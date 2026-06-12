#include "assets/loaders/TexturePackage.h"

#include <cctype>
#include <cstddef>
#include <fstream>
#include <limits>
#include <string>
#include <utility>
#include <vector>

namespace osk::texture {
namespace {

constexpr std::size_t HeaderSize = 12;
constexpr std::size_t DirectoryEntrySize = 32;
constexpr std::size_t NameBytes = 16;
constexpr std::size_t MipHeaderSize = 40;
constexpr std::uint32_t MaxPlausibleDimension = 16384;
constexpr std::uint16_t MaxPaletteColors = 256;

std::uint8_t byteAt(std::span<const std::byte> bytes, std::size_t offset) {
    return std::to_integer<std::uint8_t>(bytes[offset]);
}

std::uint16_t readU16LE(std::span<const std::byte> bytes, std::size_t offset) {
    return static_cast<std::uint16_t>(byteAt(bytes, offset))
        | static_cast<std::uint16_t>(static_cast<std::uint16_t>(byteAt(bytes, offset + 1)) << 8U);
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

std::string readFixedName(std::span<const std::byte> bytes, std::size_t offset) {
    std::string name;
    for (std::size_t i = 0; i < NameBytes; ++i) {
        const std::uint8_t c = byteAt(bytes, offset + i);
        if (c == 0) {
            break;
        }
        name.push_back(std::isprint(c) != 0 ? static_cast<char>(c) : '?');
    }
    return name;
}

bool magicEquals(std::span<const std::byte> bytes, const char* magic) {
    for (std::size_t i = 0; i < 4; ++i) {
        if (byteAt(bytes, i) != static_cast<std::uint8_t>(magic[i])) {
            return false;
        }
    }
    return true;
}

std::string readMagic(std::span<const std::byte> bytes) {
    std::string magic;
    magic.reserve(4);
    for (std::size_t i = 0; i < 4; ++i) {
        const std::uint8_t c = byteAt(bytes, i);
        magic.push_back(std::isprint(c) != 0 ? static_cast<char>(c) : '?');
    }
    return magic;
}

bool plausibleDimensions(std::uint32_t width, std::uint32_t height) {
    return width > 0 && height > 0 && width <= MaxPlausibleDimension && height <= MaxPlausibleDimension;
}

bool mulWouldOverflow(std::size_t a, std::size_t b) {
    return a != 0 && b > std::numeric_limits<std::size_t>::max() / a;
}

std::size_t mipWidth(std::uint32_t width, std::size_t level) {
    const std::uint32_t shifted = width >> level;
    return static_cast<std::size_t>(shifted == 0 ? 1 : shifted);
}

std::size_t mipHeight(std::uint32_t height, std::size_t level) {
    const std::uint32_t shifted = height >> level;
    return static_cast<std::size_t>(shifted == 0 ? 1 : shifted);
}

std::size_t mipPixelCount(std::uint32_t width, std::uint32_t height, std::size_t level) {
    const std::size_t w = mipWidth(width, level);
    const std::size_t h = mipHeight(height, level);
    if (mulWouldOverflow(w, h)) {
        throw TexturePackageFormatError("texture mip dimensions overflow size_t");
    }
    return w * h;
}

void parseMipMetadata(std::span<const std::byte> bytes, TexturePackageEntry& entry, std::vector<std::string>& warnings) {
    if (entry.compression != 0 || !entry.rangeValid || entry.diskSize < MipHeaderSize) {
        return;
    }

    const auto entryOffset = static_cast<std::size_t>(entry.dataOffset);
    const std::string mipName = readFixedName(bytes, entryOffset);
    const std::uint32_t width = readU32LE(bytes, entryOffset + 16);
    const std::uint32_t height = readU32LE(bytes, entryOffset + 20);

    if (!plausibleDimensions(width, height)) {
        return;
    }

    entry.mipMetadataAvailable = true;
    entry.textureName = mipName.empty() ? entry.name : mipName;
    entry.width = width;
    entry.height = height;

    entry.mipOffsetsWithinEntry = true;
    for (std::size_t i = 0; i < entry.mipOffsets.size(); ++i) {
        const std::uint32_t offset = readU32LE(bytes, entryOffset + 24 + i * 4);
        entry.mipOffsets[i] = offset;
        const std::size_t pixels = mipPixelCount(width, height, i);
        const std::size_t begin = static_cast<std::size_t>(offset);
        if (begin < MipHeaderSize || begin > entry.diskSize || pixels > static_cast<std::size_t>(entry.diskSize) - begin) {
            entry.mipOffsetsWithinEntry = false;
        }
    }

    if (!entry.mipOffsetsWithinEntry) {
        warnings.emplace_back("texture entry '" + entry.name + "' has mip offsets outside its data range");
    }
}

std::size_t paletteOffset(const TexturePackageEntry& entry) {
    std::size_t end = MipHeaderSize;
    for (std::size_t i = 0; i < entry.mipOffsets.size(); ++i) {
        const std::size_t mipStart = static_cast<std::size_t>(entry.mipOffsets[i]);
        const std::size_t mipSize = mipPixelCount(entry.width, entry.height, i);
        if (mipStart > static_cast<std::size_t>(entry.diskSize) || mipSize > static_cast<std::size_t>(entry.diskSize) - mipStart) {
            throw TexturePackageFormatError("texture mip data is outside its entry data range: " + entry.name);
        }
        end = std::max(end, mipStart + mipSize);
    }
    return end;
}

} // namespace

std::string_view texturePackageKindName(TexturePackageKind kind) {
    switch (kind) {
        case TexturePackageKind::Wad2:
            return "WAD2";
        case TexturePackageKind::Wad3:
            return "WAD3";
    }

    return "unknown";
}

TexturePackageFormatError::TexturePackageFormatError(const std::string& message)
    : std::runtime_error(message) {}

TexturePackageSummary parseTexturePackageSummary(std::span<const std::byte> bytes) {
    if (bytes.size() < HeaderSize) {
        throw TexturePackageFormatError("file is too small to contain a texture package header");
    }

    TexturePackageSummary summary;
    summary.fileSize = bytes.size();
    summary.magic = readMagic(bytes);

    if (magicEquals(bytes, "WAD2")) {
        summary.kind = TexturePackageKind::Wad2;
    } else if (magicEquals(bytes, "WAD3")) {
        summary.kind = TexturePackageKind::Wad3;
    } else {
        throw TexturePackageFormatError("unsupported texture package magic: " + summary.magic);
    }

    summary.declaredEntryCount = readI32LE(bytes, 4);
    if (summary.declaredEntryCount < 0) {
        throw TexturePackageFormatError("texture package has a negative directory entry count");
    }

    summary.directoryOffset = readU32LE(bytes, 8);
    if (static_cast<std::size_t>(summary.directoryOffset) > bytes.size()) {
        throw TexturePackageFormatError("texture package directory offset is outside the file");
    }

    const auto directoryOffset = static_cast<std::size_t>(summary.directoryOffset);
    const auto entryCount = static_cast<std::size_t>(summary.declaredEntryCount);
    if (entryCount > (bytes.size() - directoryOffset) / DirectoryEntrySize) {
        throw TexturePackageFormatError("texture package directory is truncated");
    }

    summary.entries.reserve(entryCount);
    for (std::size_t i = 0; i < entryCount; ++i) {
        const std::size_t offset = directoryOffset + i * DirectoryEntrySize;
        TexturePackageEntry entry;
        entry.dataOffset = readU32LE(bytes, offset);
        entry.diskSize = readU32LE(bytes, offset + 4);
        entry.uncompressedSize = readU32LE(bytes, offset + 8);
        entry.type = byteAt(bytes, offset + 12);
        entry.compression = byteAt(bytes, offset + 13);
        entry.name = readFixedName(bytes, offset + 16);
        entry.rangeValid = rangeInside(bytes.size(), entry.dataOffset, entry.diskSize);

        if (entry.name.empty()) {
            summary.warnings.emplace_back("texture package contains an entry with an empty name");
        }

        if (!entry.rangeValid) {
            throw TexturePackageFormatError("texture package entry data range is outside the file: " + entry.name);
        }

        parseMipMetadata(bytes, entry, summary.warnings);
        summary.entries.push_back(std::move(entry));
    }

    return summary;
}

std::vector<std::byte> loadTexturePackageBytes(const std::filesystem::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw TexturePackageFormatError("failed to open texture package file: " + path.string());
    }

