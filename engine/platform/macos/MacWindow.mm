#include "platform/Window.h"

#import <Cocoa/Cocoa.h>

#include <chrono>
#include <memory>
#include <optional>
#include <string>
#include <thread>
#include <utility>

@interface OSKWindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, assign) BOOL closeRequested;
@end

@implementation OSKWindowDelegate

- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    self.closeRequested = YES;
    return YES;
}

@end

namespace {

std::optional<osk::input::InputKey> mapKeyEvent(NSEvent* event) {
    NSString* characters = [event charactersIgnoringModifiers];
    if (characters == nil || [characters length] == 0) {
        return std::nullopt;
    }

    const unichar character = [characters characterAtIndex:0];
    switch (character) {
    case 'w':
    case 'W':
        return osk::input::InputKey::Forward;
    case 's':
    case 'S':
        return osk::input::InputKey::Back;
    case 'a':
    case 'A':
        return osk::input::InputKey::Left;
    case 'd':
    case 'D':
        return osk::input::InputKey::Right;
    case ' ':
        return osk::input::InputKey::Jump;
    case 'c':
    case 'C':
        return osk::input::InputKey::Crouch;
    case 27:
        return osk::input::InputKey::Exit;
    default:
        return std::nullopt;
    }
}

bool isMouseMotionEvent(NSEventType type) {
    return type == NSEventTypeMouseMoved
        || type == NSEventTypeLeftMouseDragged
        || type == NSEventTypeRightMouseDragged
        || type == NSEventTypeOtherMouseDragged;
}

} // namespace

namespace osk {

struct Window::Impl {
    NSWindow* window = nil;
    OSKWindowDelegate* delegate = nil;
    bool closeRequested = false;
    input::InputState inputState;
};

Window::Window() = default;

Window::Window(std::unique_ptr<Impl> impl)
    : impl_(std::move(impl)) {
}

Window::~Window() {
    if (!impl_) {
        return;
    }

    if (impl_->window != nil) {
        [impl_->window setDelegate:nil];
        [impl_->window close];
        [impl_->window release];
        impl_->window = nil;
    }

    if (impl_->delegate != nil) {
        [impl_->delegate release];
        impl_->delegate = nil;
    }
}

Window::Window(Window&&) noexcept = default;
Window& Window::operator=(Window&&) noexcept = default;

std::unique_ptr<Window> Window::create(const WindowDesc& desc, std::string* error) {
    @autoreleasepool {
        if (desc.width <= 0 || desc.height <= 0) {
            if (error != nullptr) {
                *error = "window dimensions must be positive";
            }
            return nullptr;
        }

        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        const NSRect frame = NSMakeRect(0.0, 0.0, static_cast<CGFloat>(desc.width), static_cast<CGFloat>(desc.height));
        const NSWindowStyleMask style = NSWindowStyleMaskTitled
            | NSWindowStyleMaskClosable
            | NSWindowStyleMaskMiniaturizable
            | NSWindowStyleMaskResizable;

        NSWindow* nativeWindow = [[NSWindow alloc]
            initWithContentRect:frame
                      styleMask:style
                        backing:NSBackingStoreBuffered
                          defer:NO];

        if (nativeWindow == nil) {
            if (error != nullptr) {
                *error = "failed to create NSWindow";
            }
            return nullptr;
        }

        NSString* title = [[NSString alloc] initWithUTF8String:desc.title.c_str()];
        [nativeWindow setTitle:title];
        [title release];

        OSKWindowDelegate* delegate = [[OSKWindowDelegate alloc] init];
        [nativeWindow setDelegate:delegate];
        [nativeWindow center];
        [nativeWindow makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        auto impl = std::make_unique<Impl>();
        impl->window = nativeWindow;
        impl->delegate = delegate;

        return std::unique_ptr<Window>(new Window(std::move(impl)));
    }
}

void Window::pollEvents() {
    if (!impl_) {
        return;
    }

    input::resetFrameDeltas(impl_->inputState);

    @autoreleasepool {
        for (;;) {
            NSEvent* event = [NSApp
                nextEventMatchingMask:NSEventMaskAny
                            untilDate:[NSDate distantPast]
                               inMode:NSDefaultRunLoopMode
                              dequeue:YES];

            if (event == nil) {
                break;
            }

            const NSEventType type = [event type];
            if (type == NSEventTypeKeyDown || type == NSEventTypeKeyUp) {
                const bool down = type == NSEventTypeKeyDown;
                const std::optional<input::InputKey> mappedKey = mapKeyEvent(event);
                if (mappedKey.has_value()) {
                    input::setKey(impl_->inputState, *mappedKey, down);
                    if (down && *mappedKey == input::InputKey::Exit) {
                        impl_->closeRequested = true;
                        [impl_->window close];
                        break;
                    }
                }
            } else if (isMouseMotionEvent(type)) {
                input::addLookDelta(
                    impl_->inputState,
                    static_cast<float>([event deltaX]),
                    static_cast<float>([event deltaY]));
            }

            [NSApp sendEvent:event];
        }

        [NSApp updateWindows];
    }
}

const input::InputState& Window::inputState() const {
    static const input::InputState EmptyInputState;
    if (!impl_) {
        return EmptyInputState;
    }

    return impl_->inputState;
}

bool Window::shouldClose() const {
    if (!impl_) {
        return true;
    }

    if (impl_->closeRequested) {
        return true;
    }

    if (impl_->delegate != nil && [impl_->delegate closeRequested]) {
        return true;
    }

    return false;
}

void Window::runUntilClosed() {
    using namespace std::chrono_literals;

    while (!shouldClose()) {
        pollEvents();
        std::this_thread::sleep_for(8ms);
    }
}

} // namespace osk
