#include "game/SpawnParser.h"

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

template <typename T>
void requireOptionalHasValue(const std::optional<T>& opt, bool expected, const std::string& message) {
    if ((opt.has_value()) != expected) {
        std::ostringstream out;
        out << message << " (actual: " << (opt.has_value() ? "has value" : "empty")
            << ", expected: " << (expected ? "has value" : "empty") << ")";
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

void testParseSpawnValid() {
    std::vector<std::string> tokens = {"1.0", "2.5", "-3.25"};
    auto result = osk::game::parseSpawn(tokens);
    requireOptionalHasValue(result, true, "valid spawn should return value");
    requireNear(result->x, 1.0f, 0.0001f, "x coordinate");
    requireNear(result->y, 2.5f, 0.0001f, "y coordinate");
    requireNear(result->z, -3.25f, 0.0001f, "z coordinate");
}

void testParseSpawnInvalidCount() {
    std::vector<std::string> tokens = {"1.0", "2.0"};
    auto result = osk::game::parseSpawn(tokens);
    requireOptionalHasValue(result, false, "too few tokens should return empty");
}

void testParseSpawnInvalidNumber() {
    std::vector<std::string> tokens = {"1.0", "abc", "3.0"};
    auto result = osk::game::parseSpawn(tokens);
    requireOptionalHasValue(result, false, "invalid float should return empty");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests = {
        {"parseSpawn valid", testParseSpawnValid},
        {"parseSpawn invalid count", testParseSpawnInvalidCount},
        {"parseSpawn invalid number", testParseSpawnInvalidNumber},
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
