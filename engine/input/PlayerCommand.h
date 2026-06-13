#pragma once

#include "input/InputState.h"

#include <cstdint>

namespace osk::input {

struct PlayerCommand {
    std::uint64_t tick = 0;
    float forwardMove = 0.0F;
    float sideMove = 0.0F;
    float lookDeltaX = 0.0F;
    float lookDeltaY = 0.0F;
    bool jump = false;
    bool crouch = false;
    bool exit = false;
};

PlayerCommand buildPlayerCommand(const InputState& input, std::uint64_t tick);

} // namespace osk::input
