#include "assets/loaders/BspMesh.h"

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <exception>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace {

struct ViewerVertex {
    vector_float3 position;
    vector_float3 normal;
};

float length3(const osk::bsp::Vec3& value) {
    return std::sqrt(value.x * value.x + value.y * value.y + value.z * value.z);
}

osk::bsp::Vec3 rotateDebugView(osk::bsp::Vec3 value) {
    constexpr float yaw = 0.7853981633974483F;    // 45 degrees.
    constexpr float pitch = -0.9599310885968813F; // -55 degrees.

    const float cy = std::cos(yaw);
    const float sy = std::sin(yaw);
    const float cp = std::cos(pitch);
    const float sp = std::sin(pitch);

    const float x0 = value.x * cy - value.y * sy;
    const float y0 = value.x * sy + value.y * cy;
    const float z0 = value.z;

    return osk::bsp::Vec3{
        .x = x0,
        .y = y0 * cp - z0 * sp,
        .z = y0 * sp + z0 * cp,
    };
}

std::vector<ViewerVertex> buildViewerVertices(const osk::bsp::BspWorldMesh& mesh) {
    std::vector<ViewerVertex> vertices;
    vertices.reserve(mesh.vertices.size());

    osk::bsp::Vec3 center{};
    osk::bsp::Vec3 extent{};
    if (mesh.bounds.valid) {
        center = osk::bsp::Vec3{
            .x = (mesh.bounds.min.x + mesh.bounds.max.x) * 0.5F,
            .y = (mesh.bounds.min.y + mesh.bounds.max.y) * 0.5F,
            .z = (mesh.bounds.min.z + mesh.bounds.max.z) * 0.5F,
        };
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

    for (const osk::bsp::BspMeshVertex& source : mesh.vertices) {
        const osk::bsp::Vec3 centered{
            .x = source.position.x - center.x,
            .y = source.position.y - center.y,
            .z = source.position.z - center.z,
        };
        const osk::bsp::Vec3 p = rotateDebugView(centered);
        const osk::bsp::Vec3 n = rotateDebugView(source.normal);

        const float z = std::clamp(p.z / (radius * 2.0F) + 0.5F, 0.0F, 1.0F);
        vertices.push_back(ViewerVertex{
            .position = vector_float3{p.x / radius * 0.9F, p.y / radius * 0.9F, z},
            .normal = vector_float3{n.x, n.y, n.z},
        });
    }

    return vertices;
}

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
    float3 n = abs(normalize(input.normal));
    float3 color = 0.20 + n * 0.75;
    return float4(color, 1.0);
}
)";
}

std::string nsStringToStdString(NSString* value) {
    if (value == nil) {
        return {};
    }
    return std::string([value UTF8String]);
}

void printUsage(std::ostream& out) {
    out << "OpenStrikeBspView\n"
        << "\n"
        << "Usage:\n"
        << "  OpenStrikeBspView <path/to/map.bsp>\n"
        << "\n"
        << "This debug tool opens a native macOS Metal window and displays a\n"
        << "wireframe view of local user-provided BSP geometry. It does not copy,\n"
        << "extract, or write user-provided assets.\n";
}

} // namespace

@interface OSKBspViewDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, assign) BOOL closeRequested;
@end

@implementation OSKBspViewDelegate
- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    self.closeRequested = YES;
    return YES;
}
@end

@interface OSKBspMetalRenderer : NSObject <MTKViewDelegate> {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState> _depthState;
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    NSUInteger _indexCount;
}
- (instancetype)initWithView:(MTKView*)view mesh:(const osk::bsp::BspWorldMesh&)mesh errorMessage:(std::string*)errorMessage;
@end

@implementation OSKBspMetalRenderer

