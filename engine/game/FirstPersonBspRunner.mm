// This file defines a minimal first‑person BSP renderer for macOS.  The
// implementation mirrors the debug BSP viewer but fixes the camera
// translation to a user‑supplied spawn position and removes orbit
// controls and texture atlas handling.  The renderer is compiled only
// on macOS; on other platforms the run function will emit an error.

#include "game/FirstPersonBspRunner.h"

#include "assets/loaders/BspMesh.h"
#include <iostream>
#include <memory>
#include <string>
#include <cmath>

#if defined(__APPLE__)

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

namespace {

// Simple camera structure used for computing relative vertex positions.
struct FirstPersonCamera {
    float yaw = 0.0F;
    float pitch = 0.0F;
    float zoom = 1.0F;
    osk::bsp::Vec3 position{};
};

// Compact vertex structure used for the Metal vertex buffer.  It
// contains a position and normal only; texture coordinates are
// intentionally omitted for this minimal renderer.
struct FirstPersonVertex {
    vector_float3 position;
    vector_float3 normal;
};

// Compute the Euclidean length of a 3‑vector.
float length3(const osk::bsp::Vec3& v) {
    return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

// Rotate a vector around yaw (about the Z axis) and pitch (about the X
// axis) to transform from world space into camera space.  This
// implementation is identical to the helper used in the debug BSP
// viewer.
osk::bsp::Vec3 rotateView(const osk::bsp::Vec3& value, const FirstPersonCamera& camera) {
    const float cy = std::cos(camera.yaw);
    const float sy = std::sin(camera.yaw);
    const float cp = std::cos(camera.pitch);
    const float sp = std::sin(camera.pitch);
    const float x0 = value.x * cy - value.y * sy;
    const float y0 = value.x * sy + value.y * cy;
    const float z0 = value.z;
    return osk::bsp::Vec3{
        .x = x0,
        .y = y0 * cp - z0 * sp,
        .z = y0 * sp + z0 * cp,
    };
}

// Clamp a floating value to the [0,1] range.  Non‑finite inputs map to 0.
float clamp01(float v) {
    if (!std::isfinite(v)) {
        return 0.0F;
    }
    return v < 0.0F ? 0.0F : (v > 1.0F ? 1.0F : v);
}

// Build a list of vertices for the world mesh relative to the camera.
// The mesh is scaled by the radius of its bounding box to keep the
// scene within Metal's clip space.  Depth is encoded in the z
// component but true perspective projection is not implemented.
std::vector<FirstPersonVertex> buildVertices(
    const osk::bsp::BspWorldMesh& mesh,
    const FirstPersonCamera& camera) {
    std::vector<FirstPersonVertex> vertices(mesh.vertices.size());
    osk::bsp::Vec3 extent{};
    if (mesh.bounds.valid) {
        extent = osk::bsp::Vec3{
            .x = mesh.bounds.max.x - mesh.bounds.min.x,
            .y = mesh.bounds.max.y - mesh.bounds.min.y,
            .z = mesh.bounds.max.z - mesh.bounds.min.z,
        };
    }
    float radius = length3(extent) * 0.5F;
    if (radius <= 0.0F) {
        radius = 1.0F;
    }
    const float viewScale = 0.9F * camera.zoom;
    for (std::size_t i = 0; i < mesh.vertices.size(); ++i) {
        const osk::bsp::BspMeshVertex& src = mesh.vertices[i];
        const osk::bsp::Vec3 rel{
            .x = src.position.x - camera.position.x,
            .y = src.position.y - camera.position.y,
            .z = src.position.z - camera.position.z,
        };
        const osk::bsp::Vec3 p = rotateView(rel, camera);
        const osk::bsp::Vec3 n = rotateView(src.normal, camera);
        const float zNorm = clamp01(p.z / (radius * 2.0F) + 0.5F);
        vertices[i] = FirstPersonVertex{
            .position = vector_float3{p.x / radius * viewScale, p.y / radius * viewScale, zNorm},
            .normal = vector_float3{n.x, n.y, n.z},
        };
    }
    return vertices;
}

// Metal shader source for the minimal first‑person renderer.  It uses
// per‑vertex normals to compute a simple diffuse shading with a fixed
// light direction and constant base colour.  No texture sampling is
// performed.
NSString* shaderSource() {
    return @R"(
#include <metal_stdlib>
using namespace metal;
struct VertexIn {
    float3 position;
    float3 normal;
};
struct VertexOut {
    float4 position [[position]];
    float3 normal;
};
vertex VertexOut vertex_main(
    const device VertexIn* vertices [[buffer(0)]],
    uint vertexId [[vertex_id]]) {
    VertexIn input = vertices[vertexId];
    VertexOut output;
    output.position = float4(input.position, 1.0);
    output.normal = normalize(input.normal);
    return output;
}
fragment float4 fragment_main(VertexOut input [[stage_in]]) {
    float3 lightDir = normalize(float3(0.5, 1.0, 0.5));
    float intensity = clamp(dot(normalize(input.normal), lightDir), 0.0, 1.0);
    float3 colour = float3(0.7, 0.7, 0.7) * intensity + float3(0.3, 0.3, 0.3);
    return float4(colour, 1.0);
}
)";
}

// Simple window delegate used to detect when the user closes the
// first‑person window.  When the window should close, the
// closeRequested flag is set to true and the run loop terminates.
@interface OSKFirstPersonWindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, assign) BOOL closeRequested;
@end

