#pragma once

#include <filesystem>
#include <string>
#include <vector>

#include "assets/loaders/BspLoader.h"

namespace osk::game {

/**
 * Options for launching a minimal first‑person BSP viewer.  The view
 * renders a loaded BSP world mesh from a fixed spawn position using a
 * simple shaded pipeline.  It does not implement player movement or
 * collision; the camera orientation is fixed to yaw=0 and pitch=0.
 */
struct FirstPersonBspOptions {
    /// Path to the BSP map.  Must be a valid BSP file.
    std::filesystem::path mapPath;
    /// Additional read‑only resource roots (unused in the minimal viewer).
    std::vector<std::filesystem::path> resourceRoots;
    /// Spawn position expressed in BSP world coordinates.  The camera
    /// originates from this point when rendering the map.
    osk::bsp::Vec3 spawn;
    /// Log name used when printing errors.
    std::string logName;
    /// Prefix used when building the NSWindow title.
    std::string windowTitlePrefix;
};

/**
 * Launches a first‑person BSP render window on macOS.  When built on
 * non‑Apple platforms this function prints an error and returns a
 * non‑zero status code.  The implementation constructs a Metal view
 * that draws the world mesh with a simple per‑vertex lighting shader.
 * It blocks until the window is closed or the user presses Escape.
 *
 * \return 0 on success; a non‑zero error code on failure.
 */
int runFirstPersonBsp(const FirstPersonBspOptions& options);

} // namespace osk::game
