#include "assets/ResourceIndex.h"
#include "assets/VirtualFileSystem.h"
#include "config/Config.h"

#include <chrono>
#include <cstdlib>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace fs = std::filesystem;

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

std::string pathString(const fs::path& path) {
    return path.generic_string();
}

class TempDir {
public:
    explicit TempDir(std::string_view name) {
        const auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
        root_ = fs::temp_directory_path() / ("openstrike-" + std::string(name) + "-" + std::to_string(now));
        fs::create_directories(root_);
    }

    TempDir(const TempDir&) = delete;
    TempDir& operator=(const TempDir&) = delete;

    ~TempDir() {
        std::error_code ec;
        fs::remove_all(root_, ec);
    }

    [[nodiscard]] const fs::path& path() const {
        return root_;
    }

private:
    fs::path root_;
};

void writeTextFile(const fs::path& path, std::string_view text) {
    fs::create_directories(path.parent_path());
    std::ofstream out(path);
    require(static_cast<bool>(out), "failed to open test output file: " + path.string());
    out << text;
}

void touchFile(const fs::path& path) {
    writeTextFile(path, "synthetic test file\n");
}

bool containsVirtualPath(const std::vector<osk::ResourceFile>& files, std::string_view virtualPath) {
    for (const osk::ResourceFile& file : files) {
        if (file.virtualPath == virtualPath) {
            return true;
        }
    }

    return false;
}

