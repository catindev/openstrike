#include "assets/loaders/BspLight.h"

#include "assets/loaders/BspGeometry.h"
#include "assets/loaders/BspLoader.h"

#include <algorithm>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <limits>
#include <span>
#include <string>
#include <vector>

namespace osk::bsp {
namespace {

struct TexInfoRecord {
    float sAxisX = 0.0F;
    float sAxisY = 0.0F;
    float sAxisZ = 0.0F;
    float sOffset = 0.0F;
    float tAxisX = 0.0F;
    float tAxisY = 0.0F;
    float tAxisZ = 0.0F;
    float tOffset = 0.0F;
    std::int32_t textureIndex = -1;
};

struct FaceRecord {
    std::uint16_t planeIndex = 0;
    std::uint16_t planeSide = 0;
    std::int32_t firstEdge = 0;
    std::int16_t edgeCount = 0;
    std::int16_t texInfoIndex = -1;
    std::array<std::uint8_t, 4> styles{};
    std::int32_t lightOffset = -1;
};

struct EdgeRecord {
    std::uint16_t vertex0 = 0;
    std::uint16_t vertex1 = 0;
};

std::uint8_t byteAt(std::span<const std::byte> bytes, std::size_t offset) {
    return std::to_integer<std::uint8_t>(bytes[offset]);
}

std::uint16_t readU16LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::uint16_t>(byteAt(bytes, offset))
        | static_cast<std::uint16_t>(static_cast<std::uint16_t>(byteAt(bytes, offset + 1)) << 8U);
}

std::int16_t readI16LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::int16_t>(readU16LE(bytes, offset));
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
    return std::bit_cast<float>(readU32LE(bytes, offset));
}

const LumpInfo& lump(const BspSummary& summary, LumpId id) {
    return summary.lumps[static_cast<std::size_t>(id)];
}

std::span<const std::byte> lumpBytes(std::span<const std::byte> bytes, const LumpInfo& info) {
    if (!info.rangeValid || info.length == 0) {
        return {};
    }
    return bytes.subspan(static_cast<std::size_t>(info.offset), static_cast<std::size_t>(info.length));
}

Vec3 readVertex(std::span<const std::byte> vertices, std::size_t index) {
    const std::size_t offset = index * 12;
    return Vec3{
        .x = readF32LE(vertices, offset),
        .y = readF32LE(vertices, offset + 4),
        .z = readF32LE(vertices, offset + 8),
    };
}

TexInfoRecord readTexInfo(std::span<const std::byte> texInfo, std::size_t index) {
    const std::size_t offset = index * 40;
    return TexInfoRecord{
        .sAxisX = readF32LE(texInfo, offset),
        .sAxisY = readF32LE(texInfo, offset + 4),
        .sAxisZ = readF32LE(texInfo, offset + 8),
        .sOffset = readF32LE(texInfo, offset + 12),
        .tAxisX = readF32LE(texInfo, offset + 16),
        .tAxisY = readF32LE(texInfo, offset + 20),
        .tAxisZ = readF32LE(texInfo, offset + 24),
        .tOffset = readF32LE(texInfo, offset + 28),
        .textureIndex = readI32LE(texInfo, offset + 32),
    };
}

FaceRecord readFace(std::span<const std::byte> faces, std::size_t index) {
    const std::size_t offset = index * 20;
    return FaceRecord{
        .planeIndex = readU16LE(faces, offset),
        .planeSide = readU16LE(faces, offset + 2),
        .firstEdge = readI32LE(faces, offset + 4),
        .edgeCount = readI16LE(faces, offset + 8),
        .texInfoIndex = readI16LE(faces, offset + 10),
        .styles = {byteAt(faces, offset + 12), byteAt(faces, offset + 13), byteAt(faces, offset + 14), byteAt(faces, offset + 15)},
        .lightOffset = readI32LE(faces, offset + 16),
    };
}

EdgeRecord readEdge(std::span<const std::byte> edges, std::size_t index) {
    const std::size_t offset = index * 4;
    return EdgeRecord{
        .vertex0 = readU16LE(edges, offset),
        .vertex1 = readU16LE(edges, offset + 2),
    };
}

std::size_t activeStyleCount(const std::array<std::uint8_t, 4>& styles) {
    std::size_t count = 0;
    for (std::uint8_t style : styles) {
        if (style != 255U) {
            ++count;
        }
    }
    return count;
}

bool mulWouldOverflow(std::size_t a, std::size_t b) {
    return a != 0 && b > std::numeric_limits<std::size_t>::max() / a;
}

