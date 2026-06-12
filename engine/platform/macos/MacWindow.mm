#include "platform/Window.h"

#import <Cocoa/Cocoa.h>

#include <chrono>
#include <memory>
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

namespace osk {

struct Window::Impl {
    NSWindow* window = nil;
    OSKWindowDelegate* delegate = nil;
    bool closeRequested = false;
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

            if ([event type] == NSEventTypeKeyDown) {
                NSString* characters = [event charactersIgnoringModifiers];
                if ([characters length] > 0 && [characters characterAtIndex:0] == 27) {
                    impl_->closeRequested = true;
                    [impl_->window close];
                    break;
                }
            }

            [NSApp sendEvent:event];
        }

        [NSApp updateWindows];
    }
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
