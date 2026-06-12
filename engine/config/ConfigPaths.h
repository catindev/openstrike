#pragma once

#include <filesystem>

namespace osk {

std::filesystem::path defaultConfigPath();
void ensureParentDirectoryExists(const std::filesystem::path& path);

} // namespace osk
