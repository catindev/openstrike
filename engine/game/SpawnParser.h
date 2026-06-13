#pragma once

// This header defines a helper for parsing spawn coordinates from CLI tokens.
// It is header-only so that it can be easily tested without additional
// compilation units. The helper returns an optional Vec3 when parsing
// succeeds or std::nullopt on failure.

#include <optional>
#include <string>
#include <vector>
#include <cstdlib>

#include "assets/loaders/BspGeometry.h"

namespace osk::game {

/**
 * Parse three floating-point values into a Vec3 representing a spawn point.
 * The tokens vector must contain exactly three strings convertible to floats.
 * If parsing fails or an unexpected number of tokens is provided, the
 * function returns std::nullopt.
 *
 * \param tokens  A vector of strings representing the x, y and z values.
 * \return An optional Vec3 with parsed coordinates or std::nullopt on error.
 */
inline std::optional<osk::bsp::Vec3> parseSpawn(const std::vector<std::string>& tokens) {
    if (tokens.size() != 3) {
        return std::nullopt;
    }
    char* endp = nullptr;
    const float x = std::strtof(tokens[0].c_str(), &endp);
    if (endp == nullptr || *endp != '\0') {
        return std::nullopt;
    }
    const float y = std::strtof(tokens[1].c_str(), &endp);
    if (endp == nullptr || *endp != '\0') {
        return std::nullopt;
    }
    const float z = std::strtof(tokens[2].c_str(), &endp);
    if (endp == nullptr || *endp != '\0') {
        return std::nullopt;
    }
    return osk::bsp::Vec3{.x = x, .y = y, .z = z};
}

} // namespace osk::game
