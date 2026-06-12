#include "assets/loaders/TexturePackage.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {

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

void appendU32LE(std::vector<std::byte>& bytes, std::uint32_t value) {
    appendByte(bytes, static_cast<std::uint8_t>(value & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 8U) & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 16U) & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 24U) & 0xFFU));
}

void putU32LE(std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value) {
    bytes.at(offset) = static_cast<std::byte>(value & 0xFFU);
    bytes.at(offset + 1) = static_cast<std::byte>((value >> 8U) & 0xFFU);
    bytes.at(offset + 2) = static_cast<std::byte>((value >> 16U) & 0xFFU);
    bytes.at(offset + 3) = static_cast<std::byte>((value >> 24U) & 0xFFU);
}

void writeNameAt(std::vector<std::byte>& bytes, std::size_t offset, std::string_view name) {
    for (std::size_t i = 0; i < 16; ++i) {
        const std::uint8_t value = i < name.size() ? static_cast<std::uint8_t>(name[i]) : 0;
        bytes.at(offset + i) = static_cast<std::byte>(value);
    }
}

void appendName(std::vector<std::byte>& bytes, std::string_view name) {
    for (std::size_t i = 0; i < 16; ++i) {
        const std::uint8_t value = i < name.size() ? static_cast<std::uint8_t>(name[i]) : 0;
        appendByte(bytes, value);
    }
}

void appendDirectoryEntry(
    std::vector<std::byte>& bytes,
    std::uint32_t filePosition,
    std::uint32_t diskSize,
    std::uint32_t uncompressedSize,
    std::uint8_t type,
    std::uint8_t compression,
    std::string_view name) {
    appendU32LE(bytes, filePosition);
    appendU32LE(bytes, diskSize);
    appendU32LE(bytes, uncompressedSize);
    appendByte(bytes, type);
    appendByte(bytes, compression);
    appendByte(bytes, 0);
    appendByte(bytes, 0);
    appendName(bytes, name);
}

std::vector<std::byte> makeSyntheticPackage(std::string_view magic = "WAD3") {
    std::vector<std::byte> bytes;
    appendMagic(bytes, magic);
    appendU32LE(bytes, 2);
    appendU32LE(bytes, 0); // Patched with directory offset below.

    constexpr std::uint32_t Width = 64;
    constexpr std::uint32_t Height = 32;
    constexpr std::array<std::uint32_t, 4> MipOffsets{40, 2088, 2600, 2728};
    constexpr std::uint32_t StoneSize = 2760;

    const auto stoneOffset = static_cast<std::uint32_t>(bytes.size());
    bytes.resize(bytes.size() + StoneSize, std::byte{0});
    writeNameAt(bytes, stoneOffset, "STONE");
    putU32LE(bytes, stoneOffset + 16, Width);
    putU32LE(bytes, stoneOffset + 20, Height);
    for (std::size_t i = 0; i < MipOffsets.size(); ++i) {
        putU32LE(bytes, stoneOffset + 24 + i * 4, MipOffsets[i]);
    }

    const auto infoOffset = static_cast<std::uint32_t>(bytes.size());
    appendByte(bytes, 1);
    appendByte(bytes, 2);
    appendByte(bytes, 3);
    appendByte(bytes, 4);

    const auto directoryOffset = static_cast<std::uint32_t>(bytes.size());
    putU32LE(bytes, 8, directoryOffset);
    appendDirectoryEntry(bytes, stoneOffset, StoneSize, StoneSize, 0x43, 0, "STONE");
    appendDirectoryEntry(bytes, infoOffset, 4, 4, 0x40, 0, "INFO");

    return bytes;
}

