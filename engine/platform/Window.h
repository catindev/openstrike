#pragma once

#include "input/InputState.h"

#include <memory>
#include <string>

namespace osk {

struct WindowDesc {
    std::string title = "OpenStrike";
    int width = 1280;
    int height = 720;
};

class Window final {
public:
    Window();
    ~Window();

    Window(const Window&) = delete;
    Window& operator=(const Window&) = delete;

    Window(Window&&) noexcept;
    Window& operator=(Window&&) noexcept;

    static std::unique_ptr<Window> create(const WindowDesc& desc, std::string* error = nullptr);

    void pollEvents();
    const input::InputState& inputState() const;
    bool shouldClose() const;
    void runUntilClosed();

private:
    struct Impl;

    explicit Window(std::unique_ptr<Impl> impl);

    std::unique_ptr<Impl> impl_;
};

} // namespace osk
