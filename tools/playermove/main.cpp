#include "assets/loaders/BspCollision.h"
#include "physics/PlayerMovement.h"

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>

namespace {

constexpr float GroundEpsilon = 0.03125F;

struct Args {
    int ticks = 8;
    float forwardMove = 0.0F;
    float sideMove = 0.0F;
    int jumpTick = -1;
    int crouchFromTick = -1;
    int crouchUntilTick = -1;
    bool startCrouched = false;
    bool standBlocked = false;
    bool help = false;
    osk::physics::PlayerMovementConfig config;
};

void printUsage(std::ostream& out) {
    out << "OpenStrikePlayerMove\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikePlayerMove [options]\n"
        << "\n"
        << "Options:\n"
        << "  --ticks n             Number of fixed ticks to simulate, default 8.\n"
        << "  --forward v           Forward input axis, clamped by movement code.\n"
        << "  --side v              Side input axis, clamped by movement code.\n"
        << "  --jump-tick n         Press jump on one tick.\n"
        << "  --crouch-from n       Hold crouch from tick n.\n"
        << "  --crouch-until n      Stop holding crouch after tick n.\n"
        << "  --start-crouched      Start the state crouched.\n"
        << "  --stand-blocked       Make the synthetic stand hull solid to show blocked uncrouch.\n"
        << "  --tick-seconds v      Fixed tick duration, default 1/60.\n"
        << "  --walk-speed v        Movement walk speed, default 160.\n"
        << "  --gravity v           Gravity, default 800.\n"
        << "  --jump-speed v        Jump impulse speed, default 270.\n"
        << "\n"
        << "This debug tool uses an in-memory synthetic ground plane. It does not read,\n"
        << "write, extract, cache, or copy user-provided assets.\n";
}

bool parseFloat(const std::string& value, float& out) {
    char* end = nullptr;
    out = std::strtof(value.c_str(), &end);
    return end != value.c_str() && end != nullptr && *end == '\0';
}

bool parseInt(const std::string& value, int& out) {
    char* end = nullptr;
    const long parsed = std::strtol(value.c_str(), &end, 10);
    if (end == value.c_str() || end == nullptr || *end != '\0') {
        return false;
    }
    out = static_cast<int>(parsed);
    return true;
}

bool requireInt(int argc, char** argv, int& index, int& out, const char* optionName) {
    if (index + 1 >= argc || !parseInt(argv[++index], out)) {
        std::cerr << "OpenStrikePlayerMove error: " << optionName << " requires an integer\n";
        return false;
    }
    return true;
}

bool requireFloat(int argc, char** argv, int& index, float& out, const char* optionName) {
    if (index + 1 >= argc || !parseFloat(argv[++index], out)) {
        std::cerr << "OpenStrikePlayerMove error: " << optionName << " requires a numeric value\n";
        return false;
    }
    return true;
}

bool parseArgs(int argc, char** argv, Args& args) {
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--help" || arg == "-h") {
            args.help = true;
            return true;
        }
        if (arg == "--ticks") {
            if (!requireInt(argc, argv, i, args.ticks, "--ticks")) {
                return false;
            }
            continue;
        }
        if (arg == "--forward") {
            if (!requireFloat(argc, argv, i, args.forwardMove, "--forward")) {
                return false;
            }
            continue;
        }
        if (arg == "--side") {
            if (!requireFloat(argc, argv, i, args.sideMove, "--side")) {
                return false;
            }
            continue;
        }
        if (arg == "--jump-tick") {
            if (!requireInt(argc, argv, i, args.jumpTick, "--jump-tick")) {
                return false;
            }
            continue;
        }
        if (arg == "--crouch-from") {
            if (!requireInt(argc, argv, i, args.crouchFromTick, "--crouch-from")) {
                return false;
            }
            continue;
        }
        if (arg == "--crouch-until") {
            if (!requireInt(argc, argv, i, args.crouchUntilTick, "--crouch-until")) {
                return false;
            }
            continue;
        }
        if (arg == "--start-crouched") {
            args.startCrouched = true;
            continue;
        }
        if (arg == "--stand-blocked") {
            args.standBlocked = true;
            continue;
        }
        if (arg == "--tick-seconds") {
            if (!requireFloat(argc, argv, i, args.config.tickSeconds, "--tick-seconds")) {
                return false;
            }
            continue;
        }
        if (arg == "--walk-speed") {
            if (!requireFloat(argc, argv, i, args.config.walkSpeed, "--walk-speed")) {
                return false;
            }
            continue;
        }
        if (arg == "--gravity") {
            if (!requireFloat(argc, argv, i, args.config.gravity, "--gravity")) {
                return false;
            }
            continue;
        }
        if (arg == "--jump-speed") {
            if (!requireFloat(argc, argv, i, args.config.jumpSpeed, "--jump-speed")) {
                return false;
            }
            continue;
        }

