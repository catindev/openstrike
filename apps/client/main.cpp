#include "assets/ResourceIndex.h"
#include "assets/VirtualFileSystem.h"
#include "config/Config.h"
#include "config/ConfigPaths.h"
#include "platform/Window.h"

#if defined(__APPLE__)
#include "BspViewRunner.h"
#endif

#include <exception>
#include <filesystem>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace {

struct CliOptions {
    bool help = false;
    bool printConfigPath = false;
    bool validateConfig = false;
    bool listResources = false;
    bool noWindow = false;
    std::optional<fs::path> configPath;
    std::optional<fs::path> sandboxMap;
    std::vector<fs::path> resourceRoots;
};

void printUsage(std::ostream& out) {
    out << "OpenStrike bootstrap client\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrike [options]\n"
        << "\n"
        << "Options:\n"
        << "  --help                         Show this help text.\n"
        << "  --print-config-path            Print the default config path and exit.\n"
        << "  --validate-config              Load config, mount resource roots, print summary, and exit.\n"
        << "  --list-resources               Print indexed resource filenames.\n"
        << "  --no-window                    Initialize resources and exit without opening a window.\n"
        << "  --sandbox-map <path>           Launch local sandbox mode with a map window.\n"
        << "  --config <path>                Use an explicit config file.\n"
        << "  --resource-root <path>         Add a temporary read-only resource root.\n"
        << "\n"
        << "The repository and application do not include proprietary game resources.\n"
        << "Resource roots must point to local user-provided files.\n";
}

CliOptions parseArgs(int argc, char** argv) {
    CliOptions options;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];

        if (arg == "--help" || arg == "-h") {
            options.help = true;
        } else if (arg == "--print-config-path") {
            options.printConfigPath = true;
        } else if (arg == "--validate-config") {
            options.validateConfig = true;
        } else if (arg == "--list-resources") {
            options.listResources = true;
        } else if (arg == "--no-window") {
            options.noWindow = true;
        } else if (arg == "--sandbox-map") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--sandbox-map requires a path argument");
            }
            options.sandboxMap = fs::path(argv[++i]);
        } else if (arg == "--config") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--config requires a path argument");
            }
            options.configPath = fs::path(argv[++i]);
        } else if (arg == "--resource-root") {
            if (i + 1 >= argc) {
                throw std::runtime_error("--resource-root requires a path argument");
            }
            options.resourceRoots.emplace_back(argv[++i]);
        } else {
            throw std::runtime_error("unknown argument: " + arg);
        }
    }

    return options;
}

bool mountConfiguredRoots(const osk::EngineConfig& config, osk::VirtualFileSystem& vfs) {
    bool ok = true;

    for (const fs::path& root : config.resources.openAssetRoots) {
        std::string error;
        if (!vfs.mountReadOnlyDirectory(root, "open-assets", false, &error)) {
            std::cerr << "Warning: open asset root skipped: " << error << '\n';
        }
    }

    for (const fs::path& root : config.resources.roots) {
        std::string error;
        if (!vfs.mountReadOnlyDirectory(root, "user-resources", true, &error)) {
            std::cerr << "Error: user resource root skipped: " << error << '\n';
            ok = false;
        }
    }

    return ok;
}

void printMountedRoots(const osk::VirtualFileSystem& vfs) {
    std::cout << "Mounted roots:\n";

    if (vfs.mounts().empty()) {
        std::cout << "  none\n";
        return;
    }

    for (const osk::MountedRoot& root : vfs.mounts()) {
        std::cout << "  - " << root.canonicalPath.string()
            << " [" << (root.userProvided ? "user" : "open") << "]\n";
    }
}

int runWindowLoop() {
    std::string error;
    std::unique_ptr<osk::Window> window = osk::Window::create(osk::WindowDesc{
        .title = "OpenStrike Bootstrap",
        .width = 1280,
        .height = 720,
    }, &error);

    if (!window) {
        std::cerr << "OpenStrike error: failed to create window: " << error << '\n';
        return 3;
    }

    std::cout << "OpenStrike window running. Press Esc or close the window to exit.\n";
    window->runUntilClosed();
    std::cout << "OpenStrike window closed.\n";

    return 0;
}

} // namespace

int main(int argc, char** argv) {
    try {
        const CliOptions options = parseArgs(argc, argv);

        if (options.help) {
            printUsage(std::cout);
            return 0;
        }

        const fs::path configPath = options.configPath.value_or(osk::defaultConfigPath());

        if (options.printConfigPath) {
            std::cout << configPath.string() << '\n';
            return 0;
        }

        if (!fs::exists(configPath)) {
            osk::writeDefaultConfigTemplate(configPath);
            std::cout << "Created OpenStrike config template:\n"
                << "  " << configPath.string() << "\n\n"
                << "Edit [resources].roots and add local paths to compatible user-provided files.\n";

            return options.validateConfig ? 1 : 0;
        }

        osk::EngineConfig config = osk::loadConfigFile(configPath);
        for (const fs::path& root : options.resourceRoots) {
            config.resources.roots.push_back(root);
        }

        osk::VirtualFileSystem vfs;
        const bool rootsOk = mountConfiguredRoots(config, vfs);

        if (vfs.userMountCount() == 0) {
            std::cerr << "Warning: no user-provided resource roots are configured.\n";
        }

        const osk::ResourceIndex index = osk::buildResourceIndex(vfs);

        if (options.validateConfig || options.listResources) {
            std::cout << "Config: " << configPath.string() << '\n';
            printMountedRoots(vfs);
            osk::printResourceIndex(std::cout, index, options.listResources);
            return rootsOk ? 0 : 2;
        }

        std::cout << "OpenStrike bootstrap client initialized.\n";
        std::cout << "Config: " << configPath.string() << '\n';
        std::cout << "Indexed resources: " << index.totalFiles() << '\n';

        if (options.sandboxMap.has_value()) {
#if defined(__APPLE__)
            std::vector<fs::path> sandboxRoots = config.resources.roots;
            sandboxRoots.insert(sandboxRoots.end(), options.resourceRoots.begin(), options.resourceRoots.end());
            return osk::debug::runBspView(osk::debug::BspViewOptions{
                .mapPath = *options.sandboxMap,
                .resourceRoots = sandboxRoots,
                .logName = "OpenStrikeSandbox",
                .windowTitlePrefix = "OpenStrike Sandbox",
                .loadDefaultConfigRoots = false,
            });
#else
            std::cerr << "OpenStrike error: sandbox map mode is currently available only on macOS.\n";
            return 1;
#endif
        }

        if (options.noWindow) {
            return rootsOk ? 0 : 2;
        }

        const int windowResult = runWindowLoop();
        if (windowResult != 0) {
            return windowResult;
        }

        return rootsOk ? 0 : 2;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrike error: " << e.what() << '\n';
        return 1;
    }
}
