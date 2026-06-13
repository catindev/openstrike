#include "assets/loaders/ModelMetadata.h"

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

constexpr std::size_t HeaderSize = 244;
constexpr std::size_t BodyPartSize = 76;
constexpr std::size_t SequenceSize = 176;
constexpr std::size_t TextureSize = 80;
constexpr std::size_t HitboxSize = 32;

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

void putByte(std::vector<std::byte>& bytes, std::size_t offset, std::uint8_t value) {
    bytes.at(offset) = static_cast<std::byte>(value);
}

void putI32LE(std::vector<std::byte>& bytes, std::size_t offset, std::int32_t value) {
    const auto raw = static_cast<std::uint32_t>(value);
    putByte(bytes, offset, static_cast<std::uint8_t>(raw & 0xFFU));
    putByte(bytes, offset + 1, static_cast<std::uint8_t>((raw >> 8U) & 0xFFU));
    putByte(bytes, offset + 2, static_cast<std::uint8_t>((raw >> 16U) & 0xFFU));
    putByte(bytes, offset + 3, static_cast<std::uint8_t>((raw >> 24U) & 0xFFU));
}

void putF32LE(std::vector<std::byte>& bytes, std::size_t offset, float value) {
    std::uint32_t raw = 0;
    static_assert(sizeof(raw) == sizeof(value));
    std::memcpy(&raw, &value, sizeof(raw));
    putI32LE(bytes, offset, static_cast<std::int32_t>(raw));
}

void putName(std::vector<std::byte>& bytes, std::size_t offset, std::size_t maxLength, std::string_view name) {
    for (std::size_t i = 0; i < maxLength; ++i) {
        const std::uint8_t value = i < name.size() ? static_cast<std::uint8_t>(name[i]) : 0;
        putByte(bytes, offset + i, value);
    }
}

void putVec3(std::vector<std::byte>& bytes, std::size_t offset, float x, float y, float z) {
    putF32LE(bytes, offset, x);
    putF32LE(bytes, offset + 4, y);
    putF32LE(bytes, offset + 8, z);
}

std::vector<std::byte> makeSyntheticModel() {
    constexpr std::size_t BodyPartOffset = HeaderSize;
    constexpr std::size_t SequenceOffset = BodyPartOffset + BodyPartSize;
    constexpr std::size_t TextureOffset = SequenceOffset + SequenceSize;
    constexpr std::size_t HitboxOffset = TextureOffset + TextureSize;
    constexpr std::size_t FileSize = HitboxOffset + HitboxSize;

    std::vector<std::byte> bytes(FileSize, std::byte{0});

    putName(bytes, 0, 4, "IDST");
    putI32LE(bytes, 4, 10);
    putName(bytes, 8, 64, "synthetic_player");
    putI32LE(bytes, 72, static_cast<std::int32_t>(FileSize));
    putVec3(bytes, 76, 0.0F, 0.0F, 64.0F);
    putVec3(bytes, 88, -16.0F, -16.0F, 0.0F);
    putVec3(bytes, 100, 16.0F, 16.0F, 72.0F);
    putVec3(bytes, 112, -20.0F, -20.0F, -4.0F);
    putVec3(bytes, 124, 20.0F, 20.0F, 76.0F);
    putI32LE(bytes, 136, 7);

    putI32LE(bytes, 156, 1);
    putI32LE(bytes, 160, static_cast<std::int32_t>(HitboxOffset));
    putI32LE(bytes, 164, 1);
    putI32LE(bytes, 168, static_cast<std::int32_t>(SequenceOffset));
    putI32LE(bytes, 180, 1);
    putI32LE(bytes, 184, static_cast<std::int32_t>(TextureOffset));
    putI32LE(bytes, 188, 0);
    putI32LE(bytes, 192, 1);
    putI32LE(bytes, 196, 1);
    putI32LE(bytes, 200, 0);
    putI32LE(bytes, 204, 1);
    putI32LE(bytes, 208, static_cast<std::int32_t>(BodyPartOffset));

    putName(bytes, BodyPartOffset, 64, "body");
    putI32LE(bytes, BodyPartOffset + 64, 1);
    putI32LE(bytes, BodyPartOffset + 68, 1);
    putI32LE(bytes, BodyPartOffset + 72, 320);

    putName(bytes, SequenceOffset, 32, "idle");
    putF32LE(bytes, SequenceOffset + 32, 30.0F);
    putI32LE(bytes, SequenceOffset + 36, 2);
    putI32LE(bytes, SequenceOffset + 40, 101);
    putI32LE(bytes, SequenceOffset + 44, 5);
    putI32LE(bytes, SequenceOffset + 48, 0);
    putI32LE(bytes, SequenceOffset + 52, 0);
    putI32LE(bytes, SequenceOffset + 56, 12);
    putI32LE(bytes, SequenceOffset + 60, 0);
    putI32LE(bytes, SequenceOffset + 64, 0);
    putI32LE(bytes, SequenceOffset + 68, 0);
    putI32LE(bytes, SequenceOffset + 72, -1);
    putVec3(bytes, SequenceOffset + 76, 1.0F, 2.0F, 3.0F);
    putVec3(bytes, SequenceOffset + 96, -4.0F, -5.0F, -6.0F);
    putVec3(bytes, SequenceOffset + 108, 4.0F, 5.0F, 6.0F);
    putI32LE(bytes, SequenceOffset + 120, 1);
    putI32LE(bytes, SequenceOffset + 124, 512);
    putI32LE(bytes, SequenceOffset + 156, 0);
    putI32LE(bytes, SequenceOffset + 160, 0);
    putI32LE(bytes, SequenceOffset + 164, 0);
    putI32LE(bytes, SequenceOffset + 168, 0);
    putI32LE(bytes, SequenceOffset + 172, 0);

    putName(bytes, TextureOffset, 64, "body_texture");
    putI32LE(bytes, TextureOffset + 64, 3);
    putI32LE(bytes, TextureOffset + 68, 64);
    putI32LE(bytes, TextureOffset + 72, 32);
    putI32LE(bytes, TextureOffset + 76, 1024);

    putI32LE(bytes, HitboxOffset, 0);
    putI32LE(bytes, HitboxOffset + 4, 2);
    putVec3(bytes, HitboxOffset + 8, -1.0F, -2.0F, -3.0F);
    putVec3(bytes, HitboxOffset + 20, 1.0F, 2.0F, 3.0F);

    return bytes;
}

