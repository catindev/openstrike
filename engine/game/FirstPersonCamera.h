#pragma once

// This header defines helpers for manipulating a simple first‑person camera.
// The functions are intentionally header‑only to make them easy to test
// without requiring separate compilation units. They do not depend on
// macOS‑specific frameworks.

#include "assets/loaders/BspGeometry.h"

namespace osk::game {

/**
 * Incrementally adjust the camera yaw and pitch given pointer deltas. A
 * positive deltaX rotates the view to the right (increasing yaw) and a
 * positive deltaY rotates the view downward (increasing pitch). The
 * sensitivity parameter scales the deltas to radians; callers should
 * choose a reasonable value such as 0.002 to convert pixels to radians.
 *
 * \param yaw        The camera yaw angle in radians. It will be updated.
 * \param pitch      The camera pitch angle in radians. It will be updated.
 * \param deltaX     Horizontal pointer movement since the last frame.
 * \param deltaY     Vertical pointer movement since the last frame.
 * \param sensitivity Scale factor applied to the deltas to obtain radians.
 */
inline void updateYawPitch(float& yaw, float& pitch, float deltaX, float deltaY, float sensitivity) {
    yaw += deltaX * sensitivity;
    pitch += deltaY * sensitivity;
}

/**
 * Clamp the camera pitch angle into a safe range. Extreme pitch angles can
 * result in gimbal lock or undefined behaviour when constructing view
 * matrices. This helper ensures that the pitch is within the provided
 * bounds. If the pitch exceeds the bounds it will be set to the nearest
 * bound.
 *
 * \param pitch  The pitch angle to clamp, modified in place.
 * \param minPitch Minimum allowed pitch angle in radians.
 * \param maxPitch Maximum allowed pitch angle in radians.
 */
inline void clampPitch(float& pitch, float minPitch, float maxPitch) {
    if (pitch < minPitch) {
        pitch = minPitch;
    } else if (pitch > maxPitch) {
        pitch = maxPitch;
    }
}

} // namespace osk::game
