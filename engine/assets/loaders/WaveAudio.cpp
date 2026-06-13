#include "assets/loaders/WaveAudio.h"

#include <cctype>
#include <cstddef>
#include <fstream>
#include <limits>
#include <string>
#include <vector>

namespace osk::audio {
namespace {

constexpr std::size_t RiffHeaderSize = 12;
constexpr std::size_t ChunkHeaderSize = 8;
constexpr std::size_t PcmFormatSize = 16;
constexpr std::uint16_t PcmFormat = 1;

std::uint8_t byteAt(std::span<const std::byte> bytes, std::size_t offset) {
    return std::to_integer<std::uint8_t>(bytes[offset]);
}

std::uint16_t readU16LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::uint16_t>(byteAt(bytes, offset))
        | static_cast<std::uint16_t>(static_cast<std::uint16_t>(byteAt(bytes, offset + 1)) << 8U);
}

std::uint32_t readU32LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::uint32_t>(byteAt(bytes, offset))
        | (static_cast<std::uint32_t>(byteAt(bytes, offset + 1)) << 8U)
        | (static_cast<std::uint32_t>(byteAt(bytes, offset + 2)) << 16U)
        | (static_cast<std::uint32_t>(byteAt(bytes, offset + 3)) << 24U);
}

std::string readFourCC(std::span<const std::byte> bytes, std::size_t offset) {
    std::string fourcc;
    fourcc.reserve(4);
    for (std::size_t i = 0; i < 4; ++i) {
        const std::uint8_t c = byteAt(bytes, offset + i);
        fourcc.push_back(std::isprint(c) != 0 ? static_cast<char>(c) : '?');
    }
    return fourcc;
}

bool fourccEquals(std::span<const std::byte> bytes, std::size_t offset, const char* fourcc) {
    for (std::size_t i = 0; i < 4; ++i) {
        if (byteAt(bytes, offset + i) != static_cast<std::uint8_t>(fourcc[i])) {
            return false;
        }
    }
    return true;
}

void requireRange(std::span<const std::byte> bytes, std::size_t offset, std::size_t size, const std::string& label) {
    if (offset > bytes.size() || size > bytes.size() - offset) {
        throw WaveAudioFormatError("WAV " + label + " is truncated");
    }
}

std::size_t paddedChunkSize(std::uint32_t chunkSize) {
    const std::size_t size = static_cast<std::size_t>(chunkSize);
    if (size == std::numeric_limits<std::size_t>::max()) {
        throw WaveAudioFormatError("WAV chunk size overflows size_t");
    }
    return size + (size % 2);
}

void validateFormat(const WaveFormatInfo& format) {
    if (format.audioFormat != PcmFormat) {
        throw WaveAudioFormatError("unsupported WAV audio format: " + std::to_string(format.audioFormat));
    }
    if (format.channelCount == 0) {
        throw WaveAudioFormatError("WAV has zero channels");
    }
    if (format.sampleRate == 0) {
        throw WaveAudioFormatError("WAV has a zero sample rate");
    }
    if (format.byteRate == 0) {
        throw WaveAudioFormatError("WAV has a zero byte rate");
    }
    if (format.bitsPerSample == 0 || (format.bitsPerSample % 8) != 0) {
        throw WaveAudioFormatError("WAV bits per sample is not byte-aligned");
    }

    const std::uint32_t expectedBlockAlign =
        static_cast<std::uint32_t>(format.channelCount) * static_cast<std::uint32_t>(format.bitsPerSample / 8);
    if (format.blockAlign == 0 || format.blockAlign != expectedBlockAlign) {
        throw WaveAudioFormatError("WAV block align does not match channels and sample size");
    }

    const std::uint32_t expectedByteRate = format.sampleRate * static_cast<std::uint32_t>(format.blockAlign);
    if (format.byteRate != expectedByteRate) {
        throw WaveAudioFormatError("WAV byte rate does not match sample rate and block align");
    }
}

