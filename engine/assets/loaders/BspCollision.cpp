#include "assets/loaders/BspCollision.h"

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

constexpr float TraceEpsilon = 0.03125F;
constexpr const char* UnsupportedHullWarning = "trace hull index is unsupported; clipnode prototype supports hulls 1..3";

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

float dot(Vec3 a, Vec3 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

Vec3 lerp(Vec3 a, Vec3 b, float fraction) {
    return Vec3{
        .x = a.x + (b.x - a.x) * fraction,
        .y = a.y + (b.y - a.y) * fraction,
        .z = a.z + (b.z - a.z) * fraction,
    };
}

Vec3 negate(Vec3 v) {
    return Vec3{.x = -v.x, .y = -v.y, .z = -v.z};
}

bool isSolidContents(std::int16_t contents) {
    return contents == BspContentsSolid || contents == BspContentsClip;
}

BspCollisionPlane readPlane(std::span<const std::byte> planes, std::size_t index) {
    const std::size_t offset = index * 20;
    return BspCollisionPlane{
        .normal = Vec3{
            .x = readF32LE(planes, offset),
            .y = readF32LE(planes, offset + 4),
            .z = readF32LE(planes, offset + 8),
        },
        .distance = readF32LE(planes, offset + 12),
        .type = readI32LE(planes, offset + 16),
    };
}

BspClipNode readClipNode(std::span<const std::byte> clipNodes, std::size_t index) {
    const std::size_t offset = index * 8;
    return BspClipNode{
        .planeIndex = readI32LE(clipNodes, offset),
        .children = {readI16LE(clipNodes, offset + 4), readI16LE(clipNodes, offset + 6)},
    };
}

BspModelCollisionInfo readModel(std::span<const std::byte> models, std::size_t index) {
    const std::size_t offset = index * 64;
    BspModelCollisionInfo model;
    model.modelIndex = index;
    for (std::size_t i = 0; i < model.headNodes.size(); ++i) {
        model.headNodes[i] = readI32LE(models, offset + 36 + i * 4);
    }
    return model;
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

std::int16_t pointContents(const BspCollisionData& collision, std::int32_t headNode, Vec3 point, std::vector<std::string>* warnings) {
    std::int32_t nodeIndex = headNode;
    std::size_t guard = 0;
    while (nodeIndex >= 0) {
        if (guard++ > collision.clipNodes.size()) {
            if (warnings != nullptr) {
                warnings->emplace_back("clipnode traversal exceeded guard limit");
            }
            return BspContentsEmpty;
        }

        const auto node = static_cast<std::size_t>(nodeIndex);
        if (node >= collision.clipNodes.size()) {
            if (warnings != nullptr) {
                warnings->emplace_back("clipnode index is outside the clipnode array");
            }
            return BspContentsEmpty;
        }

        const BspClipNode& clipNode = collision.clipNodes[node];
        if (clipNode.planeIndex < 0 || static_cast<std::size_t>(clipNode.planeIndex) >= collision.planes.size()) {
            if (warnings != nullptr) {
                warnings->emplace_back("clipnode references an invalid plane index");
            }
            return BspContentsEmpty;
        }

        const BspCollisionPlane& plane = collision.planes[static_cast<std::size_t>(clipNode.planeIndex)];
        const float distance = dot(point, plane.normal) - plane.distance;
        nodeIndex = clipNode.children[distance < 0.0F ? 1 : 0];
    }

    return static_cast<std::int16_t>(nodeIndex);
}

bool recursiveTrace(
    const BspCollisionData& collision,
    std::int32_t nodeIndex,
    float startFraction,
    float endFraction,
    Vec3 start,
    Vec3 end,
    BspTraceResult& result,
    std::size_t depth) {
    if (result.hit && result.fraction <= startFraction) {
        return false;
    }

    if (depth > collision.clipNodes.size() + 8) {
        result.warnings.emplace_back("clipnode trace exceeded recursion guard");
        return true;
    }

    if (nodeIndex < 0) {
        const auto contents = static_cast<std::int16_t>(nodeIndex);
        if (!isSolidContents(contents)) {
            result.allSolid = false;
            return true;
        }
        if (startFraction == 0.0F) {
            result.startSolid = true;
        }
        return false;
    }

    const auto node = static_cast<std::size_t>(nodeIndex);
    if (node >= collision.clipNodes.size()) {
        result.warnings.emplace_back("trace reached an out-of-range clipnode");
        result.allSolid = false;
        return true;
    }

    const BspClipNode& clipNode = collision.clipNodes[node];
    if (clipNode.planeIndex < 0 || static_cast<std::size_t>(clipNode.planeIndex) >= collision.planes.size()) {
        result.warnings.emplace_back("trace reached a clipnode with an invalid plane index");
        result.allSolid = false;
        return true;
    }

    const BspCollisionPlane& plane = collision.planes[static_cast<std::size_t>(clipNode.planeIndex)];
    const float startDistance = dot(start, plane.normal) - plane.distance;
    const float endDistance = dot(end, plane.normal) - plane.distance;

    if (startDistance >= 0.0F && endDistance >= 0.0F) {
        return recursiveTrace(collision, clipNode.children[0], startFraction, endFraction, start, end, result, depth + 1);
    }
    if (startDistance < 0.0F && endDistance < 0.0F) {
        return recursiveTrace(collision, clipNode.children[1], startFraction, endFraction, start, end, result, depth + 1);
    }

    const int firstSide = startDistance < 0.0F ? 1 : 0;
    const int secondSide = 1 - firstSide;
    const float denominator = startDistance - endDistance;
    float splitFraction = 0.0F;
    if (denominator != 0.0F) {
        const float offset = firstSide == 0 ? TraceEpsilon : -TraceEpsilon;
        splitFraction = (startDistance - offset) / denominator;
    }
    splitFraction = std::clamp(splitFraction, 0.0F, 1.0F);

    const float midFraction = startFraction + (endFraction - startFraction) * splitFraction;
    const Vec3 mid = lerp(start, end, splitFraction);

    if (!recursiveTrace(collision, clipNode.children[firstSide], startFraction, midFraction, start, mid, result, depth + 1)) {
        return false;
    }

    if (recursiveTrace(collision, clipNode.children[secondSide], midFraction, endFraction, mid, end, result, depth + 1)) {
        return true;
    }

    if (!result.startSolid && midFraction < result.fraction) {
        result.hit = true;
        result.fraction = std::clamp(midFraction, 0.0F, 1.0F);
        result.endPosition = mid;
        result.planeIndex = clipNode.planeIndex;
        result.hitNormal = firstSide == 0 ? plane.normal : negate(plane.normal);
        result.contents = pointContents(collision, clipNode.children[secondSide], mid, &result.warnings);
    }

    return false;
}

} // namespace

BspCollisionData parseBspCollisionData(std::span<const std::byte> bytes, const BspSummary& summary) {
    BspCollisionData collision;

    const LumpInfo& planesInfo = lump(summary, LumpId::Planes);
    const LumpInfo& clipNodesInfo = lump(summary, LumpId::ClipNodes);
    const LumpInfo& modelsInfo = lump(summary, LumpId::Models);

    if (!planesInfo.rangeValid || !clipNodesInfo.rangeValid || !modelsInfo.rangeValid) {
        collision.warnings.emplace_back("one or more collision source lumps have invalid ranges");
        return collision;
    }

    if (!planesInfo.sizeAligned || !clipNodesInfo.sizeAligned || !modelsInfo.sizeAligned) {
        collision.warnings.emplace_back("one or more collision source lumps have unaligned sizes");
        return collision;
    }

    const std::span<const std::byte> planes = lumpBytes(bytes, planesInfo);
    const std::span<const std::byte> clipNodes = lumpBytes(bytes, clipNodesInfo);
    const std::span<const std::byte> models = lumpBytes(bytes, modelsInfo);

    collision.planes.reserve(planesInfo.elementCount);
    for (std::size_t i = 0; i < planesInfo.elementCount; ++i) {
        collision.planes.push_back(readPlane(planes, i));
    }

    collision.clipNodes.reserve(clipNodesInfo.elementCount);
    for (std::size_t i = 0; i < clipNodesInfo.elementCount; ++i) {
        collision.clipNodes.push_back(readClipNode(clipNodes, i));
    }

    collision.models.reserve(modelsInfo.elementCount);
    for (std::size_t i = 0; i < modelsInfo.elementCount; ++i) {
        collision.models.push_back(readModel(models, i));
    }

    if (collision.planes.empty()) {
        collision.warnings.emplace_back("collision plane table is empty");
    }
    if (collision.clipNodes.empty()) {
        collision.warnings.emplace_back("clipnode table is empty");
    }
    if (collision.models.empty()) {
        collision.warnings.emplace_back("model table is empty");
    }

    return collision;
}

BspCollisionData loadBspCollisionData(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = readWholeFile(path);
    const BspSummary summary = parseBspSummary(std::span<const std::byte>(bytes.data(), bytes.size()));
    return parseBspCollisionData(std::span<const std::byte>(bytes.data(), bytes.size()), summary);
}

BspTraceResult tracePoint(const BspCollisionData& collision, const BspTraceInput& input) {
    BspTraceResult result;
    result.endPosition = input.end;

    result.warnings.insert(result.warnings.end(), collision.warnings.begin(), collision.warnings.end());
    if (input.hullIndex == 0 || input.hullIndex >= BspCollisionHullCount) {
        result.warnings.emplace_back(UnsupportedHullWarning);
        return result;
    }
    if (input.modelIndex >= collision.models.size()) {
        result.warnings.emplace_back("trace model index is outside the model table");
        return result;
    }

    const std::int32_t headNode = collision.models[input.modelIndex].headNodes[input.hullIndex];
    if (headNode < 0) {
        result.valid = true;
        result.contents = static_cast<std::int16_t>(headNode);
        result.startSolid = isSolidContents(result.contents);
        result.allSolid = result.startSolid;
        result.hit = result.startSolid;
        result.fraction = result.startSolid ? 0.0F : 1.0F;
        result.endPosition = result.startSolid ? input.start : input.end;
        return result;
    }
    if (static_cast<std::size_t>(headNode) >= collision.clipNodes.size()) {
        result.warnings.emplace_back("trace hull headnode is outside the clipnode table");
        return result;
    }

    result.valid = true;
    result.startSolid = isSolidContents(pointContents(collision, headNode, input.start, &result.warnings));
    const bool endSolid = isSolidContents(pointContents(collision, headNode, input.end, &result.warnings));
    result.allSolid = result.startSolid && endSolid;

    recursiveTrace(collision, headNode, 0.0F, 1.0F, input.start, input.end, result, 0);
    if (!result.hit) {
        result.fraction = 1.0F;
        result.endPosition = input.end;
    }
    if (result.startSolid) {
        result.hit = true;
        result.fraction = 0.0F;
        result.endPosition = input.start;
    }

    return result;
}

} // namespace osk::bsp
