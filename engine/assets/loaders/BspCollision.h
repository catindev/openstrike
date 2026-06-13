#pragma once

#include "assets/loaders/BspGeometry.h"
#include "assets/loaders/BspTypes.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <string>
#include <vector>

namespace osk::bsp {

inline constexpr std::int16_t BspContentsEmpty = -1;
inline constexpr std::int16_t BspContentsSolid = -2;
inline constexpr std::int16_t BspContentsClip = -8;
inline constexpr std::size_t BspCollisionHullCount = 4;

struct BspCollisionPlane {
    Vec3 normal;
    float distance = 0.0F;
    std::int32_t type = 0;
};

struct BspClipNode {
    std::int32_t planeIndex = -1;
    std::array<std::int16_t, 2> children{};
};

struct BspModelCollisionInfo {
    std::size_t modelIndex = 0;
    std::array<std::int32_t, BspCollisionHullCount> headNodes{};
};

struct BspCollisionData {
    std::vector<BspCollisionPlane> planes;
    std::vector<BspClipNode> clipNodes;
    std::vector<BspModelCollisionInfo> models;
    std::vector<std::string> warnings;
};

struct BspTraceInput {
    Vec3 start;
    Vec3 end;
    std::size_t modelIndex = 0;
    std::size_t hullIndex = 1;
};

struct BspTraceResult {
    bool valid = false;
    bool hit = false;
    bool startSolid = false;
    bool allSolid = false;
    float fraction = 1.0F;
    Vec3 endPosition;
    Vec3 hitNormal;
    std::int32_t planeIndex = -1;
    std::int16_t contents = BspContentsEmpty;
    std::vector<std::string> warnings;
};

BspCollisionData parseBspCollisionData(std::span<const std::byte> bytes, const BspSummary& summary);
BspCollisionData loadBspCollisionData(const std::filesystem::path& path);
BspTraceResult tracePoint(const BspCollisionData& collision, const BspTraceInput& input);

} // namespace osk::bsp
