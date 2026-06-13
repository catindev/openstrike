#include "assets/loaders/SpriteMetadata.h"

#include <cctype>
#include <cstddef>
#include <cstring>
#include <fstream>
#include <limits>
#include <string>
#include <utility>
#include <vector>

namespace osk::sprite {
namespace {

constexpr std::size_t HeaderSize = 40;
constexpr std::size_t PaletteCountSize = 2;
constexpr std::size_t PaletteColorSize = 3;
constexpr std::size_t FrameTypeSize = 4;
constexpr std::size_t FrameHeaderSize = 16;
constexpr std::int32_t SupportedSpriteVersion = 2;
constexpr std::int32_t SingleFrameType = 0;
constexpr std::int32_t GroupFrameType = 1;
constexpr std::uint16_t MaxPaletteColors = 256;

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

std::int32_t readI32LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::int32_t>(readU32LE(bytes, offset));
}

float readF32LE(std::span<const std::byte> bytes, std::size_t offset) {
    const std::uint32_t raw = readU32LE(bytes, offset);
    float value = 0.0F;
    static_assert(sizeof(value) == sizeof(raw));
    std::memcpy(&value, &raw, sizeof(value));
    return value;
}

std::string readMagic(std::span<const std::byte> bytes) {
    std::string magic;
    magic.reserve(4);
    for (std::size_t i = 0; i < 4; ++i) {
        const std::uint8_t c = byteAt(bytes, i);
        magic.push_back(std::isprint(c) != 0 ? static_cast<char>(c) : '?');
    }
    return magic;
}

bool magicEquals(std::span<const std::byte> bytes, const char* magic) {
    for (std::size_t i = 0; i < 4; ++i) {
        if (byteAt(bytes, i) != static_cast<std::uint8_t>(magic[i])) {
            return false;
        }
    }
    return true;
}

void requireBytes(std::span<const std::byte> bytes, std::size_t offset, std::size_t length, const std::string& label) {
    if (offset > bytes.size() || length > bytes.size() - offset) {
        throw SpriteMetadataFormatError("sprite " + label + " is truncated");
    }
}

void requirePositive(std::int32_t value, const std::string& fieldName) {
    if (value <= 0) {
        throw SpriteMetadataFormatError("sprite has a non-positive " + fieldName);
    }
}

std::size_t pixelDataSize(std::int32_t width, std::int32_t height) {
    requirePositive(width, "frame width");
    requirePositive(height, "frame height");
    const auto w = static_cast<std::size_t>(width);
    const auto h = static_cast<std::size_t>(height);
    if (w > std::numeric_limits<std::size_t>::max() / h) {
        throw SpriteMetadataFormatError("sprite frame dimensions overflow size_t");
    }
    return w * h;
}

SpriteHeaderInfo readHeader(std::span<const std::byte> bytes) {
    SpriteHeaderInfo header;
    header.magic = readMagic(bytes);
    header.version = readI32LE(bytes, 4);
    header.type = readI32LE(bytes, 8);
    header.textureFormat = readI32LE(bytes, 12);
    header.boundingRadius = readF32LE(bytes, 16);
    header.maxWidth = readI32LE(bytes, 20);
    header.maxHeight = readI32LE(bytes, 24);
    header.frameCount = readI32LE(bytes, 28);
    header.beamLength = readF32LE(bytes, 32);
    header.syncType = readI32LE(bytes, 36);
    header.fileSize = bytes.size();
    return header;
}

SpriteFrameInfo readFrame(
    std::span<const std::byte> bytes,
    std::size_t& offset,
    std::int32_t frameIndex,
    std::int32_t subframeIndex,
    bool grouped,
    float interval) {
    requireBytes(bytes, offset, FrameHeaderSize, "frame header");

    SpriteFrameInfo frame;
    frame.frameIndex = frameIndex;
    frame.subframeIndex = subframeIndex;
    frame.grouped = grouped;
    frame.interval = interval;
    frame.originX = readI32LE(bytes, offset);
    frame.originY = readI32LE(bytes, offset + 4);
    frame.width = readI32LE(bytes, offset + 8);
    frame.height = readI32LE(bytes, offset + 12);
    offset += FrameHeaderSize;

    frame.pixelDataOffset = offset;
    frame.pixelDataSize = pixelDataSize(frame.width, frame.height);
    requireBytes(bytes, frame.pixelDataOffset, frame.pixelDataSize, "frame pixel data");
    offset += frame.pixelDataSize;
    return frame;
}

void readLogicalFrame(
    std::span<const std::byte> bytes,
    std::size_t& offset,
    std::int32_t frameIndex,
    SpriteMetadataSummary& summary) {
    requireBytes(bytes, offset, FrameTypeSize, "frame type");
    const std::int32_t frameType = readI32LE(bytes, offset);
    offset += FrameTypeSize;

    if (frameType == SingleFrameType) {
        summary.frames.push_back(readFrame(bytes, offset, frameIndex, 0, false, 0.0F));
        return;
    }

    if (frameType != GroupFrameType) {
        throw SpriteMetadataFormatError("sprite has an unsupported frame type: " + std::to_string(frameType));
    }

    requireBytes(bytes, offset, 4, "group frame count");
    const std::int32_t subframeCount = readI32LE(bytes, offset);
    offset += 4;
    requirePositive(subframeCount, "group frame count");

    const auto intervalCount = static_cast<std::size_t>(subframeCount);
    if (intervalCount > (std::numeric_limits<std::size_t>::max() / 4)) {
        throw SpriteMetadataFormatError("sprite group interval table is too large");
    }
    requireBytes(bytes, offset, intervalCount * 4, "group interval table");

    std::vector<float> intervals;
    intervals.reserve(intervalCount);
    for (std::int32_t i = 0; i < subframeCount; ++i) {
        const float interval = readF32LE(bytes, offset + static_cast<std::size_t>(i) * 4);
        if (interval <= 0.0F) {
            throw SpriteMetadataFormatError("sprite group has a non-positive frame interval");
        }
        intervals.push_back(interval);
    }
    offset += intervalCount * 4;

    summary.groups.push_back({frameIndex, subframeCount});
    for (std::int32_t i = 0; i < subframeCount; ++i) {
        summary.frames.push_back(readFrame(bytes, offset, frameIndex, i, true, intervals[static_cast<std::size_t>(i)]));
    }
}

} // namespace

