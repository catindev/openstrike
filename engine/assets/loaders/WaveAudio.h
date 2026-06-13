#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace osk::audio {

class WaveAudioFormatError : public std::runtime_error {
public:
    explicit WaveAudioFormatError(const std::string& message);
};

struct WaveFormatInfo {
    std::uint16_t audioFormat = 0;
    std::uint16_t channelCount = 0;
    std::uint32_t sampleRate = 0;
    std::uint32_t byteRate = 0;
    std::uint16_t blockAlign = 0;
    std::uint16_t bitsPerSample = 0;
};

struct WaveDataInfo {
    std::size_t offset = 0;
    std::size_t size = 0;
    double durationSeconds = 0.0;
};

struct WaveAudioSummary {
    std::string riffMagic;
    std::string waveMagic;
    std::uint32_t declaredRiffSize = 0;
    std::size_t fileSize = 0;
    WaveFormatInfo format;
    WaveDataInfo data;
    std::vector<std::string> warnings;
};

std::string_view waveAudioFormatName(std::uint16_t audioFormat);

WaveAudioSummary parseWaveAudioSummary(std::span<const std::byte> bytes);
WaveAudioSummary loadWaveAudioSummary(const std::filesystem::path& path);
std::vector<std::byte> loadWaveAudioBytes(const std::filesystem::path& path);

} // namespace osk::audio