void expectFormatError(const std::vector<std::byte>& bytes, const std::string& message) {
    bool failed = false;
    try {
        (void)osk::model::parseModelMetadata(bytes);
    } catch (const osk::model::ModelMetadataFormatError&) {
        failed = true;
    }
    require(failed, message);
}

void testValidSyntheticModel() {
    const std::vector<std::byte> bytes = makeSyntheticModel();
    const osk::model::ModelMetadataSummary summary = osk::model::parseModelMetadata(bytes);

    requireEqual(summary.header.magic, std::string("IDST"), "magic");
    requireEqual(summary.header.version, 10, "version");
    requireEqual(summary.header.name, std::string("synthetic_player"), "model name");
    requireEqual(summary.header.flags, 7, "flags");
    require(summary.warnings.empty(), "valid synthetic model should not warn");

    requireEqual(summary.bodyParts.size(), static_cast<std::size_t>(1), "body part count");
    requireEqual(summary.bodyParts[0].name, std::string("body"), "body part name");
    requireEqual(summary.bodyParts[0].modelCount, 1, "body part model count");

    requireEqual(summary.sequences.size(), static_cast<std::size_t>(1), "sequence count");
    requireEqual(summary.sequences[0].label, std::string("idle"), "sequence label");
    requireEqual(summary.sequences[0].frameCount, 12, "sequence frame count");
    requireEqual(summary.sequences[0].activity, 101, "sequence activity");

    requireEqual(summary.textures.size(), static_cast<std::size_t>(1), "texture count");
    requireEqual(summary.textures[0].name, std::string("body_texture"), "texture name");
    requireEqual(summary.textures[0].width, 64, "texture width");
    requireEqual(summary.textures[0].height, 32, "texture height");

    requireEqual(summary.hitboxes.size(), static_cast<std::size_t>(1), "hitbox count");
    requireEqual(summary.hitboxes[0].bone, 0, "hitbox bone");
    requireEqual(summary.hitboxes[0].group, 2, "hitbox group");
}

void testWarningsForDeclaredLengthMismatch() {
    std::vector<std::byte> bytes = makeSyntheticModel();
    putI32LE(bytes, 72, static_cast<std::int32_t>(bytes.size() + 16));

    const osk::model::ModelMetadataSummary summary = osk::model::parseModelMetadata(bytes);
    requireEqual(summary.warnings.size(), static_cast<std::size_t>(1), "declared length warning count");
}

void testMalformedInputs() {
    expectFormatError(std::vector<std::byte>(HeaderSize - 1, std::byte{0}), "short header should throw");

    std::vector<std::byte> badMagic = makeSyntheticModel();
    putName(badMagic, 0, 4, "NOPE");
    expectFormatError(badMagic, "bad magic should throw");

    std::vector<std::byte> badVersion = makeSyntheticModel();
    putI32LE(badVersion, 4, 9);
    expectFormatError(badVersion, "bad version should throw");

    std::vector<std::byte> negativeCount = makeSyntheticModel();
    putI32LE(negativeCount, 180, -1);
    expectFormatError(negativeCount, "negative texture count should throw");

    std::vector<std::byte> overlappingTable = makeSyntheticModel();
    putI32LE(overlappingTable, 184, 12);
    expectFormatError(overlappingTable, "table overlapping header should throw");

    std::vector<std::byte> truncatedTexture = makeSyntheticModel();
    truncatedTexture.resize(truncatedTexture.size() - 1);
    expectFormatError(truncatedTexture, "truncated texture table should throw");

    std::vector<std::byte> negativeTextureWidth = makeSyntheticModel();
    constexpr std::size_t TextureOffset = HeaderSize + BodyPartSize + SequenceSize;
    putI32LE(negativeTextureWidth, TextureOffset + 68, -64);
    expectFormatError(negativeTextureWidth, "negative texture width should throw");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"valid synthetic model", testValidSyntheticModel},
        {"declared length mismatch warning", testWarningsForDeclaredLengthMismatch},
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
