#include "config/Config.h"

#include "config/ConfigPaths.h"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string_view>

namespace osk {
namespace {

std::string readTextFile(const std::filesystem::path& path) {
    std::ifstream in(path);
    if (!in) {
        throw std::runtime_error("failed to open config file: " + path.string());
    }

    std::ostringstream buffer;
    buffer << in.rdbuf();
    return buffer.str();
}

std::string trim(std::string_view value) {
    auto begin = value.begin();
    auto end = value.end();

    while (begin != end && std::isspace(static_cast<unsigned char>(*begin))) {
        ++begin;
    }

    while (begin != end && std::isspace(static_cast<unsigned char>(*(end - 1)))) {
        --end;
    }

    return std::string(begin, end);
}

std::string stripLineComment(std::string_view line) {
    bool inString = false;
    for (std::size_t i = 0; i < line.size(); ++i) {
        const char c = line[i];
        if (c == '"' && (i == 0 || line[i - 1] != '\\')) {
            inString = !inString;
        }
        if (c == '#' && !inString) {
            return std::string(line.substr(0, i));
        }
    }

    return std::string(line);
}

std::string stripComments(const std::string& input) {
    std::istringstream stream(input);
    std::ostringstream out;
    std::string line;

    while (std::getline(stream, line)) {
        out << stripLineComment(line) << '\n';
    }

    return out.str();
}

std::optional<std::string> sectionBody(const std::string& input, std::string_view sectionName) {
    const std::string header = "[" + std::string(sectionName) + "]";
    const auto sectionStart = input.find(header);
    if (sectionStart == std::string::npos) {
        return std::nullopt;
    }

    const auto bodyStart = sectionStart + header.size();
    auto bodyEnd = input.find("\n[", bodyStart);
    if (bodyEnd == std::string::npos) {
        bodyEnd = input.size();
    }

    return input.substr(bodyStart, bodyEnd - bodyStart);
}

std::optional<std::string> rawValue(const std::string& section, std::string_view key) {
    std::istringstream stream(section);
    std::string line;
    const std::string keyText(key);

    while (std::getline(stream, line)) {
        const auto eq = line.find('=');
        if (eq == std::string::npos) {
            continue;
        }

        if (trim(std::string_view(line).substr(0, eq)) == keyText) {
            return trim(std::string_view(line).substr(eq + 1));
        }
    }

    return std::nullopt;
}

std::optional<std::size_t> findArrayClose(std::string_view text) {
    bool inString = false;
    bool escape = false;

    for (std::size_t i = 0; i < text.size(); ++i) {
        const char c = text[i];

        if (escape) {
            escape = false;
            continue;
        }

        if (inString && c == '\\') {
            escape = true;
            continue;
        }

        if (c == '"') {
            inString = !inString;
            continue;
        }

        if (!inString && c == ']') {
            return i;
        }
    }

    return std::nullopt;
}

std::optional<std::string> rawArrayValue(const std::string& section, std::string_view key) {
    std::istringstream stream(section);
    std::string line;
    const std::string keyText(key);

    while (std::getline(stream, line)) {
        const auto eq = line.find('=');
        if (eq == std::string::npos) {
            continue;
        }

        if (trim(std::string_view(line).substr(0, eq)) != keyText) {
            continue;
        }

        const auto open = line.find('[', eq + 1);
        if (open == std::string::npos) {
            return std::nullopt;
        }

        std::string collected = line.substr(open + 1);
        while (true) {
            if (const auto close = findArrayClose(collected)) {
                return collected.substr(0, *close);
            }

            if (!std::getline(stream, line)) {
                throw std::runtime_error("unterminated array in config key: " + std::string(key));
            }

            collected.push_back('\n');
            collected += line;
        }
    }

    return std::nullopt;
}

std::vector<std::filesystem::path> parseStringArray(const std::string& section, std::string_view key) {
    std::vector<std::filesystem::path> result;
    const auto raw = rawArrayValue(section, key);
    if (!raw.has_value()) {
        return result;
    }

    bool inString = false;
    bool escape = false;
    std::string current;

    for (char c : *raw) {
        if (!inString) {
            if (c == '"') {
                inString = true;
                current.clear();
            }
            continue;
        }

        if (escape) {
            current.push_back(c);
            escape = false;
            continue;
        }

        if (c == '\\') {
            escape = true;
            continue;
        }

        if (c == '"') {
            inString = false;
            result.emplace_back(current);
            current.clear();
            continue;
        }

        current.push_back(c);
    }

    if (inString) {
        throw std::runtime_error("unterminated string in config array: " + std::string(key));
    }

    return result;
}

std::string parseString(const std::string& section, std::string_view key, std::string fallback) {
    const auto raw = rawValue(section, key);
    if (!raw.has_value()) {
        return fallback;
    }

    const std::string value = trim(*raw);
    if (value.size() >= 2 && value.front() == '"' && value.back() == '"') {
        return value.substr(1, value.size() - 2);
    }

    return value;
}

bool parseBool(const std::string& section, std::string_view key, bool fallback) {
    const auto raw = rawValue(section, key);
    if (!raw.has_value()) {
        return fallback;
    }

    std::string value = trim(*raw);
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });

