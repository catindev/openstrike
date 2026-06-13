#include "physics/PlayerMovement.h"

#include <algorithm>
#include <cmath>

namespace osk::physics {
namespace {

bsp::Vec3 add(bsp::Vec3 a, bsp::Vec3 b) {
    return bsp::Vec3{.x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z};
}

bsp::Vec3 subtract(bsp::Vec3 a, bsp::Vec3 b) {
    return bsp::Vec3{.x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z};
}

bsp::Vec3 scale(bsp::Vec3 value, float factor) {
    return bsp::Vec3{.x = value.x * factor, .y = value.y * factor, .z = value.z * factor};
}

float dot(bsp::Vec3 a, bsp::Vec3 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

float clampMoveAxis(float value) {
    return std::clamp(value, -1.0F, 1.0F);
}

bsp::Vec3 desiredHorizontalVelocity(const PlayerMovementInput& input, float walkSpeed) {
    float forward = clampMoveAxis(input.forwardMove);
    float side = clampMoveAxis(input.sideMove);

    const float length = std::sqrt(forward * forward + side * side);
    if (length > 1.0F) {
        forward /= length;
        side /= length;
    }

    return bsp::Vec3{.x = forward * walkSpeed, .y = side * walkSpeed, .z = 0.0F};
}

bool isGroundHit(const bsp::BspTraceResult& trace, const PlayerMovementConfig& config) {
    return trace.valid && trace.hit && trace.hitNormal.z >= config.groundNormalMinZ;
}

void appendWarnings(std::vector<std::string>& target, const std::vector<std::string>& source) {
    target.insert(target.end(), source.begin(), source.end());
}

bsp::Vec3 clipVelocity(bsp::Vec3 velocity, bsp::Vec3 normal) {
    const float intoPlane = dot(velocity, normal);
    if (intoPlane >= 0.0F) {
        return velocity;
    }

    return subtract(velocity, scale(normal, intoPlane));
}

} // namespace

PlayerMovementStepResult stepPlayerMovement(
    const PlayerMovementState& current,
    const PlayerMovementInput& input,
    const PlayerMovementTraceContext& traceContext,
    const PlayerMovementConfig& config) {
    PlayerMovementStepResult result;
    result.state = current;
    result.hullIndex = current.crouched ? traceContext.crouchHullIndex : traceContext.standHullIndex;

    if (traceContext.collision == nullptr) {
        result.warnings.emplace_back("player movement trace context has no collision data");
        return result;
    }
    if (config.tickSeconds <= 0.0F) {
        result.warnings.emplace_back("player movement tick duration must be positive");
        return result;
    }

    PlayerMovementState next = current;
    next.crouched = input.crouch;
    std::size_t hullIndex = next.crouched ? traceContext.crouchHullIndex : traceContext.standHullIndex;

    if (current.crouched && !input.crouch) {
        const bsp::BspTraceResult standProbe = bsp::tracePoint(
            *traceContext.collision,
            bsp::BspTraceInput{
                .start = current.position,
                .end = current.position,
                .modelIndex = traceContext.modelIndex,
                .hullIndex = traceContext.standHullIndex,
            });
        appendWarnings(result.warnings, standProbe.warnings);
        if (standProbe.valid && standProbe.startSolid) {
            next.crouched = true;
            hullIndex = traceContext.crouchHullIndex;
            result.uncrouchBlocked = true;
            result.warnings.emplace_back("player uncrouch blocked by stand hull");
        }
    }
    result.hullIndex = hullIndex;

    const bsp::Vec3 desiredVelocity = desiredHorizontalVelocity(input, config.walkSpeed);
    next.velocity.x = desiredVelocity.x;
    next.velocity.y = desiredVelocity.y;

    const bool jumping = current.grounded && input.jump;
    if (jumping) {
        next.velocity.z = config.jumpSpeed;
        next.grounded = false;
        result.jumped = true;
    } else if (current.grounded) {
        next.velocity.z = 0.0F;
    }

    if (!current.grounded || jumping) {
        next.velocity.z -= config.gravity * config.tickSeconds;
    }

    const bsp::Vec3 target = add(next.position, scale(next.velocity, config.tickSeconds));
    result.trace = bsp::tracePoint(
        *traceContext.collision,
        bsp::BspTraceInput{
            .start = next.position,
            .end = target,
            .modelIndex = traceContext.modelIndex,
            .hullIndex = hullIndex,
        });
    appendWarnings(result.warnings, result.trace.warnings);

    if (!result.trace.valid) {
        next.grounded = false;
        result.state = next;
        return result;
    }

    next.position = result.trace.endPosition;
    if (isGroundHit(result.trace, config)) {
        next.velocity = clipVelocity(next.velocity, result.trace.hitNormal);
        if (next.velocity.z < 0.0F) {
            next.velocity.z = 0.0F;
        }
        next.grounded = true;
    } else if (result.trace.hit) {
        next.velocity = clipVelocity(next.velocity, result.trace.hitNormal);
        next.grounded = false;
    } else {
        next.grounded = current.grounded && !jumping && next.velocity.z <= 0.0F;
    }

    result.state = next;
    return result;
}

} // namespace osk::physics