WaveFormatInfo readFormatChunk(std::span<const std::byte> bytes, std::size_t offset, std::uint32_t chunkSize) {
    if (chunkSize < PcmFormatSize) {
        throw WaveAudioFormatError("WAV fmt chunk is too small");
    }
    requireRange(bytes, offset, PcmFormatSize, "fmt chunk");

    return {
        readU16LE(bytes, offset),
        readU16LE(bytes, offset + 2),
        readU32LE(bytes, offset + 4),
        readU32LE(bytes, offset + 8),
        readU16LE(bytes, offset + 12),
        readU16LE(bytes, offset + 14),
    };
}

} // namespace

WaveAudioFormatError::WaveAudioFormatError(const std::string& message)
    : std::runtime_error(message) {}

std::string_view waveAudioFormatName(std::uint16_t audioFormat) {
    switch (audioFormat) {
        case PcmFormat:
            return "PCM";
        default:
            return "unknown";
    }
}

WaveAudioSummary parseWaveAudioSummary(std::span<const std::byte> bytes) {
    if (bytes.size() < RiffHeaderSize) {
        throw WaveAudioFormatError("file is too small to contain a WAV RIFF header");
    }
    if (!fourccEquals(bytes, 0, "RIFF")) {
        throw WaveAudioFormatError("unsupported WAV RIFF magic: " + readFourCC(bytes, 0));
    }
    if (!fourccEquals(bytes, 8, "WAVE")) {
        throw WaveAudioFormatError("unsupported WAV format magic: " + readFourCC(bytes, 8));
    }

    WaveAudioSummary summary;
    summary.riffMagic = readFourCC(bytes, 0);
    summary.declaredRiffSize = readU32LE(bytes, 4);
    summary.waveMagic = readFourCC(bytes, 8);
    summary.fileSize = bytes.size();

    const std::size_t declaredTotalSize = static_cast<std::size_t>(summary.declaredRiffSize) + 8;
    if (declaredTotalSize != bytes.size()) {
        summary.warnings.emplace_back("declared RIFF size does not match the file size");
    }

    bool foundFormat = false;
    bool foundData = false;
    std::size_t offset = RiffHeaderSize;
    while (offset < bytes.size()) {
        requireRange(bytes, offset, ChunkHeaderSize, "chunk header");
        const std::string chunkId = readFourCC(bytes, offset);
        const std::uint32_t chunkSize = readU32LE(bytes, offset + 4);
        const std::size_t dataOffset = offset + ChunkHeaderSize;
        requireRange(bytes, dataOffset, static_cast<std::size_t>(chunkSize), "chunk data");

        if (chunkId == "fmt ") {
            summary.format = readFormatChunk(bytes, dataOffset, chunkSize);
            foundFormat = true;
        } else if (chunkId == "data") {
            summary.data.offset = dataOffset;
            summary.data.size = static_cast<std::size_t>(chunkSize);
            foundData = true;
        }

        offset = dataOffset + paddedChunkSize(chunkSize);
    }

    if (!foundFormat) {
        throw WaveAudioFormatError("WAV is missing a fmt chunk");
    }
    validateFormat(summary.format);

    if (!foundData) {
        throw WaveAudioFormatError("WAV is missing a data chunk");
    }
    if (summary.data.size == 0) {
        throw WaveAudioFormatError("WAV data chunk is empty");
    }
    if ((summary.data.size % summary.format.blockAlign) != 0) {
        throw WaveAudioFormatError("WAV data size is not aligned to full samples");
    }

    summary.data.durationSeconds = static_cast<double>(summary.data.size) / static_cast<double>(summary.format.byteRate);
    return summary;
}

std::vector<std::byte> loadWaveAudioBytes(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw WaveAudioFormatError("failed to open WAV file: " + path.string());
    }

    std::vector<std::byte> bytes;
    file.seekg(0, std::ios::end);
    const std::streamoff size = file.tellg();
    if (size < 0) {
        throw WaveAudioFormatError("failed to determine WAV file size: " + path.string());
    }

    bytes.resize(static_cast<std::size_t>(size));
    file.seekg(0, std::ios::beg);

    if (!bytes.empty()) {
        file.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
        if (!file) {
            throw WaveAudioFormatError("failed to read WAV file: " + path.string());
        }
    }

    return bytes;
}

WaveAudioSummary loadWaveAudioSummary(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = loadWaveAudioBytes(path);
    return parseWaveAudioSummary(std::span<const std::byte>(bytes.data(), bytes.size()));
}

} // namespace osk::audio
