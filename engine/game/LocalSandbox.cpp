#include "game/LocalSandbox.h"

#include "input/PlayerCommand.h"
#include "platform/Window.h"
#include "assets/loaders/BspLoader.h"

#include <chrono>
#include <filesystem>
#include <iostream>
#include <memory>
#include <thread>
#include <exception>

namespace fs = std::filesystem;

namespace osk::game {
namespace {

constexpr auto FixedTickDuration = std::chrono::duration<float>(1.0F / 60.0F);

void printCommandDebug(const input::PlayerCommand& command) {
    std::cout << "playable tick " << command.tick
              << " forward=" << command.forwardMove
              << " side=" << command.sideMove
              << " jump=" << (command.jump ? "yes" : "no")
              << " crouch=" << (command.crouch ? "yes" : "no")
              << " look=(" << command.lookDeltaX << ", " << command.lookDeltaY << ")"
              << " exit=" << (command.exit ? "yes" : "no")
              << '\n';
}

} // namespace

int runLocalSandbox(const LocalSandboxOptions& options) {
    if (options.mapPath.empty()) {
        std::cerr << "OpenStrike error: --playable-map requires a map path.\n";
        return 1;
    }

    if (!fs::exists(options.mapPath)) {
        std::cerr << "OpenStrike error: playable map path does not exist: " << options.mapPath.string() << '\n';
        return 1;
    }

    // Validate that the provided file is a BSP before opening a window.
    try {
        (void)osk::bsp::loadBspSummary(options.mapPath);
    } catch (const osk::bsp::BspFormatError& e) {
        std::cerr << "OpenStrike error: playable map file is not a valid BSP: " << e.what() << '\n';
        return 1;
    } catch (const std::exception& e) {
        std::cerr << "OpenStrike error: failed to load playable map: " << e.what() << '\n';
        return 1;
    }

    std::string error;
    std::unique_ptr<Window> window = Window::create(WindowDesc{
        .title = "OpenStrike Playable Sandbox",
        .width = 1280,
        .height = 720,
    }, &error);

    if (!window) {
        std::cerr << "OpenStrike error: failed to create playable sandbox window: " << error << '\n';
        return 3;
    }

    std::cout << "OpenStrike playable sandbox runtime shell running.\n"
              << "  map: " << options.mapPath.string() << '\n'
              << "  read-only resource roots: " << options.resourceRoots.size() << '\n'
              << "  debug input: " << (options.debugInput ? "on" : "off") << '\n'
              << "  collision-backed movement: not implemented in this slice\n"
              << "  renderer: placeholder window loop\n"
              << "Press Esc or close the window to exit.\n";

    std::uint64_t tick = 0;
    while (!window->shouldClose()) {
        const auto tickStart = std::chrono::steady_clock::now();

        window->pollEvents();
        const input::PlayerCommand command = input::buildPlayerCommand(window->inputState(), tick);
        if (options.debugInput) {
            printCommandDebug(command);
        }

        if (command.exit) {
            break;
        }

        ++tick;
        std::this_thread::sleep_until(tickStart + FixedTickDuration);
    }

    std::cout << "OpenStrike playable sandbox runtime shell closed after " << tick << " ticks.\n";
    return 0;
}

} // namespace osk::game
