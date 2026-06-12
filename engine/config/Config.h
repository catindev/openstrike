#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace osk {

struct ResourceConfig {
    std::vector<std::filesystem::path> roots;
    std::vector<std::filesystem::path> openAssetRoots;

    bool enableWad = true;
    bool enablePak = false;
    bool enableLooseFiles = true;
};

struct GameConfig {
    std::string defaultMap;
    std::string startMode = "sandbox";
};

struct VideoConfig {
    int width = 1280;
    int height = 720;
    bool fullscreen = false;
    bool vsync = true;
};

struct DebugConfig {
    bool showFps = true;
    bool showResourceIndex = false;
    bool showCollision = false;
};

struct EngineConfig {
    ResourceConfig resources;
    GameConfig game;
    VideoConfig video;
    DebugConfig debug;
};

EngineConfig loadConfigFile(const std::filesystem::path& path);
void writeDefaultConfigTemplate(const std::filesystem::path& path);

} // namespace osk
