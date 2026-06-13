#include "assets/loaders/WaveAudio.h"

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

void appendFourCC(std::vector<std::byte>& bytes, std::string_view fourcc) {
    requireEqual(fourcc.size(), static_cast<std::size_t>(4), "fourcc size");
    for (char c : fourcc) {
        appendByte(bytes, static_cast<std::uint8_t>(c));
    }
}

void appendU16LE(std::vector<std::byte>& bytes, std::uint16_t value) {
    appendByte(bytes, static_cast<std::uint8_t>(value & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 8U) & 0xFFU));
}

void appendU32LE(std::vector<std::byte>& bytes, std::uint32_t value) {
    appendByte(bytes, static_cast<std::uint8_t>(value & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 8U) & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 16U) & 0xFFU));
    appendByte(bytes, static_cast<std::uint8_t>((value >> 24U) & 0xFFU));
}

void patchU32LE(std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value) {
    bytes.at(offset) = static_cast<std::byte>(value & 0xFFU);
    bytes.at(offset + 1) = static_cast<std::byte>((value >> 8U) & 0xFFU);
    bytes.at(offset + 2) = static_cast<std::byte>((value >> 16U) & 0xFFU);
    bytes.at(offset + 3) = static_cast<std::byte>((value >> 24U) & 0xFFU);
}

void appendFmtChunk(
    std::vector<std::byte>& bytes,
    std::uint16_t audioFormat = 1,
    std::uint16_t channels = 1,
    std::uint32_t sampleRate = 8000,
    std::uint16_t bitsPerSample = 16) {
    const std::uint16_t blockAlign = static_cast<std::uint16_t>(channels * (bitsPerSample / 8));
    const std::uint32_t byteRate = sampleRate * blockAlign;

    appendFourCC(bytes, "fmt ");
    appendU32LE(bytes, 16);
    appendU16LE(bytes, audioFormat);
    appendU16LE(bytes, channels);
    appendU32LE(bytes, sampleRate);
    appendU32LE(bytes, byteRate);
    appendU16LE(bytes, blockAlign);
    appendU16LE(bytes, bitsPerSample);
}

void appendDataChunk(std::vector<std::byte>& bytes, std::uint32_t byteCount = 16) {
    appendFourCC(bytes, "data");
    appendU32LE(bytes, byteCount);
    for (std::uint32_t i = 0; i < byteCount; ++i) {
        appendByte(bytes, static_cast<std::uint8_t>(i & 0xFFU));
    }
}

std::vector<std::byte> makeSyntheticWave() {
    std::vector<std::byte> bytes;
    appendFourCC(bytes, "RIFF");
    appendU32LE(bytes, 0);
    appendFourCC(bytes, "WAVE");
    appendFmtChunk(bytes);
    appendDataChunk(bytes, 16);
    patchU32LE(bytes, 4, static_cast<std::uint32_t>(bytes.size() - 8));
    return bytes;
}

void expectFormatError(const std::vector<std::byte>& bytes, const std::string& message) {
    bool failed = false;
    try {
        (void)osk::audio::parseWaveAudioSummary(bytes);
    } catch (const osk::audio::WaveAudioFormatError&) {
        failed = true;
    }
    require(failed, message);
}

void testValidSyntheticWave() {
    const std::vector<std::byte> bytes = makeSyntheticWave();
    const osk::audio::WaveAudioSummary summary = osk::audio::parseWaveAudioSummary(bytes);

    requireEqual(summary.riffMagic, std::string("RIFF"), "riff magic");
    requireEqual(summary.waveMagic, std::string("WAVE"), "wave magic");
    requireEqual(summary.format.audioFormat, static_cast<std::uint16_t>(1), "audio format");
    requireEqual(summary.format.channelCount, static_cast<std::uint16_t>(1), "channels");
    requireEqual(summary.format.sampleRate, static_cast<std::uint32_t>(8000), "sample rate");
    requireEqual(summary.format.bitsPerSample, static_cast<std::uint16_t>(16), "bits per sample");
    requireEqual(summary.data.size, static_cast<std::size_t>(16), "data size");
    require(summary.data.durationSeconds > 0.0, "duration should be positive");
    require(summary.warnings.empty(), "valid synthetic WAV should not warn");
}