void testConfigParsing() {
    TempDir temp("config-parse");
    const fs::path configPath = temp.path() / "config.toml";

    writeTextFile(configPath, R"toml(
# Comments outside strings are ignored.
[resources]
roots = [
  "/tmp/user-a", # inline comment
  "/tmp/user-b#kept"
]
open_asset_roots = [
  "./assets_open"
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

    requireEqual(config.resources.roots.size(), static_cast<std::size_t>(2), "resource root count");
    requireEqual(pathString(config.resources.roots[0]), "/tmp/user-a", "first resource root");
    requireEqual(pathString(config.resources.roots[1]), "/tmp/user-b#kept", "hash inside quoted string");
    requireEqual(config.resources.openAssetRoots.size(), static_cast<std::size_t>(1), "open asset root count");
    requireEqual(pathString(config.resources.openAssetRoots[0]), "./assets_open", "open asset root");
    require(!config.resources.enableWad, "enable_wad should parse false");
    require(config.resources.enablePak, "enable_pak should parse true");
    require(!config.resources.enableLooseFiles, "enable_loose_files should parse false");

    requireEqual(config.game.defaultMap, std::string("maps/example.bsp"), "default map");
    requireEqual(config.game.startMode, std::string("sandbox"), "start mode");

    requireEqual(config.video.width, 1024, "video width");
    requireEqual(config.video.height, 768, "video height");
    require(config.video.fullscreen, "fullscreen should parse true");
    require(!config.video.vsync, "vsync should parse false");

    require(!config.debug.showFps, "show_fps should parse false");
    require(config.debug.showResourceIndex, "show_resource_index should parse true");
    require(config.debug.showCollision, "show_collision should parse true");
}

void testConfigArrayKeysDoNotCollide() {
    TempDir temp("config-key-collision");
    const fs::path configPath = temp.path() / "config.toml";

    writeTextFile(configPath, R"toml(
[resources]
open_asset_roots = [
  "./assets_open"
]
)toml");

    const osk::EngineConfig config = osk::loadConfigFile(configPath);
    require(config.resources.roots.empty(), "roots must not parse open_asset_roots by substring collision");
    requireEqual(config.resources.openAssetRoots.size(), static_cast<std::size_t>(1), "open_asset_roots should still parse");
    requireEqual(pathString(config.resources.openAssetRoots[0]), "./assets_open", "open asset root after collision test");
}

void testConfigDefaultsAndTemplate() {
    TempDir temp("config-template");
    const fs::path configPath = temp.path() / "nested" / "config.toml";

    osk::writeDefaultConfigTemplate(configPath);
    require(fs::exists(configPath), "default config template should be written");

    const osk::EngineConfig config = osk::loadConfigFile(configPath);
    require(config.resources.roots.empty(), "template should not include user resource roots");
    requireEqual(config.resources.openAssetRoots.size(), static_cast<std::size_t>(1), "template open asset root count");
    requireEqual(pathString(config.resources.openAssetRoots[0]), "./assets_open", "template open asset root");
    require(config.resources.enableWad, "template enable_wad");
    require(!config.resources.enablePak, "template enable_pak");
    require(config.resources.enableLooseFiles, "template enable_loose_files");
    requireEqual(config.video.width, 1280, "template width");
    requireEqual(config.video.height, 720, "template height");
}

void testConfigErrors() {
    TempDir temp("config-errors");

    const fs::path invalidBool = temp.path() / "invalid_bool.toml";
    writeTextFile(invalidBool, R"toml(
[resources]
enable_wad = maybe
)toml");

    bool boolFailed = false;
    try {
        (void)osk::loadConfigFile(invalidBool);
    } catch (const std::runtime_error&) {
        boolFailed = true;
    }
    require(boolFailed, "invalid boolean should throw");

    const fs::path unterminated = temp.path() / "unterminated.toml";
    writeTextFile(unterminated, R"toml(
[resources]
roots = [
  "/tmp/example"
)toml");

    bool arrayFailed = false;
    try {
        (void)osk::loadConfigFile(unterminated);
    } catch (const std::runtime_error&) {
        arrayFailed = true;
    }
    require(arrayFailed, "unterminated array should throw");
}

void testVfsMountValidation() {
    TempDir temp("vfs-mount");
    osk::VirtualFileSystem vfs;

    std::string error;
    const bool missingMounted = vfs.mountReadOnlyDirectory(temp.path() / "missing", "missing", true, &error);
    require(!missingMounted, "missing directory should not mount");
    require(!error.empty(), "missing directory should provide an error message");
    requireEqual(vfs.mountCount(), static_cast<std::size_t>(0), "mount count after missing dir");

    const fs::path root = temp.path() / "root";
    fs::create_directories(root);
    require(vfs.mountReadOnlyDirectory(root, "root", true, &error), "existing directory should mount");
    requireEqual(vfs.mountCount(), static_cast<std::size_t>(1), "mount count after first mount");
    requireEqual(vfs.userMountCount(), static_cast<std::size_t>(1), "user mount count");

    require(vfs.mountReadOnlyDirectory(root, "root-duplicate", true, &error), "duplicate mount should be harmless");
    requireEqual(vfs.mountCount(), static_cast<std::size_t>(1), "duplicate mount should not add a new root");
}

void testVfsResourceIndexingAndPhysicalDedupe() {
    TempDir temp("vfs-index");

    const fs::path parent = temp.path() / "game";
    const fs::path mod = parent / "mod";
    fs::create_directories(mod / "maps");
    fs::create_directories(parent / "maps");

    touchFile(mod / "maps" / "shared.BSP");
    touchFile(parent / "maps" / "base.bsp");

    osk::VirtualFileSystem vfs;
    std::string error;
    require(vfs.mountReadOnlyDirectory(mod, "mod", true, &error), "mod mount");
    require(vfs.mountReadOnlyDirectory(parent, "parent", true, &error), "parent mount");

    const std::vector<osk::ResourceFile> maps = vfs.findByExtension("bsp");
    requireEqual(maps.size(), static_cast<std::size_t>(2), "physical dedupe map count");
    require(containsVirtualPath(maps, "maps/shared.BSP"), "direct mod path should win for shared physical file");
    require(containsVirtualPath(maps, "maps/base.bsp"), "parent map should remain visible");
}

void testVfsVirtualPathShadowing() {
    TempDir temp("vfs-shadow");

    const fs::path first = temp.path() / "first";
    const fs::path second = temp.path() / "second";
    fs::create_directories(first);
    fs::create_directories(second);

    touchFile(first / "cached.wad");
    touchFile(second / "cached.wad");
    touchFile(second / "other.wad");

    osk::VirtualFileSystem vfs;
    std::string error;
    require(vfs.mountReadOnlyDirectory(first, "first", true, &error), "first mount");
    require(vfs.mountReadOnlyDirectory(second, "second", true, &error), "second mount");

    const std::vector<osk::ResourceFile> wads = vfs.findByExtension(".wad");
    requireEqual(wads.size(), static_cast<std::size_t>(2), "virtual path shadowing count");
    require(containsVirtualPath(wads, "cached.wad"), "first cached.wad should remain visible");
    require(containsVirtualPath(wads, "other.wad"), "non-shadowed wad should remain visible");

    for (const osk::ResourceFile& file : wads) {
        if (file.virtualPath == "cached.wad") {
            requireEqual(file.mountIndex, static_cast<std::size_t>(0), "earlier mount should shadow later mount");
        }
    }
}

void testResourceIndexSummary() {
    TempDir temp("resource-index");
    const fs::path root = temp.path() / "root";

    touchFile(root / "maps" / "one.bsp");
    touchFile(root / "textures" / "one.wad");
    touchFile(root / "models" / "one.mdl");
    touchFile(root / "sprites" / "one.spr");
    touchFile(root / "sound" / "one.wav");
    touchFile(root / "ignored" / "one.txt");

    osk::VirtualFileSystem vfs;
    std::string error;
    require(vfs.mountReadOnlyDirectory(root, "root", true, &error), "resource index mount");

    const osk::ResourceIndex index = osk::buildResourceIndex(vfs);
    requireEqual(index.maps.size(), static_cast<std::size_t>(1), "map count");
    requireEqual(index.wads.size(), static_cast<std::size_t>(1), "wad count");
    requireEqual(index.models.size(), static_cast<std::size_t>(1), "model count");
    requireEqual(index.sprites.size(), static_cast<std::size_t>(1), "sprite count");
    requireEqual(index.sounds.size(), static_cast<std::size_t>(1), "sound count");
    requireEqual(index.totalFiles(), static_cast<std::size_t>(5), "total resource count");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"config parsing", testConfigParsing},
        {"config array key collision", testConfigArrayKeysDoNotCollide},
        {"config defaults and template", testConfigDefaultsAndTemplate},
        {"config errors", testConfigErrors},
        {"vfs mount validation", testVfsMountValidation},
        {"vfs indexing and physical dedupe", testVfsResourceIndexingAndPhysicalDedupe},
        {"vfs virtual path shadowing", testVfsVirtualPathShadowing},
        {"resource index summary", testResourceIndexSummary},
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

    if (failures != 0) {
        std::cerr << failures << " test(s) failed\n";
        return 1;
    }

    std::cout << tests.size() << " test(s) passed\n";
    return 0;
}
