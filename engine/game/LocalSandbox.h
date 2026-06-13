#pragma once

#include <filesystem>
#include <vector>

namespace osk::game {

struct LocalSandboxOptions {
    std::filesystem::path mapPath;
    std::vector<std::filesystem::path> resourceRoots;
    bool debugInput = false;
};

int runLocalSandbox(const LocalSandboxOptions& options);

} // namespace osk::game
