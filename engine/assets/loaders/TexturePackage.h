#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace osk::texture {

enum class TexturePackageKind {
    Wad2,
    Wad3,
};

std::string_view texturePackageKindName(TexturePackageKind kind);

class TexturePackageFormatError : public std::runtime_error {
public:
    explicit TexturePackageFormatError(const std::string& message);
};

struct TexturePackageEntry {
    std::string name;
    std::uint32_t dataOffset = 0;
    std::uint32_t diskSize = 0;
    std::uint32_t uncompressedSize = 0;
    std::uint8_t type = 0;
    std::uint8_t compression = 0;
    bool rangeValid = false;

    bool mipMetadataAvailable = false;
    std::string textureName;
    std::uint32_t width = 0;
    std::uint32_t height = 0;
    std::array<std::uint32_t, 4> mipOffsets{};
    bool mipOffsetsWithinEntry = false;
};

struct TexturePackageSummary {
    TexturePackageKind kind = TexturePackageKind::Wad3;
    std::string magic;
    std::size_t fileSize = 0;
    std::int32_t declaredEntryCount = 0;
    std::uint32_t directoryOffset = 0;
    std::vector<TexturePackageEntry> entries;
    std::vector<std::string> warnings;
};

struct DecodedTexture {
    std::string name;
    std::uint32_t width = 0;
    std::uint32_t height = 0;
    std::vector<std::uint8_t> rgba;
};

TexturePackageSummary parseTexturePackageSummary(std::span<const std::byte> bytes);
TexturePackageSummary loadTexturePackageSummary(const std::filesystem::path& path);
std::vector<std::byte> loadTexturePackageBytes(const std::filesystem::path& path);
DecodedTexture decodeIndexedMipTexture(std::span<const std::byte> bytes, const TexturePackageEntry& entry);

} // namespace osk::texture