    if (value == "true") {
        return true;
    }

    if (value == "false") {
        return false;
    }

    throw std::runtime_error("invalid boolean value for config key: " + std::string(key));
}

int parseInt(const std::string& section, std::string_view key, int fallback) {
    const auto raw = rawValue(section, key);
    if (!raw.has_value()) {
        return fallback;
    }

    return std::stoi(trim(*raw));
}

} // namespace

EngineConfig loadConfigFile(const std::filesystem::path& path) {
    const std::string text = stripComments(readTextFile(path));
    EngineConfig config;

    if (const auto resources = sectionBody(text, "resources")) {
        config.resources.roots = parseStringArray(*resources, "roots");
        config.resources.openAssetRoots = parseStringArray(*resources, "open_asset_roots");
        config.resources.enableWad = parseBool(*resources, "enable_wad", config.resources.enableWad);
        config.resources.enablePak = parseBool(*resources, "enable_pak", config.resources.enablePak);
        config.resources.enableLooseFiles = parseBool(*resources, "enable_loose_files", config.resources.enableLooseFiles);
    }

    if (const auto game = sectionBody(text, "game")) {
        config.game.defaultMap = parseString(*game, "default_map", config.game.defaultMap);
        config.game.startMode = parseString(*game, "start_mode", config.game.startMode);
    }

    if (const auto video = sectionBody(text, "video")) {
        config.video.width = parseInt(*video, "width", config.video.width);
        config.video.height = parseInt(*video, "height", config.video.height);
        config.video.fullscreen = parseBool(*video, "fullscreen", config.video.fullscreen);
        config.video.vsync = parseBool(*video, "vsync", config.video.vsync);
    }

    if (const auto debug = sectionBody(text, "debug")) {
        config.debug.showFps = parseBool(*debug, "show_fps", config.debug.showFps);
        config.debug.showResourceIndex = parseBool(*debug, "show_resource_index", config.debug.showResourceIndex);
        config.debug.showCollision = parseBool(*debug, "show_collision", config.debug.showCollision);
    }

    return config;
}

void writeDefaultConfigTemplate(const std::filesystem::path& path) {
    ensureParentDirectoryExists(path);

    std::ofstream out(path);
    if (!out) {
        throw std::runtime_error("failed to create config template: " + path.string());
    }

    out << R"(# OpenStrike configuration.
#
# OpenStrike does not include proprietary assets.
# Add only paths to local files you are legally allowed to access.
# Resource roots are mounted read-only and are never modified by the engine.

[resources]
roots = [
  # "/absolute/path/to/user/owned/compatible/files"
]

open_asset_roots = [
  "./assets_open"
]

enable_wad = true
enable_pak = false
enable_loose_files = true

[game]
default_map = ""
start_mode = "sandbox"

[video]
width = 1280
height = 720
fullscreen = false
vsync = true

[debug]
show_fps = true
show_resource_index = false
show_collision = false
)";
}

} // namespace osk
