#include "Playback.h"

#include "assets/loaders/WaveAudio.h"

#include <cstdlib>
#include <exception>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

namespace {

struct Options {
    fs::path path;
    bool dryRun = false;
};

void printUsage(std::ostream& out) {
    out << "OpenStrikeWavPlay\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikeWavPlay [--dry-run] <path/to/audio.wav>\n"
        << "\n"
        << "This read-only prototype validates a simple PCM WAV file and plays it on macOS.\n"
        << "It does not write, extract, convert, cache, or copy user-provided audio.\n";
}

Options parseOptions(int argc, char** argv) {
    Options options;
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--help" || arg == "-h") {
            printUsage(std::cout);
            std::exit(0);
        }
        if (arg == "--dry-run") {
            options.dryRun = true;
            continue;
        }
        if (!options.path.empty()) {
            throw std::runtime_error("multiple WAV paths were provided");
        }
        options.path = arg;
    }
    if (options.path.empty()) {
        throw std::runtime_error("missing WAV path");
    }
    return options;
}

void printSummary(const fs::path& path, const osk::audio::WaveAudioSummary& summary) {
    const osk::audio::WaveFormatInfo& format = summary.format;
    const osk::audio::WaveDataInfo& data = summary.data;

    std::cout << "WAV:             " << path.string() << '\n';
    std::cout << "Magic:           " << summary.riffMagic << " / " << summary.waveMagic << '\n';
    std::cout << "Size:            " << summary.fileSize << " bytes\n";
    std::cout << "Declared RIFF:   " << summary.declaredRiffSize << " bytes\n";
    std::cout << "Format:          " << format.audioFormat << " (" << osk::audio::waveAudioFormatName(format.audioFormat) << ")\n";
    std::cout << "Channels:        " << format.channelCount << '\n';
    std::cout << "Sample rate:     " << format.sampleRate << " Hz\n";
    std::cout << "Bits/sample:     " << format.bitsPerSample << '\n';
    std::cout << "Block align:     " << format.blockAlign << '\n';
    std::cout << "Byte rate:       " << format.byteRate << '\n';
    std::cout << "Data:            " << data.size << " bytes at " << data.offset << '\n';
    std::cout << "Duration:        " << std::fixed << std::setprecision(3) << data.durationSeconds << " seconds\n";

    if (!summary.warnings.empty()) {
        std::cout << "\nWarnings:\n";
        for (const std::string& warning : summary.warnings) {
            std::cout << "  - " << warning << '\n';
        }
    }
}

} // namespace

int main(int argc, char** argv) {
    try {
        const Options options = parseOptions(argc, argv);
        const osk::audio::WaveAudioSummary summary = osk::audio::loadWaveAudioSummary(options.path);
        printSummary(options.path, summary);

        if (options.dryRun) {
            std::cout << "\nDry run: playback skipped.\n";
            return summary.warnings.empty() ? 0 : 2;
        }

        std::cout << "\nPlaying...\n";
        std::string error;
        if (!playWaveFile(options.path, error)) {
            throw std::runtime_error(error);
        }
        std::cout << "Playback finished.\n";
        return summary.warnings.empty() ? 0 : 2;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrikeWavPlay error: " << e.what() << '\n';
        printUsage(std::cerr);
        return 1;
    }
}