    std::vector<std::byte> bytes;
    file.seekg(0, std::ios::end);
    const std::streamoff size = file.tellg();
    if (size < 0) {
        throw TexturePackageFormatError("failed to determine texture package file size: " + path.string());
    }

    bytes.resize(static_cast<std::size_t>(size));
    file.seekg(0, std::ios::beg);

    if (!bytes.empty()) {
        file.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
        if (!file) {
            throw TexturePackageFormatError("failed to read texture package file: " + path.string());
        }
    }

    return bytes;
}

TexturePackageSummary loadTexturePackageSummary(const std::filesystem::path& path) {
    std::vector<std::byte> bytes = loadTexturePackageBytes(path);
    return parseTexturePackageSummary(std::span<const std::byte>(bytes.data(), bytes.size()));
}

DecodedTexture decodeIndexedMipTexture(std::span<const std::byte> bytes, const TexturePackageEntry& entry) {
    if (!entry.mipMetadataAvailable) {
        throw TexturePackageFormatError("texture entry does not contain mip texture metadata: " + entry.name);
    }
    if (entry.compression != 0) {
        throw TexturePackageFormatError("compressed texture entries are not supported by the debug decode path: " + entry.name);
    }
    if (!entry.rangeValid || !entry.mipOffsetsWithinEntry) {
        throw TexturePackageFormatError("texture entry has invalid mip data ranges: " + entry.name);
    }

    const std::size_t entryOffset = static_cast<std::size_t>(entry.dataOffset);
    const std::size_t pixelCount = mipPixelCount(entry.width, entry.height, 0);
    const std::size_t mip0Offset = static_cast<std::size_t>(entry.mipOffsets[0]);
    if (mip0Offset > static_cast<std::size_t>(entry.diskSize) || pixelCount > static_cast<std::size_t>(entry.diskSize) - mip0Offset) {
        throw TexturePackageFormatError("first texture mip is outside entry data: " + entry.name);
    }

    const std::size_t relativePaletteOffset = paletteOffset(entry);
    if (relativePaletteOffset > static_cast<std::size_t>(entry.diskSize) || 2 > static_cast<std::size_t>(entry.diskSize) - relativePaletteOffset) {
        throw TexturePackageFormatError("texture entry is missing an embedded palette: " + entry.name);
    }

    const std::size_t paletteHeaderOffset = entryOffset + relativePaletteOffset;
    const std::uint16_t paletteColorCount = readU16LE(bytes, paletteHeaderOffset);
    if (paletteColorCount == 0 || paletteColorCount > MaxPaletteColors) {
        throw TexturePackageFormatError("texture entry has an unsupported palette size: " + entry.name);
    }

    const std::size_t paletteByteCount = static_cast<std::size_t>(paletteColorCount) * 3;
    const std::size_t paletteDataOffset = paletteHeaderOffset + 2;
    if (paletteDataOffset > bytes.size() || paletteByteCount > bytes.size() - paletteDataOffset) {
        throw TexturePackageFormatError("texture entry palette is truncated: " + entry.name);
    }

    DecodedTexture decoded;
    decoded.name = entry.textureName.empty() ? entry.name : entry.textureName;
    decoded.width = entry.width;
    decoded.height = entry.height;
    if (pixelCount > std::numeric_limits<std::size_t>::max() / 4) {
        throw TexturePackageFormatError("decoded texture is too large: " + entry.name);
    }
    decoded.rgba.resize(pixelCount * 4);

    const std::size_t pixelOffset = entryOffset + mip0Offset;
    const bool transparentLastIndex = !decoded.name.empty() && decoded.name.front() == '{';
    for (std::size_t i = 0; i < pixelCount; ++i) {
        const std::uint8_t paletteIndex = byteAt(bytes, pixelOffset + i);
        const std::size_t out = i * 4;
        if (paletteIndex >= paletteColorCount) {
            decoded.rgba[out] = 0;
            decoded.rgba[out + 1] = 0;
            decoded.rgba[out + 2] = 0;
            decoded.rgba[out + 3] = 255;
            continue;
        }

        const std::size_t palette = paletteDataOffset + static_cast<std::size_t>(paletteIndex) * 3;
        decoded.rgba[out] = byteAt(bytes, palette);
        decoded.rgba[out + 1] = byteAt(bytes, palette + 1);
        decoded.rgba[out + 2] = byteAt(bytes, palette + 2);
        decoded.rgba[out + 3] = transparentLastIndex && paletteIndex == 255 ? 0 : 255;
    }

    return decoded;
}

} // namespace osk::texture
