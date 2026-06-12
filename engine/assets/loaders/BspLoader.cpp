#include "assets/loaders/BspLoader.h"

#include <cstddef>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace osk::bsp {
namespace {

constexpr std::size_t HeaderSize = 4 + LumpCount * 8;
constexpr std::size_t MipTextureNameBytes = 16;
constexpr std::size_t MipHeaderBytes = 40;

std::uint8_t byteAt(std::span<const std::byte> bytes, std::size_t offset) {
    return std::to_integer<std::uint8_t>(bytes[offset]);
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

bool rangeInside(std::size_t fileSize, std::uint32_t offset, std::uint32_t length) {
    const std::size_t begin = static_cast<std::size_t>(offset);
    const std::size_t size = static_cast<std::size_t>(length);
    return begin <= fileSize && size <= fileSize - begin;
}

std::size_t countEntityBlocks(std::span<const std::byte> bytes, const LumpInfo& entities) {
    if (!entities.rangeValid || entities.length == 0) {
        return 0;
    }

    std::size_t count = 0;
    const std::size_t begin = entities.offset;
    const std::size_t end = begin + entities.length;

    for (std::size_t i = begin; i < end; ++i) {
        if (byteAt(bytes, i) == static_cast<std::uint8_t>('{')) {
            ++count;
        }
    }

    return count;
}

std::string readMipTextureName(std::span<const std::byte> textureLump, std::size_t mipOffset) {
    if (mipOffset > textureLump.size() || MipHeaderBytes > textureLump.size() - mipOffset) {
        return {};
    }

    std::string name;
    for (std::size_t i = 0; i < MipTextureNameBytes; ++i) {
        const std::uint8_t c = byteAt(textureLump, mipOffset + i);
        if (c == 0) {
            break;
        }
        name.push_back(static_cast<char>(c));
    }

    return name;
}

BspTextureMetadata readMipTextureMetadata(std::span<const std::byte> textureLump, std::size_t textureIndex, std::size_t mipOffset) {
    BspTextureMetadata metadata;
    metadata.index = textureIndex;
    if (mipOffset > textureLump.size() || MipHeaderBytes > textureLump.size() - mipOffset) {
        return metadata;
    }

    metadata.name = readMipTextureName(textureLump, mipOffset);
    metadata.width = readU32LE(textureLump, mipOffset + 16);
    metadata.height = readU32LE(textureLump, mipOffset + 20);
    for (std::size_t i = 0; i < metadata.mipOffsets.size(); ++i) {
        metadata.mipOffsets[i] = readU32LE(textureLump, mipOffset + 24 + i * 4);
    }
    metadata.mipMetadataAvailable = !metadata.name.empty() && metadata.width > 0 && metadata.height > 0;
    return metadata;
}

TextureInfo parseTextureInfo(std::span<const std::byte> bytes, const LumpInfo& textures, std::vector<std::string>& warnings) {
    TextureInfo info;

    if (!textures.rangeValid || textures.length == 0) {
        return info;
    }

    const auto begin = static_cast<std::size_t>(textures.offset);
    const auto length = static_cast<std::size_t>(textures.length);
    const std::span<const std::byte> lump = bytes.subspan(begin, length);

    if (lump.size() < 4) {
        warnings.emplace_back("texture lump is shorter than its texture count field");
        return info;
    }

    info.declaredCount = readI32LE(lump, 0);
    if (info.declaredCount < 0) {
        warnings.emplace_back("texture lump has a negative texture count");
        return info;
    }

    const auto count = static_cast<std::size_t>(info.declaredCount);
    if (count > (lump.size() - 4) / 4) {
        warnings.emplace_back("texture lump offset table is truncated");
        return info;
    }

    info.entries.reserve(count);
    for (std::size_t i = 0; i < count; ++i) {
        const std::int32_t relativeOffset = readI32LE(lump, 4 + i * 4);
        if (relativeOffset < 0) {
            continue;
        }

        const auto mipOffset = static_cast<std::size_t>(relativeOffset);
        if (mipOffset >= lump.size()) {
            warnings.emplace_back("texture lump contains an out-of-range miptex offset");
            continue;
        }

        ++info.validOffsetCount;
        BspTextureMetadata metadata = readMipTextureMetadata(lump, i, mipOffset);
        if (metadata.mipMetadataAvailable) {
            ++info.namedTextureCount;
        }
        info.entries.push_back(std::move(metadata));
    }

    return info;
}

} // namespace

const std::array<LumpSpec, LumpCount>& lumpSpecs() {
    static constexpr std::array<LumpSpec, LumpCount> specs{{
        {LumpId::Entities, "Entities", 0},
        {LumpId::Planes, "Planes", 20},
        {LumpId::Textures, "Textures", 0},
        {LumpId::Vertices, "Vertices", 12},
        {LumpId::Visibility, "Visibility", 0},
        {LumpId::Nodes, "Nodes", 24},
        {LumpId::TexInfo, "TexInfo", 40},
        {LumpId::Faces, "Faces", 20},
        {LumpId::Lighting, "Lighting", 0},
        {LumpId::ClipNodes, "ClipNodes", 8},
        {LumpId::Leaves, "Leaves", 28},
        {LumpId::MarkSurfaces, "MarkSurfaces", 2},
        {LumpId::Edges, "Edges", 4},
        {LumpId::SurfEdges, "SurfEdges", 4},
        {LumpId::Models, "Models", 64},
    }};

    return specs;
}

std::string_view lumpName(LumpId id) {
    return lumpSpecs()[static_cast<std::size_t>(id)].name;
}

BspFormatError::BspFormatError(const std::string& message)
    : std::runtime_error(message) {}

BspSummary parseBspSummary(std::span<const std::byte> bytes) {
    if (bytes.size() < HeaderSize) {
        throw BspFormatError("file is too small to contain a BSP header");
    }

    BspSummary summary;
    summary.fileSize = bytes.size();
    summary.version = readI32LE(bytes, 0);

    if (summary.version != GoldSrcBspVersion) {
        throw BspFormatError("unsupported BSP version: " + std::to_string(summary.version));
    }

    const auto& specs = lumpSpecs();
    for (std::size_t i = 0; i < LumpCount; ++i) {
        const std::size_t lumpHeaderOffset = 4 + i * 8;
        LumpInfo info;
        info.id = specs[i].id;
        info.name = std::string(specs[i].name);
        info.offset = readU32LE(bytes, lumpHeaderOffset);
        info.length = readU32LE(bytes, lumpHeaderOffset + 4);
        info.elementSize = specs[i].elementSize;
        info.rangeValid = rangeInside(bytes.size(), info.offset, info.length);

        if (info.elementSize > 0) {
            info.sizeAligned = (info.length % info.elementSize) == 0;
            if (info.sizeAligned) {
                info.elementCount = info.length / info.elementSize;
            }
        }

        if (!info.rangeValid) {
            summary.warnings.emplace_back(info.name + " lump range is outside the file");
        } else if (!info.sizeAligned) {
            summary.warnings.emplace_back(info.name + " lump length is not aligned to its element size");
        }

        summary.lumps[i] = std::move(info);
    }

    summary.entityBlockCount = countEntityBlocks(bytes, summary.lumps[static_cast<std::size_t>(LumpId::Entities)]);
    summary.textures = parseTextureInfo(bytes, summary.lumps[static_cast<std::size_t>(LumpId::Textures)], summary.warnings);

    return summary;
}

BspSummary loadBspSummary(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw BspFormatError("failed to open BSP file: " + path.string());
    }

    std::vector<std::byte> bytes;
    file.seekg(0, std::ios::end);
    const std::streamoff size = file.tellg();
    if (size < 0) {
        throw BspFormatError("failed to determine BSP file size: " + path.string());
    }

    bytes.resize(static_cast<std::size_t>(size));
    file.seekg(0, std::ios::beg);

    if (!bytes.empty()) {
        file.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
        if (!file) {
            throw BspFormatError("failed to read BSP file: " + path.string());
        }
    }

    return parseBspSummary(std::span<const std::byte>(bytes.data(), bytes.size()));
}

} // namespace osk::bsp