void testValidSyntheticPackage() {
    const std::vector<std::byte> bytes = makeSyntheticPackage();
    const osk::texture::TexturePackageSummary summary = osk::texture::parseTexturePackageSummary(bytes);

    require(summary.kind == osk::texture::TexturePackageKind::Wad3, "WAD3 kind");
    requireEqual(summary.magic, std::string("WAD3"), "magic");
    requireEqual(summary.declaredEntryCount, 2, "declared entry count");
    requireEqual(summary.entries.size(), static_cast<std::size_t>(2), "parsed entry count");
    require(summary.warnings.empty(), "valid synthetic package should not warn");

    const osk::texture::TexturePackageEntry& texture = summary.entries[0];
    requireEqual(texture.name, std::string("STONE"), "directory texture name");
    require(texture.rangeValid, "texture range valid");
    require(texture.mipMetadataAvailable, "mip metadata should parse");
    requireEqual(texture.textureName, std::string("STONE"), "mip texture name");
    requireEqual(texture.width, static_cast<std::uint32_t>(64), "mip width");
    requireEqual(texture.height, static_cast<std::uint32_t>(32), "mip height");
    requireEqual(texture.mipOffsets[0], static_cast<std::uint32_t>(40), "first mip offset");
    requireEqual(texture.mipOffsets[3], static_cast<std::uint32_t>(2728), "fourth mip offset");
    require(texture.mipOffsetsWithinEntry, "mip offsets within entry");

    const osk::texture::TexturePackageEntry& info = summary.entries[1];
    requireEqual(info.name, std::string("INFO"), "non-texture entry name");
    require(!info.mipMetadataAvailable, "non-texture entry should not expose mip metadata");
}

void testWad2Magic() {
    const std::vector<std::byte> bytes = makeSyntheticPackage("WAD2");
    const osk::texture::TexturePackageSummary summary = osk::texture::parseTexturePackageSummary(bytes);
    require(summary.kind == osk::texture::TexturePackageKind::Wad2, "WAD2 kind");
    requireEqual(summary.magic, std::string("WAD2"), "WAD2 magic");
}

void testMalformedInputs() {
    bool shortHeaderFailed = false;
    try {
        std::vector<std::byte> bytes(11, std::byte{0});
        (void)osk::texture::parseTexturePackageSummary(bytes);
    } catch (const osk::texture::TexturePackageFormatError&) {
        shortHeaderFailed = true;
    }
    require(shortHeaderFailed, "short header should throw");

    bool badMagicFailed = false;
    try {
        std::vector<std::byte> bytes;
        appendMagic(bytes, "NOPE");
        appendU32LE(bytes, 0);
        appendU32LE(bytes, 12);
        (void)osk::texture::parseTexturePackageSummary(bytes);
    } catch (const osk::texture::TexturePackageFormatError&) {
        badMagicFailed = true;
    }
    require(badMagicFailed, "bad magic should throw");

    bool negativeCountFailed = false;
    try {
        std::vector<std::byte> bytes;
        appendMagic(bytes, "WAD3");
        appendU32LE(bytes, 0xFFFFFFFFU);
        appendU32LE(bytes, 12);
        (void)osk::texture::parseTexturePackageSummary(bytes);
    } catch (const osk::texture::TexturePackageFormatError&) {
        negativeCountFailed = true;
    }
    require(negativeCountFailed, "negative count should throw");

    bool truncatedDirectoryFailed = false;
    try {
        std::vector<std::byte> bytes;
        appendMagic(bytes, "WAD3");
        appendU32LE(bytes, 1);
        appendU32LE(bytes, 12);
        (void)osk::texture::parseTexturePackageSummary(bytes);
    } catch (const osk::texture::TexturePackageFormatError&) {
        truncatedDirectoryFailed = true;
    }
    require(truncatedDirectoryFailed, "truncated directory should throw");

    bool entryRangeFailed = false;
    try {
        std::vector<std::byte> bytes;
        appendMagic(bytes, "WAD3");
        appendU32LE(bytes, 1);
        appendU32LE(bytes, 12);
        appendDirectoryEntry(bytes, 999, 4, 4, 0x43, 0, "BROKEN");
        (void)osk::texture::parseTexturePackageSummary(bytes);
    } catch (const osk::texture::TexturePackageFormatError&) {
        entryRangeFailed = true;
    }
    require(entryRangeFailed, "entry range outside file should throw");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"valid synthetic package", testValidSyntheticPackage},
        {"WAD2 magic", testWad2Magic},
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
