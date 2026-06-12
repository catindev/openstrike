#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace osk::bsp {

inline constexpr std::int32_t GoldSrcBspVersion = 30;
inline constexpr std::size_t LumpCount = 15;

// GoldSrc / BSP v30 lump order.
enum class LumpId : std::size_t {
    Entities = 0,
    Planes = 1,
    Textures = 2,
    Vertices = 3,
    Visibility = 4,
    Nodes = 5,
    TexInfo = 6,
    Faces = 7,
    Lighting = 8,
    ClipNodes = 9,
    Leaves = 10,
    MarkSurfaces = 11,
    Edges = 12,
    SurfEdges = 13,
    Models = 14,
};

struct LumpSpec {
    LumpId id;
    std::string_view name;
    std::size_t elementSize;
};

struct LumpInfo {
    LumpId id;
    std::string name;
    std::uint32_t offset = 0;
    std::uint32_t length = 0;
    std::size_t elementSize = 0;
    std::size_t elementCount = 0;
    bool rangeValid = false;
    bool sizeAligned = true;
};

struct BspTextureMetadata {
    std::size_t index = 0;
    std::string name;
    std::uint32_t width = 0;
    std::uint32_t height = 0;
    std::array<std::uint32_t, 4> mipOffsets{};
    bool mipMetadataAvailable = false;
};

struct TextureInfo {
    std::int32_t declaredCount = 0;
    std::size_t validOffsetCount = 0;
    std::size_t namedTextureCount = 0;
    std::vector<BspTextureMetadata> entries;
};

struct BspSummary {
    std::int32_t version = 0;
    std::size_t fileSize = 0;
    std::array<LumpInfo, LumpCount> lumps{};
    std::size_t entityBlockCount = 0;
    TextureInfo textures;
    std::vector<std::string> warnings;
};

const std::array<LumpSpec, LumpCount>& lumpSpecs();
std::string_view lumpName(LumpId id);

} // namespace osk::bsp
