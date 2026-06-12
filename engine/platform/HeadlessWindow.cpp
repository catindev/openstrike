#include "platform/Window.h"

#include <chrono>
#include <memory>
#include <string>
#include <thread>
#include <utility>

namespace osk {

struct Window::Impl {
    bool closeRequested = true;
};

Window::Window() = default;

Window::Window(std::unique_ptr<Impl> impl)
    : impl_(std::move(impl)) {
}

Window::~Window() = default;

Window::Window(Window&&) noexcept = default;
Window& Window::operator=(Window&&) noexcept = default;

std::unique_ptr<Window> Window::create(const WindowDesc& desc, std::string* error) {
    (void)desc;

    if (error != nullptr) {
        *error = "native window loop is currently implemented only for macOS";
    }

    return nullptr;
}

void Window::pollEvents() {
}

bool Window::shouldClose() const {
    return true;
}

void Window::runUntilClosed() {
    using namespace std::chrono_literals;
    std::this_thread::sleep_for(1ms);
}

} // namespace osk
