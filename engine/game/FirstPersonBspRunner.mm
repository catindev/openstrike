// This file defines a minimal first‑person BSP renderer for macOS.  The
// implementation mirrors the debug BSP viewer but fixes the camera
// translation to a user‑supplied spawn position and removes orbit
// controls and texture atlas handling.  The renderer is compiled only
// on macOS; on other platforms the run function will emit an error.

#include "game/FirstPersonBspRunner.h"
#include "assets/loaders/BspMesh.h"
#include "assets/loaders/BspLoader.h" // for loadBspSummary
#include "game/FirstPersonCamera.h"
#include <iostream>
#include <memory>
#include <string>
#include <cmath>
#include <simd/simd.h>

#if defined(__APPLE__)

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Compact vertex structure used for the Metal vertex buffer.  It
// contains a position and normal only; texture coordinates are
// intentionally omitted for this minimal renderer.
struct FirstPersonVertex {
    vector_float3 position;
    vector_float3 normal;
};

// Build a list of vertices for the world mesh.  The positions and normals
// are copied directly from the BSP mesh without any camera transform.  The
// vertex buffer thus stores world‑space coordinates and normals.
static std::vector<FirstPersonVertex> buildWorldVertices(const osk::bsp::BspWorldMesh& mesh) {
    std::vector<FirstPersonVertex> vertices(mesh.vertices.size());
    for (std::size_t i = 0; i < mesh.vertices.size(); ++i) {
        const osk::bsp::BspMeshVertex& src = mesh.vertices[i];
        vertices[i] = FirstPersonVertex{
            .position = vector_float3{src.position.x, src.position.y, src.position.z},
            .normal = vector_float3{src.normal.x, src.normal.y, src.normal.z},
        };
    }
    return vertices;
}

// Construct a right‑handed perspective projection matrix.  This helper
// produces a matrix compatible with Metal's clip space (z range 0..1).
static matrix_float4x4 makePerspectiveMatrix(float fovY, float aspect, float nearZ, float farZ) {
    const float yScale = 1.0f / std::tan(fovY * 0.5f);
    const float xScale = yScale / aspect;
    const float zRange = farZ - nearZ;
    matrix_float4x4 m = {};
    m.columns[0] = { xScale, 0.0f, 0.0f, 0.0f };
    m.columns[1] = { 0.0f, yScale, 0.0f, 0.0f };
    m.columns[2] = { 0.0f, 0.0f, farZ / zRange, 1.0f };
    m.columns[3] = { 0.0f, 0.0f, (-nearZ * farZ) / zRange, 0.0f };
    return m;
}

// Construct a view matrix from a camera position and orientation.  The
// yaw rotates around the Z axis and pitch rotates around the X axis.  This
// helper produces a matrix that transforms world coordinates into
// camera space.
static matrix_float4x4 makeViewMatrix(const osk::bsp::Vec3& pos, float yaw, float pitch) {
    const float cy = std::cos(yaw);
    const float sy = std::sin(yaw);
    const float cp = std::cos(pitch);
    const float sp = std::sin(pitch);
    // Orientation rows (world -> camera).
    const simd::float3 row0 = { cy, -sy, 0.0f };
    const simd::float3 row1 = { sy * cp, cy * cp, -sp };
    const simd::float3 row2 = { sy * sp, cy * sp, cp };
    // Translation part: -dot(row, pos)
    const float tx = -simd::dot(row0, simd::float3{pos.x, pos.y, pos.z});
    const float ty = -simd::dot(row1, simd::float3{pos.x, pos.y, pos.z});
    const float tz = -simd::dot(row2, simd::float3{pos.x, pos.y, pos.z});
    matrix_float4x4 m;
    m.columns[0] = { row0.x, row1.x, row2.x, 0.0f };
    m.columns[1] = { row0.y, row1.y, row2.y, 0.0f };
    m.columns[2] = { row0.z, row1.z, row2.z, 0.0f };
    m.columns[3] = { tx, ty, tz, 1.0f };
    return m;
}

// Uniform structure passed to the vertex shader.  It currently only
// contains the combined view‑projection matrix.
typedef struct {
    matrix_float4x4 viewProj;
} FirstPersonUniforms;