bool addWouldOverflow(std::size_t a, std::size_t b) {
    return b > std::numeric_limits<std::size_t>::max() - a;
}

bool computeLightmapSize(
    std::span<const std::byte> vertices,
    std::span<const std::byte> edges,
    std::span<const std::byte> surfEdges,
    const LumpInfo& verticesInfo,
    const LumpInfo& edgesInfo,
    const LumpInfo& surfEdgesInfo,
    const FaceRecord& face,
    const TexInfoRecord& texInfo,
    std::uint32_t& width,
    std::uint32_t& height) {
    if (face.edgeCount < 3 || face.firstEdge < 0) {
        return false;
    }

    const auto edgeCount = static_cast<std::size_t>(face.edgeCount);
    const auto firstEdge = static_cast<std::size_t>(face.firstEdge);
    if (firstEdge > surfEdgesInfo.elementCount || edgeCount > surfEdgesInfo.elementCount - firstEdge) {
        return false;
    }

    float minS = 0.0F;
    float maxS = 0.0F;
    float minT = 0.0F;
    float maxT = 0.0F;
    bool initialized = false;

    for (std::size_t edgeSlot = 0; edgeSlot < edgeCount; ++edgeSlot) {
        const std::int32_t surfEdge = readI32LE(surfEdges, (firstEdge + edgeSlot) * 4);
        if (surfEdge == std::numeric_limits<std::int32_t>::min()) {
            return false;
        }

        const auto edgeIndex = static_cast<std::size_t>(surfEdge < 0 ? -surfEdge : surfEdge);
        if (edgeIndex >= edgesInfo.elementCount) {
            return false;
        }

        const EdgeRecord edge = readEdge(edges, edgeIndex);
        const std::uint16_t vertexIndex = surfEdge >= 0 ? edge.vertex0 : edge.vertex1;
        if (static_cast<std::size_t>(vertexIndex) >= verticesInfo.elementCount) {
            return false;
        }

        const Vec3 p = readVertex(vertices, vertexIndex);
        const float s = p.x * texInfo.sAxisX + p.y * texInfo.sAxisY + p.z * texInfo.sAxisZ + texInfo.sOffset;
        const float t = p.x * texInfo.tAxisX + p.y * texInfo.tAxisY + p.z * texInfo.tAxisZ + texInfo.tOffset;
        if (!std::isfinite(s) || !std::isfinite(t)) {
            return false;
        }

        if (!initialized) {
            minS = maxS = s;
            minT = maxT = t;
            initialized = true;
        } else {
            minS = std::min(minS, s);
            maxS = std::max(maxS, s);
            minT = std::min(minT, t);
            maxT = std::max(maxT, t);
        }
    }

    if (!initialized) {
        return false;
    }

    const int minBlockS = static_cast<int>(std::floor(minS / 16.0F));
    const int maxBlockS = static_cast<int>(std::ceil(maxS / 16.0F));
    const int minBlockT = static_cast<int>(std::floor(minT / 16.0F));
    const int maxBlockT = static_cast<int>(std::ceil(maxT / 16.0F));
    if (maxBlockS < minBlockS || maxBlockT < minBlockT) {
        return false;
    }

    const auto computedWidth = static_cast<std::uint32_t>(maxBlockS - minBlockS + 1);
    const auto computedHeight = static_cast<std::uint32_t>(maxBlockT - minBlockT + 1);
    if (computedWidth == 0 || computedHeight == 0) {
        return false;
    }

    width = computedWidth;
    height = computedHeight;
    return true;
}

std::vector<std::byte> readWholeFile(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw BspFormatError("failed to open BSP file: " + path.string());
    }

    file.seekg(0, std::ios::end);
    const std::streamoff size = file.tellg();
    if (size < 0) {
        throw BspFormatError("failed to determine BSP file size: " + path.string());
    }

    std::vector<std::byte> bytes(static_cast<std::size_t>(size));
    file.seekg(0, std::ios::beg);

    if (!bytes.empty()) {
        file.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
        if (!file) {
            throw BspFormatError("failed to read BSP file: " + path.string());
        }
    }

    return bytes;
}

} // namespace

