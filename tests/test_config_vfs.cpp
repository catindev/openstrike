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

    [[nodiscard]] const fs::path& path() const { return path_; }

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
    require(static_cast<bool>(out), "failed to write test file: " + path.string());
    out << text;
}

void touchFile(const fs::path& path) {
    writeTextFile(path, "synthetic test file\n");
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

bool containsVirtualPath(const std::vector<osk::ResourceFile>& files, std::string_view virtualPath) {
    for (const osk::ResourceFile& file : files) {
        if (file.virtualPath == virtualPath) {
            return true;
        }
    }
    return false;
}

void testConfigParsingAndTemplate() {
    TempDir temp("config");
    const fs::path configPath = temp.path() / "config.toml";

    writeTextFile(configPath, R"toml(
[resources]
open_asset_roots = [
  "./assets_open"
]
roots = [
  "/tmp/user-a",
  "/tmp/user-b#kept"
]
enable_wad = false
enable_pak = true
enable_loose_files = false

[game]
default_map = "maps/example.bsp"
start_mode = "sandbox"

[video]
width = 1024
height = 768
fullscreen = true
vsync = false

[debug]
show_fps = false
show_resource_index = true
show_collision = true
)toml");

    const osk::EngineConfig config = osk::loadConfigFile(configPath);
    require(config.resources.roots.size() == 2, "expected two user roots");
    require(config.resources.roots[0].generic_string() == "/tmp/user-a", "first root parsed incorrectly");
    require(config.resources.roots[1].generic_string() == "/tmp/user-b#kept", "hash inside string should be preserved");
    require(config.resources.openAssetRoots.size() == 1, "expected one open asset root");
    require(config.resources.openAssetRoots[0].generic_string() == "./assets_open", "open asset root parsed incorrectly");
    require(!config.resources.enableWad, "enable_wad should parse false");
    require(config.resources.enablePak, "enable_pak should parse true");
    require(!config.resources.enableLooseFiles, "enable_loose_files should parse false");
    require(config.game.defaultMap == "maps/example.bsp", "default_map parse failed");
    require(config.video.width == 1024 && config.video.height == 768, "video dimensions parse failed");
    require(config.video.fullscreen && !config.video.vsync, "video booleans parse failed");
    require(!config.debug.showFps && config.debug.showResourceIndex && config.debug.showCollision, "debug booleans parse failed");

    const fs::path templatePath = temp.path() / "nested" / "config.toml";
    osk::writeDefaultConfigTemplate(templatePath);
    require(fs::exists(templatePath), "template should be created");
    const osk::EngineConfig templateConfig = osk::loadConfigFile(templatePath);
    require(templateConfig.resources.roots.empty(), "template must not configure user roots");
    require(templateConfig.resources.openAssetRoots.size() == 1, "template should configure one open asset root");
}

void testConfigErrors() {
    TempDir temp("config-errors");
    const fs::path invalidBool = temp.path() / "invalid_bool.toml";
    writeTextFile(invalidBool, "[resources]\nenable_wad = maybe\n");
    expectThrow([&]() { (void)osk::loadConfigFile(invalidBool); }, "invalid boolean");

    const fs::path unterminated = temp.path() / "unterminated.toml";
    writeTextFile(unterminated, "[resources]\nroots = [\n  \"/tmp/example\"\n");
    expectThrow([&]() { (void)osk::loadConfigFile(unterminated); }, "unterminated array");
}

void testVfsMountsAndIndexing() {
    TempDir temp("vfs");
    osk::VirtualFileSystem vfs;

    std::string error;
    require(!vfs.mountReadOnlyDirectory(temp.path() / "missing", "missing", true, &error), "missing directory should not mount");
    require(!error.empty(), "missing directory should report an error");

    const fs::path root = temp.path() / "root";
    touchFile(root / "maps" / "level.BSP");
    touchFile(root / "textures" / "pack.WAD");
    touchFile(root / "models" / "thing.MDL");
    touchFile(root / "sprites" / "thing.SPR");
    touchFile(root / "sound" / "thing.WAV");
    touchFile(root / "ignore" / "thing.txt");

    require(vfs.mountReadOnlyDirectory(root, "root", true, &error), "root should mount");
    require(vfs.mountCount() == 1, "expected one mount");
    require(vfs.userMountCount() == 1, "expected one user mount");
    require(vfs.mountReadOnlyDirectory(root, "root-again", true, &error), "duplicate mount should be accepted");
    require(vfs.mountCount() == 1, "duplicate mount should not add root");

    const osk::ResourceIndex index = osk::buildResourceIndex(vfs);
    require(index.maps.size() == 1, "expected one BSP");
    require(index.wads.size() == 1, "expected one WAD");
    require(index.models.size() == 1, "expected one MDL");
    require(index.sprites.size() == 1, "expected one SPR");
    require(index.sounds.size() == 1, "expected one WAV");
    require(index.totalFiles() == 5, "expected five indexed files");
}

void testVfsDedupeAndShadowing() {
    TempDir temp("vfs-shadow");
    const fs::path parent = temp.path() / "game";
    const fs::path mod = parent / "mod";
    touchFile(mod / "maps" / "shared.bsp");
    touchFile(parent / "maps" / "base.bsp");

    osk::VirtualFileSystem vfs;
    std::string error;
    require(vfs.mountReadOnlyDirectory(mod, "mod", true, &error), "mod should mount");
    require(vfs.mountReadOnlyDirectory(parent, "parent", true, &error), "parent should mount");

    const std::vector<osk::ResourceFile> maps = vfs.findByExtension("bsp");
    require(maps.size() == 2, "overlapping roots should dedupe physical files while keeping unique files");
    require(containsVirtualPath(maps, "maps/shared.bsp"), "mod virtual path should win");
    require(containsVirtualPath(maps, "maps/base.bsp"), "base map should remain visible");

    osk::VirtualFileSystem shadowVfs;
    const fs::path first = temp.path() / "first";
    const fs::path second = temp.path() / "second";
    touchFile(first / "cached.wad");
    touchFile(second / "cached.wad");
    touchFile(second / "other.wad");

    require(shadowVfs.mountReadOnlyDirectory(first, "first", true, &error), "first should mount");
    require(shadowVfs.mountReadOnlyDirectory(second, "second", true, &error), "second should mount");
    const std::vector<osk::ResourceFile> wads = shadowVfs.findByExtension(".wad");
    require(wads.size() == 2, "same virtual path should be shadowed by first mount");
    require(containsVirtualPath(wads, "cached.wad"), "cached.wad should remain visible");
    require(containsVirtualPath(wads, "other.wad"), "other.wad should remain visible");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn fn;
};

} // namespace

int main() {
    const TestCase tests[] = {
        {"config parsing and template", testConfigParsingAndTemplate},
        {"config errors", testConfigErrors},
        {"vfs mounts and indexing", testVfsMountsAndIndexing},
        {"vfs dedupe and shadowing", testVfsDedupeAndShadowing},
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
