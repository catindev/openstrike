#include "assets/loaders/BspLight.h"
#include "assets/loaders/BspLoader.h"
#include "assets/loaders/BspTypes.h"

#include <bit>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr std::size_t BspHeaderSize = 4 + osk::bsp::LumpCount * 8;

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

void writeU16LE(std::vector<std::byte>& bytes, std::size_t offset, std::uint16_t value) {
    bytes.at(offset) = static_cast<std::byte>(value & 0xFFU);
    bytes.at(offset + 1) = static_cast<std::byte>((value >> 8U) & 0xFFU);
}

void writeU32LE(std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value) {
    bytes.at(offset) = static_cast<std::byte>(value & 0xFFU);
    bytes.at(offset + 1) = static_cast<std::byte>((value >> 8U) & 0xFFU);
    bytes.at(offset + 2) = static_cast<std::byte>((value >> 16U) & 0xFFU);
    bytes.at(offset + 3) = static_cast<std::byte>((value >> 24U) & 0xFFU);
}

void writeI16LE(std::vector<std::byte>& bytes, std::size_t offset, std::int16_t value) {
    writeU16LE(bytes, offset, static_cast<std::uint16_t>(value));
}

void writeI32LE(std::vector<std::byte>& bytes, std::size_t offset, std::int32_t value) {
    writeU32LE(bytes, offset, static_cast<std::uint32_t>(value));
}

void writeF32LE(std::vector<std::byte>& bytes, std::size_t offset, float value) {
    writeU32LE(bytes, offset, std::bit_cast<std::uint32_t>(value));
}

void setLump(std::vector<std::byte>& bytes, osk::bsp::LumpId id, std::uint32_t offset, std::uint32_t length) {
    const std::size_t headerOffset = 4 + static_cast<std::size_t>(id) * 8;
    writeU32LE(bytes, headerOffset, offset);
    writeU32LE(bytes, headerOffset + 4, length);
}

std::uint32_t appendLump(std::vector<std::byte>& bytes, osk::bsp::LumpId id, const std::vector<std::byte>& lumpBytes) {
    const auto offset = static_cast<std::uint32_t>(bytes.size());
    bytes.insert(bytes.end(), lumpBytes.begin(), lumpBytes.end());
    setLump(bytes, id, offset, static_cast<std::uint32_t>(lumpBytes.size()));
    return offset;
}

std::vector<std::byte> makeVertices() {
    std::vector<std::byte> bytes(4 * 12, std::byte{0});
    const float values[4][3]{{0.0F, 0.0F, 0.0F}, {32.0F, 0.0F, 0.0F}, {32.0F, 32.0F, 0.0F}, {0.0F, 32.0F, 0.0F}};
    for (std::size_t i = 0; i < 4; ++i) {
        writeF32LE(bytes, i * 12, values[i][0]);
        writeF32LE(bytes, i * 12 + 4, values[i][1]);
        writeF32LE(bytes, i * 12 + 8, values[i][2]);
    }
    return bytes;
}

std::vector<std::byte> makeEdges() {
    std::vector<std::byte> bytes(4 * 4, std::byte{0});
    const std::uint16_t values[4][2]{{0, 1}, {1, 2}, {2, 3}, {3, 0}};
    for (std::size_t i = 0; i < 4; ++i) {
        writeU16LE(bytes, i * 4, values[i][0]);
        writeU16LE(bytes, i * 4 + 2, values[i][1]);
    }
    return bytes;
}

std::vector<std::byte> makeSurfEdges() {
    std::vector<std::byte> bytes(4 * 4, std::byte{0});
    for (std::int32_t i = 0; i < 4; ++i) {
        writeI32LE(bytes, static_cast<std::size_t>(i) * 4, i);
    }
    return bytes;
}

std::vector<std::byte> makeTexInfo() {
    std::vector<std::byte> bytes(40, std::byte{0});
    writeF32LE(bytes, 0, 1.0F);
    writeF32LE(bytes, 20, 1.0F);
    writeI32LE(bytes, 32, 7);
    return bytes;
}

std::vector<std::byte> makeFace(std::int32_t lightOffset) {
    std::vector<std::byte> bytes(20, std::byte{0});
    writeU16LE(bytes, 0, 0);
    writeU16LE(bytes, 2, 0);
    writeI32LE(bytes, 4, 0);
    writeI16LE(bytes, 8, 4);
    writeI16LE(bytes, 10, 0);
    bytes[12] = std::byte{0};
    bytes[13] = static_cast<std::byte>(255);
    bytes[14] = static_cast<std::byte>(255);
    bytes[15] = static_cast<std::byte>(255);
    writeI32LE(bytes, 16, lightOffset);
    return bytes;
}

