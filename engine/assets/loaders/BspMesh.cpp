#include "assets/loaders/BspMesh.h"

#include "assets/loaders/BspLoader.h"

#include <algorithm>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <limits>
#include <span>
#include <string>
#include <vector>

namespace osk::bsp {
namespace {

struct PlaneRecord {
    Vec3 normal;
};

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
    std::int32_t flags = 0;
};

struct FaceRecord {
    std::uint16_t planeIndex = 0;
    std::uint16_t planeSide = 0;
    std::int32_t firstEdge = 0;
    std::int16_t edgeCount = 0;
    std::int16_t texInfoIndex = 0;
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

PlaneRecord readPlane(std::span<const std::byte> planes, std::size_t index) {
    const std::size_t offset = index * 20;
    return PlaneRecord{
        .normal = Vec3{
            .x = readF32LE(planes, offset),
            .y = readF32LE(planes, offset + 4),
            .z = readF32LE(planes, offset + 8),
        },
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
        .flags = readI32LE(texInfo, offset + 36),
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
        .planeIndex = readU16LE(faces, offset),
        .planeSide = readU16LE(faces, offset + 2),
        .firstEdge = readI32LE(faces, offset + 4),
        .edgeCount = readI16LE(faces, offset + 8),
        .texInfoIndex = readI16LE(faces, offset + 10),
    };
}

Vec3 faceNormal(const PlaneRecord& plane, std::uint16_t planeSide) {
    if (planeSide == 0) {
        return plane.normal;
    }

    return Vec3{
        .x = -plane.normal.x,
        .y = -plane.normal.y,
        .z = -plane.normal.z,
    };
}

Vec2 textureUv(const Vec3& position, const TexInfoRecord& texInfo) {
    return Vec2{
        .x = position.x * texInfo.sAxisX + position.y * texInfo.sAxisY + position.z * texInfo.sAxisZ + texInfo.sOffset,
        .y = position.x * texInfo.tAxisX + position.y * texInfo.tAxisY + position.z * texInfo.tAxisZ + texInfo.tOffset,
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

bool fitsU32(std::size_t value) {
    return value <= static_cast<std::size_t>(std::numeric_limits<std::uint32_t>::max());
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

std::size_t BspWorldMesh::triangleCount() const {
    return indices.size() / 3;
}

BspWorldMesh buildBspWorldMesh(std::span<const std::byte> bytes, const BspSummary& summary) {
    BspWorldMesh mesh;

    const LumpInfo& verticesInfo = lump(summary, LumpId::Vertices);
    const LumpInfo& edgesInfo = lump(summary, LumpId::Edges);
    const LumpInfo& surfEdgesInfo = lump(summary, LumpId::SurfEdges);
    const LumpInfo& facesInfo = lump(summary, LumpId::Faces);
    const LumpInfo& planesInfo = lump(summary, LumpId::Planes);
    const LumpInfo& texInfoInfo = lump(summary, LumpId::TexInfo);

    if (!verticesInfo.rangeValid || !edgesInfo.rangeValid || !surfEdgesInfo.rangeValid
        || !facesInfo.rangeValid || !planesInfo.rangeValid || !texInfoInfo.rangeValid) {
        mesh.warnings.emplace_back("one or more mesh source lumps have invalid ranges");
        return mesh;
    }

    if (!verticesInfo.sizeAligned || !edgesInfo.sizeAligned || !surfEdgesInfo.sizeAligned
        || !facesInfo.sizeAligned || !planesInfo.sizeAligned || !texInfoInfo.sizeAligned) {
        mesh.warnings.emplace_back("one or more mesh source lumps have unaligned sizes");
        return mesh;
    }

    const std::span<const std::byte> vertices = lumpBytes(bytes, verticesInfo);
    const std::span<const std::byte> edges = lumpBytes(bytes, edgesInfo);
    const std::span<const std::byte> surfEdges = lumpBytes(bytes, surfEdgesInfo);
    const std::span<const std::byte> faces = lumpBytes(bytes, facesInfo);
    const std::span<const std::byte> planes = lumpBytes(bytes, planesInfo);
    const std::span<const std::byte> texInfos = lumpBytes(bytes, texInfoInfo);

    mesh.faces.reserve(facesInfo.elementCount);

    for (std::size_t faceIndex = 0; faceIndex < facesInfo.elementCount; ++faceIndex) {
        const FaceRecord face = readFace(faces, faceIndex);
        if (face.edgeCount < 3) {
            ++mesh.skippedFaceCount;
            continue;
        }

        if (face.planeIndex >= planesInfo.elementCount || face.texInfoIndex < 0
            || static_cast<std::size_t>(face.texInfoIndex) >= texInfoInfo.elementCount || face.firstEdge < 0) {
            ++mesh.skippedFaceCount;
            continue;
        }

        const auto edgeCount = static_cast<std::size_t>(face.edgeCount);
        const auto firstEdge = static_cast<std::size_t>(face.firstEdge);
        if (firstEdge > surfEdgesInfo.elementCount || edgeCount > surfEdgesInfo.elementCount - firstEdge) {
            ++mesh.skippedFaceCount;
            continue;
        }

        if (!fitsU32(mesh.vertices.size()) || !fitsU32(mesh.indices.size()) || !fitsU32(faceIndex)) {
            mesh.warnings.emplace_back("mesh is too large for 32-bit index buffers");
            return mesh;
        }

        const PlaneRecord plane = readPlane(planes, face.planeIndex);
        const TexInfoRecord texInfo = readTexInfo(texInfos, static_cast<std::size_t>(face.texInfoIndex));
        const Vec3 normal = faceNormal(plane, face.planeSide);

        const auto vertexOffset = static_cast<std::uint32_t>(mesh.vertices.size());
        const auto indexOffset = static_cast<std::uint32_t>(mesh.indices.size());

        bool valid = true;
        for (std::size_t edgeSlot = 0; edgeSlot < edgeCount; ++edgeSlot) {
            const std::int32_t surfEdge = readI32LE(surfEdges, (firstEdge + edgeSlot) * 4);
            if (surfEdge == std::numeric_limits<std::int32_t>::min()) {
                valid = false;
                break;
            }

            const auto edgeIndex = static_cast<std::size_t>(surfEdge < 0 ? -surfEdge : surfEdge);
            if (edgeIndex >= edgesInfo.elementCount) {
                valid = false;
                break;
            }

            const EdgeRecord edge = readEdge(edges, edgeIndex);
            const std::uint16_t vertexIndex = surfEdge >= 0 ? edge.vertex0 : edge.vertex1;
            if (static_cast<std::size_t>(vertexIndex) >= verticesInfo.elementCount) {
                valid = false;
                break;
            }

            const Vec3 position = readVertex(vertices, vertexIndex);
            mesh.vertices.push_back(BspMeshVertex{
                .position = position,
                .normal = normal,
                .textureUv = textureUv(position, texInfo),
                .faceIndex = static_cast<std::uint32_t>(faceIndex),
            });
            extendBounds(mesh.bounds, position);
        }

        if (!valid) {
            mesh.vertices.resize(vertexOffset);
            ++mesh.skippedFaceCount;
            continue;
        }

        for (std::size_t i = 1; i + 1 < edgeCount; ++i) {
            mesh.indices.push_back(vertexOffset);
            mesh.indices.push_back(vertexOffset + static_cast<std::uint32_t>(i));
            mesh.indices.push_back(vertexOffset + static_cast<std::uint32_t>(i + 1));
        }

        mesh.faces.push_back(BspMeshFaceRange{
            .faceIndex = static_cast<std::uint32_t>(faceIndex),
            .vertexOffset = vertexOffset,
            .vertexCount = static_cast<std::uint32_t>(edgeCount),
            .indexOffset = indexOffset,
            .indexCount = static_cast<std::uint32_t>(mesh.indices.size() - indexOffset),
            .planeIndex = face.planeIndex,
            .texInfoIndex = static_cast<std::uint16_t>(face.texInfoIndex),
            .textureIndex = texInfo.textureIndex,
            .surfaceFlags = texInfo.flags,
        });
    }

    if (mesh.skippedFaceCount > 0) {
        mesh.warnings.emplace_back("one or more faces were skipped while building the world mesh");
    }

    return mesh;
}

BspWorldMesh loadBspWorldMesh(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = readWholeFile(path);
    const BspSummary summary = parseBspSummary(std::span<const std::byte>(bytes.data(), bytes.size()));
    return buildBspWorldMesh(std::span<const std::byte>(bytes.data(), bytes.size()), summary);
}

} // namespace osk::bsp
