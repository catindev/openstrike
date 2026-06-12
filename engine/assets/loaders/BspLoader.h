#pragma once

#include "assets/loaders/BspTypes.h"

#include <filesystem>
#include <span>
#include <stdexcept>
#include <string>

namespace osk::bsp {

class BspFormatError : public std::runtime_error {
public:
    explicit BspFormatError(const std::string& message);
};

BspSummary parseBspSummary(std::span<const std::byte> bytes);
BspSummary loadBspSummary(const std::filesystem::path& path);

} // namespace osk::bsp