SpriteMetadataFormatError::SpriteMetadataFormatError(const std::string& message)
    : std::runtime_error(message) {}

std::string_view spriteTypeName(std::int32_t type) {
    switch (type) {
        case 0:
            return "VP_PARALLEL_UPRIGHT";
        case 1:
            return "FACING_UPRIGHT";
        case 2:
            return "VP_PARALLEL";
        case 3:
            return "ORIENTED";
        case 4:
            return "VP_PARALLEL_ORIENTED";
        default:
            return "unknown";
    }
}

std::string_view spriteTextureFormatName(std::int32_t textureFormat) {
    switch (textureFormat) {
        case 0:
            return "SPR_NORMAL";
        case 1:
            return "SPR_ADDITIVE";
        case 2:
            return "SPR_INDEXALPHA";
        case 3:
            return "SPR_ALPHTEST";
        default:
            return "unknown";
    }
}

std::string_view spriteSyncTypeName(std::int32_t syncType) {
    switch (syncType) {
        case 0:
            return "synchronized";
        case 1:
            return "random";
        default:
            return "unknown";
    }
}

SpriteMetadataSummary parseSpriteMetadata(std::span<const std::byte> bytes) {
    if (bytes.size() < HeaderSize) {
        throw SpriteMetadataFormatError("file is too small to contain a sprite header");
    }
    if (!magicEquals(bytes, "IDSP")) {
        throw SpriteMetadataFormatError("unsupported sprite magic: " + readMagic(bytes));
    }

    SpriteMetadataSummary summary;
    summary.header = readHeader(bytes);
    if (summary.header.version != SupportedSpriteVersion) {
        throw SpriteMetadataFormatError("unsupported sprite version: " + std::to_string(summary.header.version));
    }
    requirePositive(summary.header.maxWidth, "maximum frame width");
    requirePositive(summary.header.maxHeight, "maximum frame height");
    requirePositive(summary.header.frameCount, "frame count");

    std::size_t offset = HeaderSize;
    requireBytes(bytes, offset, PaletteCountSize, "palette color count");
    summary.palette.colorCount = readU16LE(bytes, offset);
    offset += PaletteCountSize;
    if (summary.palette.colorCount == 0 || summary.palette.colorCount > MaxPaletteColors) {
        throw SpriteMetadataFormatError("sprite has an unsupported palette color count");
    }

    summary.palette.dataOffset = offset;
    summary.palette.dataSize = static_cast<std::size_t>(summary.palette.colorCount) * PaletteColorSize;
    requireBytes(bytes, summary.palette.dataOffset, summary.palette.dataSize, "palette data");
    offset += summary.palette.dataSize;

    summary.frames.reserve(static_cast<std::size_t>(summary.header.frameCount));
    for (std::int32_t i = 0; i < summary.header.frameCount; ++i) {
        readLogicalFrame(bytes, offset, i, summary);
    }

    if (offset < bytes.size()) {
        summary.warnings.emplace_back("sprite contains trailing bytes after the declared frames");
    }

    return summary;
}

std::vector<std::byte> loadSpriteMetadataBytes(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw SpriteMetadataFormatError("failed to open sprite file: " + path.string());
    }

    std::vector<std::byte> bytes;
    file.seekg(0, std::ios::end);
    const std::streamoff size = file.tellg();
    if (size < 0) {
        throw SpriteMetadataFormatError("failed to determine sprite file size: " + path.string());
    }

    bytes.resize(static_cast<std::size_t>(size));
    file.seekg(0, std::ios::beg);

    if (!bytes.empty()) {
        file.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
        if (!file) {
            throw SpriteMetadataFormatError("failed to read sprite file: " + path.string());
        }
    }

    return bytes;
}

SpriteMetadataSummary loadSpriteMetadata(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = loadSpriteMetadataBytes(path);
    return parseSpriteMetadata(std::span<const std::byte>(bytes.data(), bytes.size()));
}

} // namespace osk::sprite
