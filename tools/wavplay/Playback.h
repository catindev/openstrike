#pragma once

#include <filesystem>
#include <string>

bool playWaveFile(const std::filesystem::path& path, std::string& error);
