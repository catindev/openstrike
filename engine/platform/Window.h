#pragma once

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
    bool shouldClose() const;
    void runUntilClosed();

private:
    struct Impl;

    explicit Window(std::unique_ptr<Impl> impl);

    std::unique_ptr<Impl> impl_;
};

} // namespace osk