@implementation OSKFirstPersonWindowDelegate
- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    self.closeRequested = YES;
    return YES;
}
@end

// Objective‑C++ class that acts as the MTKView delegate for the
// first‑person renderer.  It holds Metal objects and draws the mesh
// using the simple shading pipeline.  It does not update the camera
// orientation or zoom after initialization.
@interface OSKFirstPersonMetalRenderer : NSObject <MTKViewDelegate> {
@private
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthState;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    NSUInteger _indexCount;
}
- (instancetype)initWithView:(MTKView*)view
                         mesh:(const osk::bsp::BspWorldMesh&)mesh
                        spawn:(const osk::bsp::Vec3&)spawn
                 errorMessage:(std::string*)errorMessage;
@end

@implementation OSKFirstPersonMetalRenderer

- (instancetype)initWithView:(MTKView*)view
                         mesh:(const osk::bsp::BspWorldMesh&)mesh
                        spawn:(const osk::bsp::Vec3&)spawn
                 errorMessage:(std::string*)errorMessage {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    // Create a camera with the given spawn.  Yaw and pitch default
    // to zero so the camera looks down the positive X axis by
    // convention.  Zoom defaults to 1.
    FirstPersonCamera camera;
    camera.position = spawn;
    camera.yaw = 0.0F;
    camera.pitch = 0.0F;
    camera.zoom = 1.0F;
    _device = [view.device retain];
    _commandQueue = [_device newCommandQueue];
    if (_commandQueue == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal command queue";
        }
        [self release];
        return nil;
    }
    {
        const std::vector<FirstPersonVertex> verts = buildVertices(mesh, camera);
        _vertexBuffer = [_device newBufferWithBytes:verts.data()
                                              length:verts.size() * sizeof(FirstPersonVertex)
                                             options:MTLResourceStorageModeManaged];
        if (_vertexBuffer == nil) {
            if (errorMessage != nullptr) {
                *errorMessage = "failed to create Metal vertex buffer";
            }
            [self release];
            return nil;
        }
    }
    _indexBuffer = [_device newBufferWithBytes:mesh.indices.data()
                                        length:mesh.indices.size() * sizeof(std::uint32_t)
                                       options:MTLResourceStorageModeManaged];
    _indexCount = static_cast<NSUInteger>(mesh.indices.size());
    if (_indexBuffer == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal index buffer";
        }
        [self release];
        return nil;
    }
    NSError* libraryError = nil;
    id<MTLLibrary> library = [_device newLibraryWithSource:shaderSource() options:nil error:&libraryError];
    if (library == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to compile Metal shaders: " + std::string([[libraryError localizedDescription] UTF8String]);
        }
        [self release];
        return nil;
    }
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    MTLRenderPipelineDescriptor* pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    NSError* pipelineError = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&pipelineError];
    [pipelineDescriptor release];
    [vertexFunction release];
    [fragmentFunction release];
    [library release];
    if (_pipelineState == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal render pipeline: " + std::string([[pipelineError localizedDescription] UTF8String]);
        }
        [self release];
        return nil;
    }
    MTLDepthStencilDescriptor* depthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
    depthDescriptor.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthDescriptor];
    [depthDescriptor release];
    if (_depthState == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal depth state";
        }
        [self release];
        return nil;
    }
    return self;
}

