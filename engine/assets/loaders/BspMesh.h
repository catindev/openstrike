#pragma once

#include "assets/loaders/BspGeometry.h"
#include "assets/loaders/BspTypes.h"

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <string>
#include <vector>

namespace osk::bsp {

struct Vec2 {
    float x = 0.0F;
    float y = 0.0F;
};

struct BspMeshVertex {
    Vec3 position;
    Vec3 normal;
    Vec2 textureUv;
    std::uint32_t faceIndex = 0;
};

struct BspMeshFaceRange {
    std::uint32_t faceIndex = 0;
    std::uint32_t vertexOffset = 0;
    std::uint32_t vertexCount = 0;
    std::uint32_t indexOffset = 0;
    std::uint32_t indexCount = 0;
    std::uint16_t planeIndex = 0;
    std::uint16_t texInfoIndex = 0;
    std::int32_t textureIndex = -1;
    std::int32_t surfaceFlags = 0;
};

struct BspWorldMesh {
    std::vector<BspMeshVertex> vertices;
    std::vector<std::uint32_t> indices;
    std::vector<BspMeshFaceRange> faces;

    Bounds3 bounds;
    std::size_t skippedFaceCount = 0;
    std::vector<std::string> warnings;

    [[nodiscard]] std::size_t triangleCount() const;
};

BspWorldMesh buildBspWorldMesh(std::span<const std::byte> bytes, const BspSummary& summary);
BspWorldMesh loadBspWorldMesh(const std::filesystem::path& path);

} // namespace osk::bsp
