#include "assets/ResourceIndex.h"
#include "assets/VirtualFileSystem.h"
#include "config/Config.h"

#include <chrono>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace fs = std::filesystem;

namespace {

class TempDir {
public:
    explicit TempDir(std::string_view name) {
        const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
        path_ = fs::temp_directory_path() / ("openstrike-" + std::string(name) + "-" + std::to_string(stamp));
        fs::create_directories(path_);
    }

    ~TempDir() {
        std::error_code ec;
        fs::remove_all(path_, ec);
    }

    TempDir(const TempDir&) = delete;
    TempDir& operator=(const TempDir&) = delete;

    [[nodiscard]] const fs::path& path() const {
        return path_;
    }

private:
    fs::path path_;
};

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void writeTextFile(const fs::path& path, std::string_view text) {
    fs::create_directories(path.parent_path());
    std::ofstream out(path);
    if (!out) {
        throw std::runtime_error("failed to write test file: " + path.string());
    }
    out << text;
}

void touchFile(const fs::path& path) {
    writeTextFile(path, "test");
}

template <typename Fn>
void expectThrow(Fn&& fn, const std::string& message) {
    try {
        fn();
    } catch (const std::exception&) {
        return;
    }

    throw std::runtime_error("expected exception: " + message);
}

void testConfigArraysDoNotCollide() {
    TempDir temp("config-arrays");
    const fs::path configPath = temp.path() / "config.toml";

    writeTextFile(configPath, R"(
[resources]
open_asset_roots = [
  "/open/assets"
]
roots = [
  "/user/root"
]
enable_wad = false
enable_pak = true
enable_loose_files = false

[game]
default_map = "maps/test.bsp"
start_mode = "local"

[video]
width = 1920
height = 1080
fullscreen = true
vsync = false

[debug]
show_fps = false
show_resource_index = true
show_collision = true
)" );

    const osk::EngineConfig config = osk::loadConfigFile(configPath);
    require(config.resources.roots.size() == 1, "expected one user resource root");
    require(config.resources.roots[0] == fs::path("/user/root"), "roots parsed from the wrong config key");
    require(config.resources.openAssetRoots.size() == 1, "expected one open asset root");
    require(config.resources.openAssetRoots[0] == fs::path("/open/assets"), "open_asset_roots parsed incorrectly");
    require(!config.resources.enableWad, "enable_wad should parse false");
    require(config.resources.enablePak, "enable_pak should parse true");
    require(!config.resources.enableLooseFiles, "enable_loose_files should parse false");
    require(config.game.defaultMap == "maps/test.bsp", "default_map parse failed");
    require(config.game.startMode == "local", "start_mode parse failed");
    require(config.video.width == 1920 && config.video.height == 1080, "video dimensions parse failed");
    require(config.video.fullscreen && !config.video.vsync, "video booleans parse failed");
    require(!config.debug.showFps && config.debug.showResourceIndex && config.debug.showCollision, "debug booleans parse failed");
}

void testConfigTemplateGeneration() {
    TempDir temp("config-template");
    const fs::path configPath = temp.path() / "nested" / "config.toml";

    osk::writeDefaultConfigTemplate(configPath);
    require(fs::exists(configPath), "config template was not created");

    const osk::EngineConfig config = osk::loadConfigFile(configPath);
    require(config.resources.roots.empty(), "template should not configure user roots");
    require(config.resources.openAssetRoots.size() == 1, "template should configure one open asset root");
    require(config.resources.openAssetRoots[0] == fs::path("./assets_open"), "template open asset root changed unexpectedly");
    require(config.resources.enableWad, "template should enable WAD support");
    require(!config.resources.enablePak, "template should keep PAK disabled");
    require(config.resources.enableLooseFiles, "template should enable loose files");
    require(config.video.width == 1280 && config.video.height == 720, "template video defaults changed unexpectedly");
}

void testMalformedConfigErrors() {
    TempDir temp("config-errors");
    const fs::path configPath = temp.path() / "config.toml";

    writeTextFile(configPath, R"(
[resources]
enable_wad = maybe
)" );

    expectThrow([&]() {
        (void)osk::loadConfigFile(configPath);
    }, "invalid boolean config value");

    writeTextFile(configPath, R"(
[resources]
roots = [
  "/tmp"
)" );

    expectThrow([&]() {
        (void)osk::loadConfigFile(configPath);
    }, "unterminated config array");
}

void testVfsMountValidation() {
    TempDir temp("vfs-mount");
    osk::VirtualFileSystem vfs;

    std::string error;
    require(!vfs.mountReadOnlyDirectory(temp.path() / "missing", "missing", true, &error), "missing directory should not mount");
    require(!error.empty(), "missing directory should report an error");

    const fs::path regularFile = temp.path() / "file.txt";
    touchFile(regularFile);
    error.clear();
    require(!vfs.mountReadOnlyDirectory(regularFile, "file", true, &error), "regular file should not mount as a directory");
    require(!error.empty(), "regular file mount should report an error");

    const fs::path root = temp.path() / "root";
    fs::create_directories(root);
    error.clear();
    require(vfs.mountReadOnlyDirectory(root, "root", true, &error), "valid directory should mount");
    require(vfs.mountCount() == 1, "expected one mounted root");
    require(vfs.userMountCount() == 1, "expected one user mounted root");

    require(vfs.mountReadOnlyDirectory(root, "root-again", true, &error), "duplicate mount should be accepted as no-op");
    require(vfs.mountCount() == 1, "duplicate mount should not add another root");
}

void testResourceIndexExtensions() {
    TempDir temp("resource-index");
    const fs::path root = temp.path() / "root";

    touchFile(root / "maps" / "LEVEL.BSP");
    touchFile(root / "textures" / "pack.WAD");
    touchFile(root / "models" / "thing.MDL");
    touchFile(root / "sprites" / "thing.SPR");
    touchFile(root / "sound" / "thing.WAV");
    touchFile(root / "ignore" / "thing.txt");

    osk::VirtualFileSystem vfs;
    std::string error;
    require(vfs.mountReadOnlyDirectory(root, "root", true, &error), "resource root should mount");

    const osk::ResourceIndex index = osk::buildResourceIndex(vfs);
    require(index.maps.size() == 1, "expected one BSP file");
    require(index.wads.size() == 1, "expected one WAD file");
    require(index.models.size() == 1, "expected one MDL file");
    require(index.sprites.size() == 1, "expected one SPR file");
    require(index.sounds.size() == 1, "expected one WAV file");
    require(index.totalFiles() == 5, "resource index total should be five");
}

void testVfsDeduplicatesOverlappingPhysicalFiles() {
    TempDir temp("vfs-physical-dedupe");
    const fs::path parent = temp.path() / "game";
    const fs::path mod = parent / "mod";
    touchFile(mod / "maps" / "level.bsp");

    osk::VirtualFileSystem vfs;
    std::string error;
    require(vfs.mountReadOnlyDirectory(mod, "mod", true, &error), "mod root should mount");
    require(vfs.mountReadOnlyDirectory(parent, "parent", true, &error), "parent root should mount");

    const std::vector<osk::ResourceFile> maps = vfs.findByExtension(".bsp");
    require(maps.size() == 1, "overlapping roots should not duplicate the same physical file");
    require(maps[0].virtualPath == "maps/level.bsp", "first mount should provide the visible virtual path");
    require(maps[0].mountIndex == 0, "first mount should win for overlapping physical files");
}

void testVfsAppliesVirtualPathShadowing() {
    TempDir temp("vfs-virtual-shadow");
    const fs::path first = temp.path() / "first";
    const fs::path second = temp.path() / "second";
    touchFile(first / "cached.wad");
    touchFile(second / "cached.wad");

    osk::VirtualFileSystem vfs;
    std::string error;
    require(vfs.mountReadOnlyDirectory(first, "first", true, &error), "first root should mount");
    require(vfs.mountReadOnlyDirectory(second, "second", true, &error), "second root should mount");

    const std::vector<osk::ResourceFile> wads = vfs.findByExtension("wad");
    require(wads.size() == 1, "same virtual path should be shadowed by the first mount");
    require(wads[0].virtualPath == "cached.wad", "unexpected virtual path for shadowed file");
    require(wads[0].mountIndex == 0, "first mount should win for virtual path shadowing");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn fn;
};

} // namespace

int main() {
    const TestCase tests[] = {
        {"config arrays do not collide", testConfigArraysDoNotCollide},
        {"config template generation", testConfigTemplateGeneration},
        {"malformed config errors", testMalformedConfigErrors},
        {"vfs mount validation", testVfsMountValidation},
        {"resource index extensions", testResourceIndexExtensions},
        {"vfs overlapping physical file dedupe", testVfsDeduplicatesOverlappingPhysicalFiles},
        {"vfs virtual path shadowing", testVfsAppliesVirtualPathShadowing},
    };

    int failures = 0;
    for (const TestCase& test : tests) {
        try {
            test.fn();
            std::cout << "[PASS] " << test.name << '\n';
        } catch (const std::exception& e) {
            ++failures;
            std::cerr << "[FAIL] " << test.name << ": " << e.what() << '\n';
        }
    }

    if (failures != 0) {
        std::cerr << failures << " test(s) failed\n";
        return 1;
    }

    std::cout << "All config/VFS tests passed\n";
    return 0;
}
