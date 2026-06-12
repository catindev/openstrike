#include "config/ConfigPaths.h"

#include <cstdlib>
#include <stdexcept>

namespace osk {

std::filesystem::path defaultConfigPath() {
    const char* home = std::getenv("HOME");
    if (home == nullptr || *home == '\0') {
        throw std::runtime_error("HOME is not set; cannot resolve OpenStrike config path");
    }

    return std::filesystem::path(home)
        / "Library"
        / "Application Support"
        / "OpenStrike"
        / "config.toml";
}

void ensureParentDirectoryExists(const std::filesystem::path& path) {
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent);
    }
}

} // namespace osk
