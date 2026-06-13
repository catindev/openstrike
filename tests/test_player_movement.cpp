#include "assets/loaders/BspCollision.h"
#include "physics/PlayerMovement.h"

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

osk::bsp::BspCollisionData makeGroundCollision() {
    osk::bsp::BspCollisionData collision;
    collision.planes.push_back(osk::bsp::BspCollisionPlane{
        .normal = osk::bsp::Vec3{.x = 0.0F, .y = 0.0F, .z = 1.0F},
        .distance = 0.0F,
        .type = 2,
    });
    collision.clipNodes.push_back(osk::bsp::BspClipNode{
        .planeIndex = 0,
        .children = {osk::bsp::BspContentsEmpty, osk::bsp::BspContentsSolid},
    });

    osk::bsp::BspModelCollisionInfo model;
    model.modelIndex = 0;
    model.headNodes.fill(-1);
    model.headNodes[1] = 0;
    collision.models.push_back(model);
    return collision;
}

osk::physics::PlayerMovementTraceContext traceContext(const osk::bsp::BspCollisionData& collision) {
    return osk::physics::PlayerMovementTraceContext{
        .collision = &collision,
        .modelIndex = 0,
        .hullIndex = 1,
    };
}

void testWalkMovesAtFixedTick() {
    const osk::bsp::BspCollisionData collision = makeGroundCollision();
    osk::physics::PlayerMovementConfig config;
    config.tickSeconds = 0.1F;
    config.walkSpeed = 10.0F;
    config.gravity = 0.0F;

    osk::physics::PlayerMovementState state;
    state.position = osk::bsp::Vec3{.x = 0.0F, .y = 0.0F, .z = 0.03125F};
    state.grounded = true;

    const osk::physics::PlayerMovementStepResult result = osk::physics::stepPlayerMovement(
        state,
        osk::physics::PlayerMovementInput{.forwardMove = 1.0F},
        traceContext(collision),
        config);

    require(result.trace.valid, "walk trace should be valid");
    require(!result.trace.hit, "walk on open ground should not hit with zero gravity");
    require(result.state.grounded, "walk should preserve grounded state");
    requireNear(result.state.position.x, 1.0F, 0.0001F, "walk x position");
    requireNear(result.state.position.y, 0.0F, 0.0001F, "walk y position");
    requireNear(result.state.position.z, 0.03125F, 0.0001F, "walk z position");
    requireNear(result.state.velocity.x, 10.0F, 0.0001F, "walk x velocity");
}

void testDefaultStateIsStationary() {
    const osk::bsp::BspCollisionData collision = makeGroundCollision();
    osk::physics::PlayerMovementConfig config;
    config.tickSeconds = 0.1F;
    config.walkSpeed = 10.0F;
    config.gravity = 0.0F;

    const osk::physics::PlayerMovementStepResult result = osk::physics::stepPlayerMovement(
        osk::physics::PlayerMovementState{},
        osk::physics::PlayerMovementInput{},
        traceContext(collision),
        config);

    require(result.trace.valid, "default-state trace should be valid");
    require(!result.trace.hit, "default state should not hit with zero gravity");
    requireNear(result.state.position.x, 0.0F, 0.0001F, "default x position");
    requireNear(result.state.position.y, 0.0F, 0.0001F, "default y position");
    requireNear(result.state.position.z, 0.0F, 0.0001F, "default z position");
    requireNear(result.state.velocity.x, 0.0F, 0.0001F, "default x velocity");
    requireNear(result.state.velocity.y, 0.0F, 0.0001F, "default y velocity");
    requireNear(result.state.velocity.z, 0.0F, 0.0001F, "default z velocity");
}

void testGravityLandsOnGroundPlane() {
    const osk::bsp::BspCollisionData collision = makeGroundCollision();
    osk::physics::PlayerMovementConfig config;
    config.tickSeconds = 1.0F;
    config.walkSpeed = 0.0F;
    config.gravity = 0.0F;

    osk::physics::PlayerMovementState state;
    state.position = osk::bsp::Vec3{.x = 0.0F, .y = 0.0F, .z = 8.0F};
    state.velocity = osk::bsp::Vec3{.x = 0.0F, .y = 0.0F, .z = -20.0F};
    state.grounded = false;

    const osk::physics::PlayerMovementStepResult result = osk::physics::stepPlayerMovement(
        state,
        osk::physics::PlayerMovementInput{},
        traceContext(collision),
        config);

    require(result.trace.valid, "fall trace should be valid");
    require(result.trace.hit, "fall should hit the ground plane");
    require(result.state.grounded, "fall should land on ground");
    requireNear(result.state.velocity.z, 0.0F, 0.0001F, "landed z velocity");
    require(result.state.position.z > 0.0F && result.state.position.z < 0.1F, "landed z position should be trace epsilon above ground");
}

void testJumpLeavesGround() {
    const osk::bsp::BspCollisionData collision = makeGroundCollision();
    osk::physics::PlayerMovementConfig config;
    config.tickSeconds = 0.1F;
    config.walkSpeed = 0.0F;
    config.gravity = 0.0F;
    config.jumpSpeed = 100.0F;

    osk::physics::PlayerMovementState state;
    state.position = osk::bsp::Vec3{.x = 0.0F, .y = 0.0F, .z = 0.03125F};
    state.grounded = true;

    const osk::physics::PlayerMovementStepResult result = osk::physics::stepPlayerMovement(
        state,
        osk::physics::PlayerMovementInput{.jump = true},
        traceContext(collision),
        config);

    require(result.trace.valid, "jump trace should be valid");
    require(result.jumped, "jump should be reported");
    require(!result.state.grounded, "jump should leave ground");
    requireNear(result.state.velocity.z, 100.0F, 0.0001F, "jump z velocity");
    require(result.state.position.z > state.position.z, "jump should move upward during the tick");
}

void testMissingTraceContextWarns() {
    const osk::physics::PlayerMovementStepResult result = osk::physics::stepPlayerMovement(
        osk::physics::PlayerMovementState{},
        osk::physics::PlayerMovementInput{},
        osk::physics::PlayerMovementTraceContext{});

    require(!result.trace.valid, "missing trace context should not produce a valid trace");
    require(!result.warnings.empty(), "missing trace context should warn");
}

using TestFn = void (*)();

struct TestCase {
    const char* name;
    TestFn function;
};

} // namespace

int main() {
    const std::vector<TestCase> tests{
        {"walk moves at fixed tick", testWalkMovesAtFixedTick},
        {"default state is stationary", testDefaultStateIsStationary},
        {"gravity lands on ground plane", testGravityLandsOnGroundPlane},
        {"jump leaves ground", testJumpLeavesGround},
        {"missing trace context warns", testMissingTraceContextWarns},
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
