#include "assets/loaders/SpriteMetadata.h"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <exception>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {

constexpr std::size_t HeaderSize = 40;

struct TestFailure : std::runtime_error {
    using std::runtime_error::runtime_error;
};

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw TestFailure(message);
    }
}

template <typename A, typename B>
void requireEqual(const A& actual, const B& expected, const std::string& message) {
    if (!(actual == expected)) {
        std::ostringstream out;
        out << message << " (actual: " << actual << ", expected: " << expected << ")";
        throw TestFailure(out.str());
    }
}

void appendByte(std::vector<std::byte>& bytes, std::uint8_t value) {
    bytes.push_back(static_cast<std::byte>(value));
}

void appendMagic(std::vector<std::byte>& bytes, std::string_view magic) {
    requireEqual(magic.size(), static_cast<std::size_t>(4), "magic size");
    for (char c : magic) {
        appendByte(bytes, static_cast<std::uint8_t>(c));
    }
}

void appendI32LE(std::vector<std::byte>& bytes, std::int32_t value) {
    const auto raw = static_cast<std::uint32_t>(value);
    appendByte(bytes, static_cast<std::uint8_t>(raw & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((raw >> 8U) & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((raw >> 16U) & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((raw >> 24U) & 0xFFU));
}

void appendU16LE(std::vector<std::byte>& bytes, std::uint16_t value) {
    appendByte(bytes, static_cast<std::uint8_t>(value & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 8U) & 0xFFU));
}

void appendF32LE(std::vector<std::byte>& bytes, float value) {
    std::uint32_t raw = 0;
    static_assert(sizeof(raw) == sizeof(value));
    std::memcpy(&raw, &value, sizeof(raw));
    appendI32LE(bytes, static_cast<std::int32_t>(raw));
}

void appendHeader(std::vector<std::byte>& bytes, std::int32_t frameCount = 2) {
    appendMagic(bytes, "IDSP");
    appendI32LE(bytes, 2);
    appendI32LE(bytes, 2);
    appendI32LE(bytes, 1);
    appendF32LE(bytes, 32.0F);
    appendI32LE(bytes, 8);
    appendI32LE(bytes, 8);
    appendI32LE(bytes, frameCount);
    appendF32LE(bytes, 0.0F);
    appendI32LE(bytes, 1);
}

void appendPalette(std::vector<std::byte>& bytes, std::uint16_t colorCount = 3) {
    appendU16LE(bytes, colorCount);
    for (std::uint16_t i = 0; i < colorCount; ++i) {
        appendByte(bytes, static_cast<std::uint8_t>(i));
        appendByte(bytes, static_cast<std::uint8_t>(i + 1));
        appendByte(bytes, static_cast<std::uint8_t>(i + 2));
    }
}

void appendFrame(std::vector<std::byte>& bytes, std::int32_t originX, std::int32_t originY, std::int32_t width, std::int32_t height) {
    appendI32LE(bytes, originX);
    appendI32LE(bytes, originY);
    appendI32LE(bytes, width);
    appendI32LE(bytes, height);
    for (std::int32_t i = 0; i < width * height; ++i) {
        appendByte(bytes, static_cast<std::uint8_t>(i % 3));
    }
}

std::vector<std::byte> makeSyntheticSprite() {
    std::vector<std::byte> bytes;
    appendHeader(bytes);
    appendPalette(bytes);

    appendI32LE(bytes, 0);
    appendFrame(bytes, -4, 4, 4, 4);

    appendI32LE(bytes, 1);
    appendI32LE(bytes, 2);
    appendF32LE(bytes, 0.1F);
    appendF32LE(bytes, 0.2F);
    appendFrame(bytes, -2, 2, 2, 2);
    appendFrame(bytes, -3, 3, 3, 2);

    return bytes;
}

void expectFormatError(const std::vector<std::byte>& bytes, const std::string& message) {
    bool failed = false;
    try {
        (void)osk::sprite::parseSpriteMetadata(bytes);
    } catch (const osk::sprite::SpriteMetadataFormatError&) {
        failed = true;
    }
    require(failed, message);
}

void testValidSyntheticSprite() {
    const std::vector<std::byte> bytes = makeSyntheticSprite();
    const osk::sprite::SpriteMetadataSummary summary = osk::sprite::parseSpriteMetadata(bytes);

    requireEqual(summary.header.magic, std::string("IDSP"), "magic");
    requireEqual(summary.header.version, 2, "version");
    requireEqual(summary.header.type, 2, "type");
    requireEqual(summary.header.textureFormat, 1, "texture format");
    requireEqual(summary.header.maxWidth, 8, "max width");
    requireEqual(summary.header.maxHeight, 8, "max height");
    requireEqual(summary.header.frameCount, 2, "logical frame count");
    requireEqual(summary.palette.colorCount, static_cast<std::uint16_t>(3), "palette color count");
    requireEqual(summary.palette.dataOffset, HeaderSize + 2, "palette data offset");
    requireEqual(summary.palette.dataSize, static_cast<std::size_t>(9), "palette data size");
    requireEqual(summary.groups.size(), static_cast<std::size_t>(1), "group count");
    requireEqual(summary.groups[0].frameIndex, 1, "group frame index");
    requireEqual(summary.groups[0].subframeCount, 2, "group subframe count");
    requireEqual(summary.frames.size(), static_cast<std::size_t>(3), "physical frame count");
    require(!summary.frames[0].grouped, "first frame is single");
    requireEqual(summary.frames[0].width, 4, "first frame width");
    requireEqual(summary.frames[0].pixelDataSize, static_cast<std::size_t>(16), "first frame pixels");
    require(summary.frames[1].grouped, "second physical frame is grouped");
    requireEqual(summary.frames[1].frameIndex, 1, "grouped logical frame index");
    requireEqual(summary.frames[1].subframeIndex, 0, "first subframe index");
    requireEqual(summary.frames[2].subframeIndex, 1, "second subframe index");
    require(summary.warnings.empty(), "valid synthetic sprite should not warn");
}

void testTrailingBytesWarn() {
    std::vector<std::byte> bytes = makeSyntheticSprite();
    appendByte(bytes, 0xAA);

    const osk::sprite::SpriteMetadataSummary summary = osk::sprite::parseSpriteMetadata(bytes);
    requireEqual(summary.warnings.size(), static_cast<std::size_t>(1), "trailing byte warning count");
}

void testNames() {
    requireEqual(osk::sprite::spriteTypeName(2), std::string_view("VP_PARALLEL"), "sprite type name");
    requireEqual(osk::sprite::spriteTextureFormatName(1), std::string_view("SPR_ADDITIVE"), "texture format name");
    requireEqual(osk::sprite::spriteSyncTypeName(1), std::string_view("random"), "sync type name");
}

void testMalformedInputs() {
    expectFormatError(std::vector<std::byte>(HeaderSize - 1, std::byte{0}), "short header should throw");

    std::vector<std::byte> badMagic = makeSyntheticSprite();
    badMagic.at(0) = static_cast<std::byte>('N');
    expectFormatError(badMagic, "bad magic should throw");

    std::vector<std::byte> badVersion = makeSyntheticSprite();
    badVersion.at(4) = static_cast<std::byte>(1);
    expectFormatError(badVersion, "bad version should throw");

    std::vector<std::byte> negativeFrames;
    appendHeader(negativeFrames, -1);
    appendPalette(negativeFrames);
    expectFormatError(negativeFrames, "negative frame count should throw");

    std::vector<std::byte> truncatedPalette;
    appendHeader(truncatedPalette, 1);
    appendU16LE(truncatedPalette, 3);
    appendByte(truncatedPalette, 1);
    expectFormatError(truncatedPalette, "truncated palette should throw");

    std::vector<std::byte> unknownFrameType;
    appendHeader(unknownFrameType, 1);
    appendPalette(unknownFrameType);
    appendI32LE(unknownFrameType, 99);
    expectFormatError(unknownFrameType, "unknown frame type should throw");

    std::vector<std::byte> truncatedPixels;
    appendHeader(truncatedPixels, 1);
    appendPalette(truncatedPixels);
    appendI32LE(truncatedPixels, 0);
    appendI32LE(truncatedPixels, 0);
    appendI32LE(truncatedPixels, 0);
    appendI32LE(truncatedPixels, 2);
    appendI32LE(truncatedPixels, 2);
    appendByte(truncatedPixels, 0);
    expectFormatError(truncatedPixels, "truncated pixels should throw");

    std::vector<std::byte> emptyGroup;
    appendHeader(emptyGroup, 1);
    appendPalette(emptyGroup);
    appendI32LE(emptyGroup, 1);
    appendI32LE(emptyGroup, 0);
    expectFormatError(emptyGroup, "empty group should throw");

    std::vector<std::byte> badInterval;
    appendHeader(badInterval, 1);
    appendPalette(badInterval);
    appendI32LE(badInterval, 1);
    appendI32LE(badInterval, 1);
    appendF32LE(badInterval, 0.0F);
    appendFrame(badInterval, 0, 0, 1, 1);
    expectFormatError(badInterval, "bad interval should throw");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"valid synthetic sprite", testValidSyntheticSprite},
        {"trailing bytes warning", testTrailingBytesWarn},
        {"enum names", testNames},
        {"malformed inputs", testMalformedInputs},
    };

    int failures = 0;
    for (const TestCase& test : tests) {
        try {
            test.function();
            std::cout << "[PASS] " << test.name << '\n';
        } catch (const std::exception& e) {
            ++failures;
            std::cerr << "[FAIL] " << test.name << ": " << e.what() << '\n';
        }
    }

    return failures == 0 ? 0 : 1;
}
