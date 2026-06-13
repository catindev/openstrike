#pragma once

#include "assets/loaders/BspCollision.h"

#include <cstddef>
#include <string>
#include <vector>

namespace osk::physics {

struct PlayerMovementConfig {
    float tickSeconds = 1.0F / 60.0F;
    float walkSpeed = 160.0F;
    float gravity = 800.0F;
    float jumpSpeed = 270.0F;
    float groundNormalMinZ = 0.7F;
};

struct PlayerMovementInput {
    float forwardMove = 0.0F;
    float sideMove = 0.0F;
    bool jump = false;
};

struct PlayerMovementState {
    bsp::Vec3 position{};
    bsp::Vec3 velocity{};
    bool grounded = false;
};

struct PlayerMovementTraceContext {
    const bsp::BspCollisionData* collision = nullptr;
    std::size_t modelIndex = 0;
    std::size_t hullIndex = 1;
};

struct PlayerMovementStepResult {
    PlayerMovementState state;
    bsp::BspTraceResult trace;
    bool jumped = false;
    std::vector<std::string> warnings;
};

PlayerMovementStepResult stepPlayerMovement(
    const PlayerMovementState& current,
    const PlayerMovementInput& input,
    const PlayerMovementTraceContext& traceContext,
    const PlayerMovementConfig& config = {});

} // namespace osk::physics
