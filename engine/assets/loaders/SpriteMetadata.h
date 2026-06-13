#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace osk::sprite {

class SpriteMetadataFormatError : public std::runtime_error {
public:
    explicit SpriteMetadataFormatError(const std::string& message);
};

struct SpriteHeaderInfo {
    std::string magic;
    std::int32_t version = 0;
    std::int32_t type = 0;
    std::int32_t textureFormat = 0;
    float boundingRadius = 0.0F;
    std::int32_t maxWidth = 0;
    std::int32_t maxHeight = 0;
    std::int32_t frameCount = 0;
    float beamLength = 0.0F;
    std::int32_t syncType = 0;
    std::size_t fileSize = 0;
};

struct SpritePaletteInfo {
    std::uint16_t colorCount = 0;
    std::size_t dataOffset = 0;
    std::size_t dataSize = 0;
};

struct SpriteFrameInfo {
    std::int32_t frameIndex = 0;
    std::int32_t subframeIndex = 0;
    bool grouped = false;
    float interval = 0.0F;
    std::int32_t originX = 0;
    std::int32_t originY = 0;
    std::int32_t width = 0;
    std::int32_t height = 0;
    std::size_t pixelDataOffset = 0;
    std::size_t pixelDataSize = 0;
};

struct SpriteGroupInfo {
    std::int32_t frameIndex = 0;
    std::int32_t subframeCount = 0;
};

struct SpriteMetadataSummary {
    SpriteHeaderInfo header;
    SpritePaletteInfo palette;
    std::vector<SpriteGroupInfo> groups;
    std::vector<SpriteFrameInfo> frames;
    std::vector<std::string> warnings;
};

std::string_view spriteTypeName(std::int32_t type);
std::string_view spriteTextureFormatName(std::int32_t textureFormat);
std::string_view spriteSyncTypeName(std::int32_t syncType);

SpriteMetadataSummary parseSpriteMetadata(std::span<const std::byte> bytes);
SpriteMetadataSummary loadSpriteMetadata(const std::filesystem::path& path);
std::vector<std::byte> loadSpriteMetadataBytes(const std::filesystem::path& path);

} // namespace osk::sprite
