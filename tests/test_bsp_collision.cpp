#include "assets/loaders/BspCollision.h"
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
constexpr const char* UnsupportedHullWarning = "trace hull index is unsupported; clipnode prototype supports hulls 1..3";

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

void appendLump(std::vector<std::byte>& bytes, osk::bsp::LumpId id, const std::vector<std::byte>& lumpBytes) {
    const auto offset = static_cast<std::uint32_t>(bytes.size());
    bytes.insert(bytes.end(), lumpBytes.begin(), lumpBytes.end());
    setLump(bytes, id, offset, static_cast<std::uint32_t>(lumpBytes.size()));
}

std::vector<std::byte> makePlanes() {
    std::vector<std::byte> bytes(20, std::byte{0});
    writeF32LE(bytes, 0, 1.0F);
    writeF32LE(bytes, 4, 0.0F);
    writeF32LE(bytes, 8, 0.0F);
    writeF32LE(bytes, 12, 0.0F);
    writeI32LE(bytes, 16, 0);
    return bytes;
}

std::vector<std::byte> makeClipNodes() {
    std::vector<std::byte> bytes(8, std::byte{0});
    writeI32LE(bytes, 0, 0);
    writeI16LE(bytes, 4, osk::bsp::BspContentsEmpty);
    writeI16LE(bytes, 6, osk::bsp::BspContentsSolid);
    return bytes;
}

std::vector<std::byte> makeModels() {
    std::vector<std::byte> bytes(64, std::byte{0});
    writeI32LE(bytes, 36, -1);
    writeI32LE(bytes, 40, 0);
    writeI32LE(bytes, 44, -1);
    writeI32LE(bytes, 48, -1);
    return bytes;
}

std::vector<std::byte> makeCollisionBsp(bool includeClipNodes = true) {
    std::vector<std::byte> bytes(BspHeaderSize, std::byte{0});
    writeI32LE(bytes, 0, osk::bsp::GoldSrcBspVersion);
    appendLump(bytes, osk::bsp::LumpId::Planes, makePlanes());
    if (includeClipNodes) {
        appendLump(bytes, osk::bsp::LumpId::ClipNodes, makeClipNodes());
    }
    appendLump(bytes, osk::bsp::LumpId::Models, makeModels());
    return bytes;
}

osk::bsp::BspCollisionData loadSyntheticCollision(bool includeClipNodes = true) {
    const std::vector<std::byte> bytes = makeCollisionBsp(includeClipNodes);
    const osk::bsp::BspSummary summary = osk::bsp::parseBspSummary(bytes);
    return osk::bsp::parseBspCollisionData(bytes, summary);
}

void testParseCollisionTables() {
    const osk::bsp::BspCollisionData collision = loadSyntheticCollision();
    requireEqual(collision.planes.size(), static_cast<std::size_t>(1), "plane count");
    requireEqual(collision.clipNodes.size(), static_cast<std::size_t>(1), "clipnode count");
    requireEqual(collision.models.size(), static_cast<std::size_t>(1), "model count");
    require(collision.warnings.empty(), "valid collision data should not warn");
    requireEqual(collision.models.front().headNodes[1], 0, "model hull 1 headnode");
}

void testHullZeroRejected() {
    const osk::bsp::BspCollisionData collision = loadSyntheticCollision();
    osk::bsp::BspTraceInput input;
    input.hullIndex = 0;
    input.start = osk::bsp::Vec3{.x = 10.0F, .y = 0.0F, .z = 0.0F};
    input.end = osk::bsp::Vec3{.x = -10.0F, .y = 0.0F, .z = 0.0F};

    const osk::bsp::BspTraceResult result = osk::bsp::tracePoint(collision, input);
    require(!result.valid, "hull 0 trace should be invalid in clipnode prototype");
    require(!result.hit, "hull 0 trace should not report a hit");
    require(!result.warnings.empty(), "hull 0 trace should warn");
    requireEqual(result.warnings.front(), std::string(UnsupportedHullWarning), "hull 0 warning");
}

void testClearTrace() {
    const osk::bsp::BspCollisionData collision = loadSyntheticCollision();
    osk::bsp::BspTraceInput input;
    input.start = osk::bsp::Vec3{.x = 10.0F, .y = 0.0F, .z = 0.0F};
    input.end = osk::bsp::Vec3{.x = 5.0F, .y = 0.0F, .z = 0.0F};

    const osk::bsp::BspTraceResult result = osk::bsp::tracePoint(collision, input);
    require(result.valid, "trace should be valid");
    require(!result.hit, "clear trace should not hit");
    require(!result.startSolid, "clear trace should not start solid");
    require(!result.allSolid, "clear trace should not be all solid");
    requireEqual(result.fraction, 1.0F, "clear trace fraction");
}

void testHitTrace() {
    const osk::bsp::BspCollisionData collision = loadSyntheticCollision();
    osk::bsp::BspTraceInput input;
    input.start = osk::bsp::Vec3{.x = 10.0F, .y = 0.0F, .z = 0.0F};
    input.end = osk::bsp::Vec3{.x = -10.0F, .y = 0.0F, .z = 0.0F};

    const osk::bsp::BspTraceResult result = osk::bsp::tracePoint(collision, input);
    require(result.valid, "trace should be valid");
    require(result.hit, "trace should hit solid half-space");
    require(!result.startSolid, "hit trace should start outside solid");
    require(result.fraction > 0.0F && result.fraction < 1.0F, "hit fraction should be between 0 and 1");
    requireEqual(result.planeIndex, 0, "hit plane index");
    require(result.hitNormal.x > 0.0F, "hit normal should face positive X");
}

void testStartSolidTrace() {
    const osk::bsp::BspCollisionData collision = loadSyntheticCollision();
    osk::bsp::BspTraceInput input;
    input.start = osk::bsp::Vec3{.x = -2.0F, .y = 0.0F, .z = 0.0F};
    input.end = osk::bsp::Vec3{.x = -4.0F, .y = 0.0F, .z = 0.0F};

    const osk::bsp::BspTraceResult result = osk::bsp::tracePoint(collision, input);
    require(result.valid, "trace should be valid");
    require(result.hit, "start solid trace should count as hit");
    require(result.startSolid, "trace should start solid");
    require(result.allSolid, "trace should be all solid");
    requireEqual(result.fraction, 0.0F, "start solid fraction");
}

void testMalformedCollisionDoesNotCrash() {
    const osk::bsp::BspCollisionData collision = loadSyntheticCollision(false);
    require(!collision.warnings.empty(), "missing clipnodes should warn");

    osk::bsp::BspTraceInput input;
    input.start = osk::bsp::Vec3{.x = 10.0F, .y = 0.0F, .z = 0.0F};
    input.end = osk::bsp::Vec3{.x = -10.0F, .y = 0.0F, .z = 0.0F};
    const osk::bsp::BspTraceResult result = osk::bsp::tracePoint(collision, input);
    require(!result.valid, "trace should be invalid without clipnodes");
    require(!result.warnings.empty(), "invalid trace should warn");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"parse collision tables", testParseCollisionTables},
        {"hull 0 rejected", testHullZeroRejected},
        {"clear trace", testClearTrace},
        {"hit trace", testHitTrace},
        {"start solid trace", testStartSolidTrace},
        {"malformed collision does not crash", testMalformedCollisionDoesNotCrash},
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