// Metal shader source for the first‑person renderer.  The vertex
// shader multiplies each vertex by the view‑projection matrix and
// passes the normal through.  The fragment shader computes a simple
// diffuse colour.
static NSString* shaderSource() {
    return @"\
#include <metal_stdlib>\
using namespace metal;\
\
struct VertexIn {\
    float3 position;\
    float3 normal;\
};\
\
struct Uniforms {\
    float4x4 viewProj;\
};\
\
struct VertexOut {\
    float4 position [[position]];\
    float3 normal;\
};\
\
vertex VertexOut vertex_main(const device VertexIn* vertices [[buffer(0)]],\
                              constant Uniforms& uniforms [[buffer(1)]],\
                              uint vertexId [[vertex_id]]) {\
    VertexIn input = vertices[vertexId];\
    VertexOut out;\
    out.position = uniforms.viewProj * float4(input.position, 1.0);\
    out.normal = normalize(input.normal);\
    return out;\
}\
\
fragment float4 fragment_main(VertexOut in [[stage_in]]) {\
    float3 lightDir = normalize(float3(0.5, 1.0, 0.5));\
    float intensity = clamp(dot(normalize(in.normal), lightDir), 0.0, 1.0);\
    float3 colour = float3(0.7, 0.7, 0.7) * intensity + float3(0.3, 0.3, 0.3);\
    return float4(colour, 1.0);\
}\
";
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
// using the simple shading pipeline.  It keeps mutable yaw and pitch
// values that are updated by the run loop.  Before each frame the
// view‑projection matrix is recomputed and stored in a uniform buffer.
@interface OSKFirstPersonMetalRenderer : NSObject <MTKViewDelegate> {
@private
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthState;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    id<MTLBuffer> _uniformBuffer;
    NSUInteger _indexCount;
    osk::bsp::Vec3 _position;
    float _yaw;
    float _pitch;
    float _fovY;
}
- (instancetype)initWithView:(MTKView*)view
                         mesh:(const osk::bsp::BspWorldMesh&)mesh
                        spawn:(const osk::bsp::Vec3&)spawn
                 errorMessage:(std::string*)errorMessage;
- (void)adjustYawDelta:(float)deltaX pitchDelta:(float)deltaY;
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
    _device = [view.device retain];
    _commandQueue = [_device newCommandQueue];
    if (_commandQueue == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal command queue";
        }
        [self release];
        return nil;
    }
    // Build vertex buffer with world positions.
    const std::vector<FirstPersonVertex> verts = buildWorldVertices(mesh);
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
    // Create uniform buffer for the view‑projection matrix.
    _uniformBuffer = [_device newBufferWithLength:sizeof(FirstPersonUniforms)
                                           options:MTLResourceStorageModeManaged];
    if (_uniformBuffer == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal uniform buffer";
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
    // Initialize camera state.
    _position = spawn;
    _yaw = 0.0f;
    _pitch = 0.0f;
    _fovY = 1.134464f; // ~65 degrees in radians
    return self;
}

- (void)dealloc {
    [_depthState release];
    [_pipelineState release];
    [_indexBuffer release];
    [_vertexBuffer release];
    [_uniformBuffer release];
    [_commandQueue release];
    [_device release];
    [super dealloc];
}

- (void)adjustYawDelta:(float)deltaX pitchDelta:(float)deltaY {
    // Convert pixel deltas into radians using a small sensitivity factor.
    constexpr float sensitivity = 0.0025f;
    osk::game::updateYawPitch(_yaw, _pitch, deltaX, -deltaY, sensitivity);
    // Clamp pitch to avoid looking too far up or down.  Use slightly less than ±90°.
    constexpr float maxPitch = 1.553343f; // about 89° in radians
    osk::game::clampPitch(_pitch, -maxPitch, maxPitch);
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
    // Update uniform buffer with the latest view‑projection matrix.
    const float aspect = (float)view.drawableSize.width / (float)view.drawableSize.height;
    const matrix_float4x4 proj = makePerspectiveMatrix(_fovY, aspect, 0.1f, 2000.0f);
    const matrix_float4x4 viewMat = makeViewMatrix(_position, _yaw, _pitch);
    const matrix_float4x4 vp = simd_mul(proj, viewMat);
    FirstPersonUniforms uniforms;
    uniforms.viewProj = vp;
    memcpy([_uniformBuffer contents], &uniforms, sizeof(uniforms));
    [_uniformBuffer didModifyRange:NSMakeRange(0, sizeof(uniforms))];
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [encoder setRenderPipelineState:_pipelineState];
    [encoder setDepthStencilState:_depthState];
    [encoder setCullMode:MTLCullModeNone];
    [encoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    [encoder setVertexBuffer:_uniformBuffer offset:0 atIndex:1];
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

// End of macOS section
#endif // defined(__APPLE__)

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
        // Enable mouse movement events so we can update the camera.
        [window setAcceptsMouseMovedEvents:YES];
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
                    NSEventType type = [event type];
                    if (type == NSEventTypeKeyDown) {
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
                    // Handle mouse movement to rotate the camera.  We use deltaX and deltaY
                    // directly from the event to adjust yaw and pitch via the renderer.
                    if (type == NSEventTypeMouseMoved || type == NSEventTypeLeftMouseDragged || type == NSEventTypeRightMouseDragged || type == NSEventTypeOtherMouseDragged) {
                        const float dx = [event deltaX];
                        const float dy = [event deltaY];
                        [renderer adjustYawDelta:dx pitchDelta:dy];
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
