#include "Playback.h"

bool playWaveFile(const std::filesystem::path&, std::string& error) {
    error = "WAV playback is only implemented for macOS in this prototype; use --dry-run for metadata validation";
    return false;
}
