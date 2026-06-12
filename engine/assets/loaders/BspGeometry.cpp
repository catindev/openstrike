#include "assets/loaders/BspGeometry.h"

#include "assets/loaders/BspLoader.h"

#include <algorithm>
#include <bit>
#include <cstdint>
#include <fstream>
#include <limits>
#include <span>
#include <string>
#include <vector>

namespace osk::bsp {
namespace {

struct FaceRecord {
    std::int32_t firstEdge = 0;
    std::int16_t edgeCount = 0;
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
    if (!info.rangeValid) {
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

EdgeRecord readEdge(std::span<const std::byte> edges, std::size_t index) {
    const std::size_t offset = index * 4;
    return EdgeRecord{
        .vertex0 = readU16LE(edges, offset),
        .vertex1 = readU16LE(edges, offset + 2),
    };
}

FaceRecord readFace(std::span<const std::byte> faces, std::size_t index) {
    const std::size_t offset = index * 20;
    return FaceRecord{
        .firstEdge = readI32LE(faces, offset + 4),
        .edgeCount = readI16LE(faces, offset + 8),
    };
}

void extendBounds(Bounds3& bounds, Vec3 point) {
    if (!bounds.valid) {
        bounds.min = point;
        bounds.max = point;
        bounds.valid = true;
        return;
    }

    bounds.min.x = std::min(bounds.min.x, point.x);
    bounds.min.y = std::min(bounds.min.y, point.y);
    bounds.min.z = std::min(bounds.min.z, point.z);
    bounds.max.x = std::max(bounds.max.x, point.x);
    bounds.max.y = std::max(bounds.max.y, point.y);
    bounds.max.z = std::max(bounds.max.z, point.z);
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

BspGeometrySummary parseBspGeometrySummary(std::span<const std::byte> bytes, const BspSummary& summary) {
    BspGeometrySummary geometry;

    const LumpInfo& verticesInfo = lump(summary, LumpId::Vertices);
    const LumpInfo& edgesInfo = lump(summary, LumpId::Edges);
    const LumpInfo& surfEdgesInfo = lump(summary, LumpId::SurfEdges);
    const LumpInfo& facesInfo = lump(summary, LumpId::Faces);

    geometry.vertexCount = verticesInfo.elementCount;
    geometry.edgeCount = edgesInfo.elementCount;
    geometry.surfEdgeCount = surfEdgesInfo.elementCount;
    geometry.faceCount = facesInfo.elementCount;

    if (!verticesInfo.rangeValid || !edgesInfo.rangeValid || !surfEdgesInfo.rangeValid || !facesInfo.rangeValid) {
        geometry.warnings.emplace_back("one or more geometry lumps have invalid ranges");
        return geometry;
    }

    if (!verticesInfo.sizeAligned || !edgesInfo.sizeAligned || !surfEdgesInfo.sizeAligned || !facesInfo.sizeAligned) {
        geometry.warnings.emplace_back("one or more geometry lumps have unaligned sizes");
        return geometry;
    }

    const std::span<const std::byte> vertices = lumpBytes(bytes, verticesInfo);
    const std::span<const std::byte> edges = lumpBytes(bytes, edgesInfo);
    const std::span<const std::byte> surfEdges = lumpBytes(bytes, surfEdgesInfo);
    const std::span<const std::byte> faces = lumpBytes(bytes, facesInfo);

    for (std::size_t faceIndex = 0; faceIndex < geometry.faceCount; ++faceIndex) {
        const FaceRecord face = readFace(faces, faceIndex);
        if (face.edgeCount < 3) {
            ++geometry.degenerateFaceCount;
            ++geometry.invalidFaceCount;
            continue;
        }

        const auto edgeCount = static_cast<std::size_t>(face.edgeCount);
        geometry.maxEdgesPerFace = std::max(geometry.maxEdgesPerFace, edgeCount);

        if (face.firstEdge < 0) {
            ++geometry.invalidFaceCount;
            continue;
        }

        const auto firstEdge = static_cast<std::size_t>(face.firstEdge);
        if (firstEdge > geometry.surfEdgeCount || edgeCount > geometry.surfEdgeCount - firstEdge) {
            ++geometry.invalidFaceCount;
            continue;
        }

        bool valid = true;
        for (std::size_t i = 0; i < edgeCount; ++i) {
            const std::int32_t surfEdge = readI32LE(surfEdges, (firstEdge + i) * 4);
            if (surfEdge == std::numeric_limits<std::int32_t>::min()) {
                valid = false;
                break;
            }

            const std::size_t edgeIndex = static_cast<std::size_t>(surfEdge < 0 ? -surfEdge : surfEdge);
            if (edgeIndex >= geometry.edgeCount) {
                valid = false;
                break;
            }

            const EdgeRecord edge = readEdge(edges, edgeIndex);
            const std::uint16_t vertexIndex = surfEdge >= 0 ? edge.vertex0 : edge.vertex1;
            if (static_cast<std::size_t>(vertexIndex) >= geometry.vertexCount) {
                valid = false;
                break;
            }

            extendBounds(geometry.bounds, readVertex(vertices, vertexIndex));
        }

        if (!valid) {
            ++geometry.invalidFaceCount;
            continue;
        }

        ++geometry.validFaceCount;
        geometry.polygonVertexCount += edgeCount;
        geometry.triangleCount += edgeCount - 2;
    }

    if (geometry.invalidFaceCount > 0) {
        geometry.warnings.emplace_back("one or more faces reference invalid surfedges, edges, or vertices");
    }

    return geometry;
}

BspGeometrySummary loadBspGeometrySummary(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = readWholeFile(path);
    const BspSummary summary = parseBspSummary(std::span<const std::byte>(bytes.data(), bytes.size()));
    return parseBspGeometrySummary(std::span<const std::byte>(bytes.data(), bytes.size()), summary);
}

} // namespace osk::bsp
