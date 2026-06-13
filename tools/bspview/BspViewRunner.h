#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace osk::debug {

struct BspViewOptions {
    std::filesystem::path mapPath;
    std::vector<std::filesystem::path> resourceRoots;
    std::string logName = "OpenStrikeBspView";
    std::string windowTitlePrefix = "OpenStrike BSP View";
    bool loadDefaultConfigRoots = true;
};

int runBspView(const BspViewOptions& options);
int runBspViewCli(int argc, char** argv);

} // namespace osk::debug