- (instancetype)initWithView:(MTKView*)view mesh:(const osk::bsp::BspWorldMesh&)mesh errorMessage:(std::string*)errorMessage {
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

    const std::vector<ViewerVertex> vertices = buildViewerVertices(mesh);
    if (vertices.empty() || mesh.indices.empty()) {
        if (errorMessage != nullptr) {
            *errorMessage = "BSP world mesh has no drawable geometry";
        }
        [self release];
        return nil;
    }

    _vertexBuffer = [_device newBufferWithBytes:vertices.data()
                                         length:vertices.size() * sizeof(ViewerVertex)
                                        options:MTLResourceStorageModeManaged];
    _indexBuffer = [_device newBufferWithBytes:mesh.indices.data()
                                        length:mesh.indices.size() * sizeof(std::uint32_t)
                                       options:MTLResourceStorageModeManaged];
    _indexCount = static_cast<NSUInteger>(mesh.indices.size());

    if (_vertexBuffer == nil || _indexBuffer == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal mesh buffers";
        }
        [self release];
        return nil;
    }

    NSError* libraryError = nil;
    id<MTLLibrary> library = [_device newLibraryWithSource:shaderSource() options:nil error:&libraryError];
    if (library == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to compile Metal shaders: " + nsStringToStdString([libraryError localizedDescription]);
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
            *errorMessage = "failed to create Metal render pipeline: " + nsStringToStdString([pipelineError localizedDescription]);
        }
        [self release];
        return nil;
    }

    MTLDepthStencilDescriptor* depthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    depthDescriptor.depthWriteEnabled = NO;
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
    [encoder setTriangleFillMode:MTLTriangleFillModeLines];
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

int main(int argc, char** argv) {
    if (argc == 2) {
        const std::string arg = argv[1];
        if (arg == "--help" || arg == "-h") {
            printUsage(std::cout);
            return 0;
        }
    }

    if (argc != 2) {
        printUsage(std::cerr);
        return 1;
    }

    try {
        const fs::path path = argv[1];
        const osk::bsp::BspWorldMesh mesh = osk::bsp::loadBspWorldMesh(path);

        @autoreleasepool {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            if (device == nil) {
                std::cerr << "OpenStrikeBspView error: Metal is not available on this system\n";
                return 1;
            }

            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

            const NSRect frame = NSMakeRect(0.0, 0.0, 1280.0, 720.0);
            const NSWindowStyleMask style = NSWindowStyleMaskTitled
                | NSWindowStyleMaskClosable
                | NSWindowStyleMaskMiniaturizable
                | NSWindowStyleMaskResizable;

            NSWindow* window = [[NSWindow alloc]
                initWithContentRect:frame
                          styleMask:style
                            backing:NSBackingStoreBuffered
                              defer:NO];
            if (window == nil) {
                std::cerr << "OpenStrikeBspView error: failed to create NSWindow\n";
                return 1;
            }

            NSString* title = [[NSString alloc] initWithFormat:@"OpenStrike BSP View - %s", path.filename().string().c_str()];
            [window setTitle:title];
            [title release];

            OSKBspViewDelegate* windowDelegate = [[OSKBspViewDelegate alloc] init];
            [window setDelegate:windowDelegate];

            MTKView* view = [[MTKView alloc] initWithFrame:frame device:device];
            view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
            view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
            view.clearColor = MTLClearColorMake(0.03, 0.035, 0.045, 1.0);
            view.paused = YES;
            view.enableSetNeedsDisplay = NO;

            std::string rendererError;
            OSKBspMetalRenderer* renderer = [[OSKBspMetalRenderer alloc] initWithView:view mesh:mesh errorMessage:&rendererError];
            if (renderer == nil) {
                std::cerr << "OpenStrikeBspView error: " << rendererError << '\n';
                [view release];
                [windowDelegate release];
                [window release];
                return 1;
            }

            [view setDelegate:renderer];
            [window setContentView:view];
            [window center];
            [window makeKeyAndOrderFront:nil];
            [NSApp activateIgnoringOtherApps:YES];

            std::cout << "OpenStrikeBspView running. Press Esc or close the window to exit.\n";
            std::cout << "Mesh: " << mesh.vertices.size() << " vertices, "
                << mesh.indices.size() << " indices, "
                << mesh.triangleCount() << " triangles\n";

            while (![windowDelegate closeRequested]) {
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
                                [windowDelegate setCloseRequested:YES];
                                [window close];
                                break;
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
    } catch (const std::exception& e) {
        std::cerr << "OpenStrikeBspView error: " << e.what() << '\n';
        return 1;
    }
}