BspLightSummary parseBspLightSummary(std::span<const std::byte> bytes, const BspSummary& summary) {
    BspLightSummary light;

    const LumpInfo& verticesInfo = lump(summary, LumpId::Vertices);
    const LumpInfo& edgesInfo = lump(summary, LumpId::Edges);
    const LumpInfo& surfEdgesInfo = lump(summary, LumpId::SurfEdges);
    const LumpInfo& facesInfo = lump(summary, LumpId::Faces);
    const LumpInfo& texInfoInfo = lump(summary, LumpId::TexInfo);
    const LumpInfo& lightingInfo = lump(summary, LumpId::Lighting);

    light.faceCount = facesInfo.elementCount;
    light.lightingByteCount = lightingInfo.rangeValid ? lightingInfo.length : 0;

    if (!verticesInfo.rangeValid || !edgesInfo.rangeValid || !surfEdgesInfo.rangeValid || !facesInfo.rangeValid || !texInfoInfo.rangeValid) {
        light.warnings.emplace_back("one or more light metadata source lumps have invalid ranges");
        return light;
    }

    if (!verticesInfo.sizeAligned || !edgesInfo.sizeAligned || !surfEdgesInfo.sizeAligned || !facesInfo.sizeAligned || !texInfoInfo.sizeAligned) {
        light.warnings.emplace_back("one or more light metadata source lumps have unaligned sizes");
        return light;
    }

    if (!lightingInfo.rangeValid && lightingInfo.length > 0) {
        light.warnings.emplace_back("lighting lump range is outside the file");
    }

    const std::span<const std::byte> vertices = lumpBytes(bytes, verticesInfo);
    const std::span<const std::byte> edges = lumpBytes(bytes, edgesInfo);
    const std::span<const std::byte> surfEdges = lumpBytes(bytes, surfEdgesInfo);
    const std::span<const std::byte> faces = lumpBytes(bytes, facesInfo);
    const std::span<const std::byte> texInfos = lumpBytes(bytes, texInfoInfo);

    light.faces.reserve(facesInfo.elementCount);
    for (std::size_t i = 0; i < facesInfo.elementCount; ++i) {
        const FaceRecord face = readFace(faces, i);
        BspLightFaceInfo info;
        info.faceIndex = static_cast<std::uint32_t>(i);
        info.texInfoIndex = face.texInfoIndex;
        info.styles = face.styles;
        info.activeStyleCount = activeStyleCount(face.styles);
        info.lightOffset = face.lightOffset;

        if (face.texInfoIndex >= 0 && static_cast<std::size_t>(face.texInfoIndex) < texInfoInfo.elementCount) {
            const TexInfoRecord texInfo = readTexInfo(texInfos, static_cast<std::size_t>(face.texInfoIndex));
            info.textureIndex = texInfo.textureIndex;
            info.geometryValid = computeLightmapSize(
                vertices,
                edges,
                surfEdges,
                verticesInfo,
                edgesInfo,
                surfEdgesInfo,
                face,
                texInfo,
                info.lightmapWidth,
                info.lightmapHeight);
        }

        info.hasLightingData = info.lightOffset >= 0 && info.activeStyleCount > 0;
        if (!info.hasLightingData) {
            ++light.missingLightmapCount;
            light.faces.push_back(info);
            continue;
        }

        ++light.litFaceCount;
        if (!info.geometryValid) {
            ++light.invalidLightmapCount;
            light.faces.push_back(info);
            continue;
        }

        if (mulWouldOverflow(info.lightmapWidth, info.lightmapHeight)) {
            ++light.invalidLightmapCount;
            light.faces.push_back(info);
            continue;
        }
        info.sampleCount = static_cast<std::size_t>(info.lightmapWidth) * static_cast<std::size_t>(info.lightmapHeight);
        if (mulWouldOverflow(info.sampleCount, info.activeStyleCount) || mulWouldOverflow(info.sampleCount * info.activeStyleCount, 3)) {
            ++light.invalidLightmapCount;
            light.faces.push_back(info);
            continue;
        }
        info.byteCount = info.sampleCount * info.activeStyleCount * 3;

        const auto offset = static_cast<std::size_t>(info.lightOffset);
        if (!lightingInfo.rangeValid || offset > light.lightingByteCount || info.byteCount > light.lightingByteCount - offset) {
            ++light.invalidLightmapCount;
            light.faces.push_back(info);
            continue;
        }

        info.rangeValid = true;
        ++light.validLightmapCount;
        light.faces.push_back(info);
    }

    if (light.invalidLightmapCount > 0) {
        light.warnings.emplace_back("one or more faces reference invalid or truncated light data");
    }

    return light;
}

BspLightSummary loadBspLightSummary(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = readWholeFile(path);
    const BspSummary summary = parseBspSummary(std::span<const std::byte>(bytes.data(), bytes.size()));
    return parseBspLightSummary(std::span<const std::byte>(bytes.data(), bytes.size()), summary);
}

} // namespace osk::bsp
