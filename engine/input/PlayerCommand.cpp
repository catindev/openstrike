#include "input/PlayerCommand.h"

namespace osk::input {
namespace {

float axis(bool positive, bool negative) {
    return (positive ? 1.0F : 0.0F) - (negative ? 1.0F : 0.0F);
}

} // namespace

PlayerCommand buildPlayerCommand(const InputState& input, std::uint64_t tick) {
    return PlayerCommand{
        .tick = tick,
        .forwardMove = axis(input.forward, input.back),
        .sideMove = axis(input.right, input.left),
        .lookDeltaX = input.lookDeltaX,
        .lookDeltaY = input.lookDeltaY,
        .jump = input.jump,
        .crouch = input.crouch,
        .exit = input.exit,
    };
}

} // namespace osk::input
