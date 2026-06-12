#pragma once

#include "assets/loaders/BspTypes.h"

#include <cstddef>
#include <filesystem>
#include <span>
#include <string>
#include <vector>

namespace osk::bsp {

struct Vec3 {
    float x = 0.0F;
    float y = 0.0F;
    float z = 0.0F;
};

struct Bounds3 {
    Vec3 min;
    Vec3 max;
    bool valid = false;
};

struct BspGeometrySummary {
    std::size_t vertexCount = 0;
    std::size_t edgeCount = 0;
    std::size_t surfEdgeCount = 0;
    std::size_t faceCount = 0;

    std::size_t validFaceCount = 0;
    std::size_t invalidFaceCount = 0;
    std::size_t degenerateFaceCount = 0;

    std::size_t polygonVertexCount = 0;
    std::size_t triangleCount = 0;
    std::size_t maxEdgesPerFace = 0;

    Bounds3 bounds;
    std::vector<std::string> warnings;
};

BspGeometrySummary parseBspGeometrySummary(std::span<const std::byte> bytes, const BspSummary& summary);
BspGeometrySummary loadBspGeometrySummary(const std::filesystem::path& path);

} // namespace osk::bsp
