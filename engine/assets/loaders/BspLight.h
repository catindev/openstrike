#pragma once

#include "assets/loaders/BspTypes.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <string>
#include <vector>

namespace osk::bsp {

struct BspLightFaceInfo {
    std::uint32_t faceIndex = 0;
    std::int16_t texInfoIndex = -1;
    std::int32_t textureIndex = -1;
    std::array<std::uint8_t, 4> styles{};
    std::size_t activeStyleCount = 0;
    std::int32_t lightOffset = -1;

    bool hasLightingData = false;
    bool geometryValid = false;
    bool rangeValid = false;

    std::uint32_t lightmapWidth = 0;
    std::uint32_t lightmapHeight = 0;
    std::size_t sampleCount = 0;
    std::size_t byteCount = 0;
};

struct BspLightSummary {
    std::size_t lightingByteCount = 0;
    std::size_t faceCount = 0;
    std::size_t litFaceCount = 0;
    std::size_t validLightmapCount = 0;
    std::size_t invalidLightmapCount = 0;
    std::size_t missingLightmapCount = 0;
    std::vector<BspLightFaceInfo> faces;
    std::vector<std::string> warnings;
};

BspLightSummary parseBspLightSummary(std::span<const std::byte> bytes, const BspSummary& summary);
BspLightSummary loadBspLightSummary(const std::filesystem::path& path);

} // namespace osk::bsp
