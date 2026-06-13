#pragma once

namespace osk::input {

enum class InputKey {
    Forward,
    Back,
    Left,
    Right,
    Jump,
    Crouch,
    Exit,
};

struct InputState {
    bool forward = false;
    bool back = false;
    bool left = false;
    bool right = false;
    bool jump = false;
    bool crouch = false;
    bool exit = false;
    float lookDeltaX = 0.0F;
    float lookDeltaY = 0.0F;
};

void setKey(InputState& state, InputKey key, bool down);
bool isKeyDown(const InputState& state, InputKey key);
void addLookDelta(InputState& state, float deltaX, float deltaY);
void resetFrameDeltas(InputState& state);

} // namespace osk::input
