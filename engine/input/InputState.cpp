#include "input/InputState.h"

namespace osk::input {

void setKey(InputState& state, InputKey key, bool down) {
    switch (key) {
    case InputKey::Forward:
        state.forward = down;
        break;
    case InputKey::Back:
        state.back = down;
        break;
    case InputKey::Left:
        state.left = down;
        break;
    case InputKey::Right:
        state.right = down;
        break;
    case InputKey::Jump:
        state.jump = down;
        break;
    case InputKey::Crouch:
        state.crouch = down;
        break;
    case InputKey::Exit:
        state.exit = down;
        break;
    }
}

bool isKeyDown(const InputState& state, InputKey key) {
    switch (key) {
    case InputKey::Forward:
        return state.forward;
    case InputKey::Back:
        return state.back;
    case InputKey::Left:
        return state.left;
    case InputKey::Right:
        return state.right;
    case InputKey::Jump:
        return state.jump;
    case InputKey::Crouch:
        return state.crouch;
    case InputKey::Exit:
        return state.exit;
    }

    return false;
}

void addLookDelta(InputState& state, float deltaX, float deltaY) {
    state.lookDeltaX += deltaX;
    state.lookDeltaY += deltaY;
}

void resetFrameDeltas(InputState& state) {
    state.lookDeltaX = 0.0F;
    state.lookDeltaY = 0.0F;
}

} // namespace osk::input