        std::cerr << "OpenStrikePlayerMove error: unexpected argument: " << arg << '\n';
        return false;
    }

    if (args.ticks <= 0) {
        std::cerr << "OpenStrikePlayerMove error: --ticks must be positive\n";
        return false;
    }
    return true;
}

osk::bsp::BspCollisionData makeGroundCollision(bool standBlocked) {
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
    model.headNodes[1] = standBlocked ? osk::bsp::BspContentsSolid : 0;
    model.headNodes[2] = 0;
    collision.models.push_back(model);
    return collision;
}

bool crouchHeld(const Args& args, int tick) {
    if (args.crouchFromTick < 0 || tick < args.crouchFromTick) {
        return false;
    }
    return args.crouchUntilTick < 0 || tick <= args.crouchUntilTick;
}

void printVec3(osk::bsp::Vec3 value) {
    std::cout << '(' << value.x << ", " << value.y << ", " << value.z << ')';
}

} // namespace

int main(int argc, char** argv) {
    Args args;
    if (!parseArgs(argc, argv, args)) {
        printUsage(std::cerr);
        return 1;
    }
    if (args.help) {
        printUsage(std::cout);
        return 0;
    }

    const osk::bsp::BspCollisionData collision = makeGroundCollision(args.standBlocked);
    const osk::physics::PlayerMovementTraceContext traceContext{
        .collision = &collision,
        .modelIndex = 0,
        .standHullIndex = 1,
        .crouchHullIndex = 2,
    };

    osk::physics::PlayerMovementState state;
    state.position = osk::bsp::Vec3{.x = 0.0F, .y = 0.0F, .z = GroundEpsilon};
    state.grounded = true;
    state.crouched = args.startCrouched;

    std::cout << std::fixed << std::setprecision(4);
    std::cout << "OpenStrikePlayerMove synthetic movement debug\n"
        << "  user assets read: no\n"
        << "  ticks: " << args.ticks << '\n'
        << "  stand hull: 1" << (args.standBlocked ? " (solid)" : "") << '\n'
        << "  crouch hull: 2\n\n";

    std::cout << "tick hull crouch ground jump blocked hit fraction position velocity warnings\n";
    for (int tick = 0; tick < args.ticks; ++tick) {
        const osk::physics::PlayerMovementInput input{
            .forwardMove = args.forwardMove,
            .sideMove = args.sideMove,
            .jump = tick == args.jumpTick,
            .crouch = crouchHeld(args, tick),
        };

        const osk::physics::PlayerMovementStepResult result = osk::physics::stepPlayerMovement(
            state,
            input,
            traceContext,
            args.config);
        state = result.state;

        std::cout << std::setw(4) << tick << ' '
            << std::setw(4) << result.hullIndex << ' '
            << std::setw(6) << (state.crouched ? "yes" : "no") << ' '
            << std::setw(6) << (state.grounded ? "yes" : "no") << ' '
            << std::setw(4) << (result.jumped ? "yes" : "no") << ' '
            << std::setw(7) << (result.uncrouchBlocked ? "yes" : "no") << ' '
            << std::setw(3) << (result.trace.hit ? "yes" : "no") << ' '
            << std::setw(8) << result.trace.fraction << ' ';
        printVec3(state.position);
        std::cout << ' ';
        printVec3(state.velocity);
        std::cout << ' ' << result.warnings.size() << '\n';

        for (const std::string& warning : result.warnings) {
            std::cout << "  warning: " << warning << '\n';
        }
    }

    return 0;
}
