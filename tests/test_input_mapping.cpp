#include "input/InputState.h"
#include "input/PlayerCommand.h"

#include <cmath>
#include <exception>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct TestFailure : std::runtime_error {
    using std::runtime_error::runtime_error;
};

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw TestFailure(message);
    }
}

template <typename A, typename B>
void requireEqual(const A& actual, const B& expected, const std::string& message) {
    if (!(actual == expected)) {
        std::ostringstream out;
        out << message << " (actual: " << actual << ", expected: " << expected << ")";
        throw TestFailure(out.str());
    }
}

void requireNear(float actual, float expected, float tolerance, const std::string& message) {
    if (std::fabs(actual - expected) > tolerance) {
        std::ostringstream out;
        out << message << " (actual: " << actual << ", expected: " << expected << ", tolerance: " << tolerance << ")";
        throw TestFailure(out.str());
    }
}

void testWasdButtonsMapToCommandAxes() {
    osk::input::InputState state;
    osk::input::setKey(state, osk::input::InputKey::Forward, true);
    osk::input::setKey(state, osk::input::InputKey::Right, true);
    osk::input::setKey(state, osk::input::InputKey::Jump, true);
    osk::input::setKey(state, osk::input::InputKey::Crouch, true);
    osk::input::addLookDelta(state, 3.0F, -2.0F);

    const osk::input::PlayerCommand command = osk::input::buildPlayerCommand(state, 42);

    requireEqual(command.tick, 42U, "command tick");
    requireNear(command.forwardMove, 1.0F, 0.0001F, "forward axis");
    requireNear(command.sideMove, 1.0F, 0.0001F, "side axis");
    requireNear(command.lookDeltaX, 3.0F, 0.0001F, "look delta x");
    requireNear(command.lookDeltaY, -2.0F, 0.0001F, "look delta y");
    require(command.jump, "jump should map");
    require(command.crouch, "crouch should map");
    require(!command.exit, "exit should be off");
}

void testOppositeAxesCancel() {
    osk::input::InputState state;
    osk::input::setKey(state, osk::input::InputKey::Forward, true);
    osk::input::setKey(state, osk::input::InputKey::Back, true);
    osk::input::setKey(state, osk::input::InputKey::Left, true);
    osk::input::setKey(state, osk::input::InputKey::Right, true);

    const osk::input::PlayerCommand command = osk::input::buildPlayerCommand(state, 7);

    requireNear(command.forwardMove, 0.0F, 0.0001F, "opposite forward/back should cancel");
    requireNear(command.sideMove, 0.0F, 0.0001F, "opposite left/right should cancel");
}

void testKeyReleaseClearsCommandButton() {
    osk::input::InputState state;
    osk::input::setKey(state, osk::input::InputKey::Jump, true);
    require(osk::input::isKeyDown(state, osk::input::InputKey::Jump), "jump should be down");

    osk::input::setKey(state, osk::input::InputKey::Jump, false);
    const osk::input::PlayerCommand command = osk::input::buildPlayerCommand(state, 0);

    require(!osk::input::isKeyDown(state, osk::input::InputKey::Jump), "jump should be up");
    require(!command.jump, "released jump should not map");
}

void testLookDeltasCanResetPerFrame() {
    osk::input::InputState state;
    osk::input::addLookDelta(state, 1.5F, 2.5F);
    osk::input::resetFrameDeltas(state);

    const osk::input::PlayerCommand command = osk::input::buildPlayerCommand(state, 0);

    requireNear(command.lookDeltaX, 0.0F, 0.0001F, "reset look delta x");
    requireNear(command.lookDeltaY, 0.0F, 0.0001F, "reset look delta y");
}

void testExitKeyMapsToCommandExit() {
    osk::input::InputState state;
    osk::input::setKey(state, osk::input::InputKey::Exit, true);

    const osk::input::PlayerCommand command = osk::input::buildPlayerCommand(state, 3);

    require(command.exit, "exit should map");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"WASD buttons map to command axes", testWasdButtonsMapToCommandAxes},
        {"opposite axes cancel", testOppositeAxesCancel},
        {"key release clears command button", testKeyReleaseClearsCommandButton},
        {"look deltas reset per frame", testLookDeltasCanResetPerFrame},
        {"exit key maps to command exit", testExitKeyMapsToCommandExit},
    };

    int failures = 0;
    for (const TestCase& test : tests) {
        try {
            test.function();
            std::cout << "[PASS] " << test.name << '\n';
        } catch (const std::exception& e) {
            ++failures;
            std::cerr << "[FAIL] " << test.name << ": " << e.what() << '\n';
        }
    }

    return failures == 0 ? 0 : 1;
}
