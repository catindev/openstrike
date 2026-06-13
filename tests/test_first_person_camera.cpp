#include "game/FirstPersonCamera.h"

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

// Test that updateYawPitch applies deltas scaled by sensitivity.
void testUpdateYawPitch() {
    float yaw = 0.0F;
    float pitch = 0.0F;
    const float deltaX = 10.0F;
    const float deltaY = -5.0F;
    const float sensitivity = 0.1F;
    osk::game::updateYawPitch(yaw, pitch, deltaX, deltaY, sensitivity);
    requireNear(yaw, 1.0F, 0.0001F, "yaw update");
    requireNear(pitch, -0.5F, 0.0001F, "pitch update");
}

// Test that clampPitch constrains values within bounds.
void testClampPitch() {
    float minPitch = -1.0F;
    float maxPitch = 1.0F;
    {
        float p = 2.0F;
        osk::game::clampPitch(p, minPitch, maxPitch);
        requireNear(p, maxPitch, 0.0001F, "clamp above max");
    }
    {
        float p = -1.5F;
        osk::game::clampPitch(p, minPitch, maxPitch);
        requireNear(p, minPitch, 0.0001F, "clamp below min");
    }
    {
        float p = 0.2F;
        osk::game::clampPitch(p, minPitch, maxPitch);
        requireNear(p, 0.2F, 0.0001F, "clamp inside range");
    }
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"updateYawPitch applies deltas", testUpdateYawPitch},
        {"clampPitch constrains values", testClampPitch},
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