void testOddSizedUnknownChunk() {
    std::vector<std::byte> bytes;
    appendFourCC(bytes, "RIFF");
    appendU32LE(bytes, 0);
    appendFourCC(bytes, "WAVE");
    appendFourCC(bytes, "JUNK");
    appendU32LE(bytes, 3);
    appendByte(bytes, 1);
    appendByte(bytes, 2);
    appendByte(bytes, 3);
    appendByte(bytes, 0);
    appendFmtChunk(bytes);
    appendDataChunk(bytes, 8);
    patchU32LE(bytes, 4, static_cast<std::uint32_t>(bytes.size() - 8));

    const osk::audio::WaveAudioSummary summary = osk::audio::parseWaveAudioSummary(bytes);
    requireEqual(summary.data.size, static_cast<std::size_t>(8), "data after odd chunk");
}

void testDeclaredSizeWarning() {
    std::vector<std::byte> bytes = makeSyntheticWave();
    patchU32LE(bytes, 4, 1);

    const osk::audio::WaveAudioSummary summary = osk::audio::parseWaveAudioSummary(bytes);
    requireEqual(summary.warnings.size(), static_cast<std::size_t>(1), "declared size warning count");
}

void testNames() {
    requireEqual(osk::audio::waveAudioFormatName(1), std::string_view("PCM"), "PCM name");
    requireEqual(osk::audio::waveAudioFormatName(7), std::string_view("unknown"), "unknown format name");
}

void testMalformedInputs() {
    expectFormatError(std::vector<std::byte>(11, std::byte{0}), "short RIFF header should throw");

    std::vector<std::byte> badRiff = makeSyntheticWave();
    badRiff.at(0) = static_cast<std::byte>('N');
    expectFormatError(badRiff, "bad RIFF magic should throw");

    std::vector<std::byte> badWave = makeSyntheticWave();
    badWave.at(8) = static_cast<std::byte>('N');
    expectFormatError(badWave, "bad WAVE magic should throw");

    std::vector<std::byte> missingFmt;
    appendFourCC(missingFmt, "RIFF");
    appendU32LE(missingFmt, 0);
    appendFourCC(missingFmt, "WAVE");
    appendDataChunk(missingFmt);
    patchU32LE(missingFmt, 4, static_cast<std::uint32_t>(missingFmt.size() - 8));
    expectFormatError(missingFmt, "missing fmt should throw");

    std::vector<std::byte> missingData;
    appendFourCC(missingData, "RIFF");
    appendU32LE(missingData, 0);
    appendFourCC(missingData, "WAVE");
    appendFmtChunk(missingData);
    patchU32LE(missingData, 4, static_cast<std::uint32_t>(missingData.size() - 8));
    expectFormatError(missingData, "missing data should throw");

    std::vector<std::byte> unsupportedFormat;
    appendFourCC(unsupportedFormat, "RIFF");
    appendU32LE(unsupportedFormat, 0);
    appendFourCC(unsupportedFormat, "WAVE");
    appendFmtChunk(unsupportedFormat, 7);
    appendDataChunk(unsupportedFormat);
    patchU32LE(unsupportedFormat, 4, static_cast<std::uint32_t>(unsupportedFormat.size() - 8));
    expectFormatError(unsupportedFormat, "unsupported format should throw");

    std::vector<std::byte> truncated = makeSyntheticWave();
    truncated.pop_back();
    expectFormatError(truncated, "truncated data should throw");

    std::vector<std::byte> unaligned = makeSyntheticWave();
    patchU32LE(unaligned, 40, 15);
    unaligned.pop_back();
    patchU32LE(unaligned, 4, static_cast<std::uint32_t>(unaligned.size() - 8));
    expectFormatError(unaligned, "unaligned data should throw");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"valid synthetic WAV", testValidSyntheticWave},
        {"odd sized unknown chunk", testOddSizedUnknownChunk},
        {"declared size warning", testDeclaredSizeWarning},
        {"format names", testNames},
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