std::vector<std::byte> makeBsp(std::int32_t lightOffset, std::size_t lightingBytes) {
    std::vector<std::byte> bytes(BspHeaderSize, std::byte{0});
    writeI32LE(bytes, 0, osk::bsp::GoldSrcBspVersion);

    appendLump(bytes, osk::bsp::LumpId::Vertices, makeVertices());
    appendLump(bytes, osk::bsp::LumpId::Edges, makeEdges());
    appendLump(bytes, osk::bsp::LumpId::SurfEdges, makeSurfEdges());
    appendLump(bytes, osk::bsp::LumpId::TexInfo, makeTexInfo());
    appendLump(bytes, osk::bsp::LumpId::Faces, makeFace(lightOffset));
    if (lightingBytes > 0) {
        appendLump(bytes, osk::bsp::LumpId::Lighting, std::vector<std::byte>(lightingBytes, std::byte{128}));
    }

    return bytes;
}

void testValidLightMetadata() {
    const std::vector<std::byte> bytes = makeBsp(0, 27);
    const osk::bsp::BspSummary summary = osk::bsp::parseBspSummary(bytes);
    const osk::bsp::BspLightSummary light = osk::bsp::parseBspLightSummary(bytes, summary);

    requireEqual(light.lightingByteCount, static_cast<std::size_t>(27), "lighting byte count");
    requireEqual(light.faceCount, static_cast<std::size_t>(1), "face count");
    requireEqual(light.litFaceCount, static_cast<std::size_t>(1), "lit face count");
    requireEqual(light.validLightmapCount, static_cast<std::size_t>(1), "valid lightmap count");
    requireEqual(light.invalidLightmapCount, static_cast<std::size_t>(0), "invalid lightmap count");
    requireEqual(light.missingLightmapCount, static_cast<std::size_t>(0), "missing lightmap count");
    require(light.warnings.empty(), "valid synthetic light data should not warn");

    const osk::bsp::BspLightFaceInfo& face = light.faces.front();
    require(face.hasLightingData, "face should have lighting data");
    require(face.geometryValid, "face geometry should be valid");
    require(face.rangeValid, "face light range should be valid");
    requireEqual(face.lightOffset, 0, "light offset");
    requireEqual(face.lightmapWidth, static_cast<std::uint32_t>(3), "lightmap width");
    requireEqual(face.lightmapHeight, static_cast<std::uint32_t>(3), "lightmap height");
    requireEqual(face.sampleCount, static_cast<std::size_t>(9), "sample count");
    requireEqual(face.byteCount, static_cast<std::size_t>(27), "byte count");
    requireEqual(face.activeStyleCount, static_cast<std::size_t>(1), "active style count");
    requireEqual(face.styles[0], static_cast<std::uint8_t>(0), "first style");
    requireEqual(face.textureIndex, 7, "texture index");
}

void testMissingLightingDoesNotCrash() {
    const std::vector<std::byte> bytes = makeBsp(-1, 0);
    const osk::bsp::BspSummary summary = osk::bsp::parseBspSummary(bytes);
    const osk::bsp::BspLightSummary light = osk::bsp::parseBspLightSummary(bytes, summary);

    requireEqual(light.faceCount, static_cast<std::size_t>(1), "face count");
    requireEqual(light.litFaceCount, static_cast<std::size_t>(0), "lit face count");
    requireEqual(light.validLightmapCount, static_cast<std::size_t>(0), "valid lightmap count");
    requireEqual(light.invalidLightmapCount, static_cast<std::size_t>(0), "invalid lightmap count");
    requireEqual(light.missingLightmapCount, static_cast<std::size_t>(1), "missing lightmap count");
    require(!light.faces.front().hasLightingData, "face should report missing lighting data");
}

void testTruncatedLightingIsReported() {
    const std::vector<std::byte> bytes = makeBsp(0, 12);
    const osk::bsp::BspSummary summary = osk::bsp::parseBspSummary(bytes);
    const osk::bsp::BspLightSummary light = osk::bsp::parseBspLightSummary(bytes, summary);

    requireEqual(light.faceCount, static_cast<std::size_t>(1), "face count");
    requireEqual(light.litFaceCount, static_cast<std::size_t>(1), "lit face count");
    requireEqual(light.validLightmapCount, static_cast<std::size_t>(0), "valid lightmap count");
    requireEqual(light.invalidLightmapCount, static_cast<std::size_t>(1), "invalid lightmap count");
    requireEqual(light.missingLightmapCount, static_cast<std::size_t>(0), "missing lightmap count");
    require(!light.faces.front().rangeValid, "truncated light range should be invalid");
    require(!light.warnings.empty(), "truncated lighting should warn");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"valid light metadata", testValidLightMetadata},
        {"missing lighting does not crash", testMissingLightingDoesNotCrash},
        {"truncated lighting is reported", testTruncatedLightingIsReported},
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