- (void)dealloc {
    [_depthState release];
    [_pipelineState release];
    [_indexBuffer release];
    [_vertexBuffer release];
    [_commandQueue release];
    [_device release];
    [super dealloc];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {
    (void)view;
    (void)size;
}

- (void)drawInMTKView:(MTKView*)view {
    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor* passDescriptor = view.currentRenderPassDescriptor;
    if (drawable == nil || passDescriptor == nil) {
        return;
    }
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [encoder setRenderPipelineState:_pipelineState];
    [encoder setDepthStencilState:_depthState];
    [encoder setCullMode:MTLCullModeNone];
    [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:_indexCount
                         indexType:MTLIndexTypeUInt32
                       indexBuffer:_indexBuffer
                indexBufferOffset:0];
    [encoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end

} // namespace

// Begin public API implementation.
namespace osk::game {

int runFirstPersonBsp(const FirstPersonBspOptions& options) {
    if (options.mapPath.empty()) {
        std::cerr << options.logName << " error: missing playable map path\n";
        return 1;
    }
    try {
        (void)osk::bsp::loadBspSummary(options.mapPath);
    } catch (const osk::bsp::BspFormatError& e) {
        std::cerr << options.logName << " error: playable map file is not a valid BSP: " << e.what() << '\n';
        return 1;
    } catch (const std::exception& e) {
        std::cerr << options.logName << " error: failed to load playable map: " << e.what() << '\n';
        return 1;
    }
    osk::bsp::BspWorldMesh mesh;
    try {
        mesh = osk::bsp::loadBspWorldMesh(options.mapPath);
    } catch (const std::exception& e) {
        std::cerr << options.logName << " error: failed to load world mesh: " << e.what() << '\n';
        return 1;
    }
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            std::cerr << options.logName << " error: Metal is not available on this system\n";
            return 1;
        }
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        const NSRect frame = NSMakeRect(0.0, 0.0, 1280.0, 720.0);
        const NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
        NSWindow* window = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:style
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        if (window == nil) {
            std::cerr << options.logName << " error: failed to create NSWindow\n";
            return 1;
        }
        NSString* title = [[NSString alloc] initWithFormat:"%s - %s", options.windowTitlePrefix.c_str(), options.mapPath.filename().string().c_str()];
        [window setTitle:title];
        [title release];
        OSKFirstPersonWindowDelegate* windowDelegate = [[OSKFirstPersonWindowDelegate alloc] init];
        windowDelegate.closeRequested = NO;
        [window setDelegate:windowDelegate];
        MTKView* view = [[MTKView alloc] initWithFrame:frame device:device];
        view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        view.clearColor = MTLClearColorMake(0.03, 0.035, 0.045, 1.0);
        view.paused = YES;
        view.enableSetNeedsDisplay = NO;
        std::string rendererError;
        OSKFirstPersonMetalRenderer* renderer = [[OSKFirstPersonMetalRenderer alloc] initWithView:view
                                                                                            mesh:mesh
                                                                                           spawn:options.spawn
                                                                                     errorMessage:&rendererError];
        if (renderer == nil) {
            std::cerr << options.logName << " error: " << rendererError << '\n';
            [view release];
            [windowDelegate release];
            [window release];
            return 1;
        }
        [view setDelegate:renderer];
        [window setContentView:view];
        [window center];
        [window makeKeyAndOrderFront:nil];
        [window makeFirstResponder:view];
        [NSApp activateIgnoringOtherApps:YES];
        std::cout << options.logName << " first‑person BSP view running. Press Esc or close the window to exit.\n";
        while (!windowDelegate.closeRequested) {
            @autoreleasepool {
                for (;;) {
                    NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                                    untilDate:[NSDate distantPast]
                                                       inMode:NSDefaultRunLoopMode
                                                      dequeue:YES];
                    if (event == nil) {
                        break;
                    }
                    if ([event type] == NSEventTypeKeyDown) {
                        NSString* characters = [event charactersIgnoringModifiers];
                        if ([characters length] > 0) {
                            const unichar key = [characters characterAtIndex:0];
                            if (key == 27) { // Escape
                                windowDelegate.closeRequested = YES;
                                [window close];
                                continue;
                            }
                        }
                    }
                    [NSApp sendEvent:event];
                }
                [NSApp updateWindows];
                [view draw];
                [NSThread sleepForTimeInterval:1.0 / 60.0];
            }
        }
        [view setDelegate:nil];
        [renderer release];
        [view release];
        [window setDelegate:nil];
        [windowDelegate release];
        [window close];
        [window release];
    }
    return 0;
}

} // namespace osk::game

#else  // defined(__APPLE__)

namespace osk::game {

int runFirstPersonBsp(const FirstPersonBspOptions& options) {
    (void)options;
    std::cerr << "OpenStrike error: first‑person BSP view is currently available only on macOS.\n";
    return 1;
}

} // namespace osk::game

#endif // defined(__APPLE__)
