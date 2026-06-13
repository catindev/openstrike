#include "BspViewRunner.h"

#include "assets/ResourceIndex.h"
#include "assets/VirtualFileSystem.h"
#include "assets/loaders/BspLoader.h"
#include "assets/loaders/BspMesh.h"
#include "assets/loaders/TexturePackage.h"
#include "config/Config.h"
#include "config/ConfigPaths.h"

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <filesystem>
#include <iostream>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace fs = std::filesystem;

namespace {

struct ViewerVertex {
    vector_float3 position;
    vector_float3 normal;
    vector_float2 uv;
};

struct ViewerCamera {
    float yaw = 0.7853981633974483F;
    float pitch = -0.9599310885968813F;
    float zoom = 1.0F;
};

struct ViewerArgs {
    fs::path mapPath;
    std::vector<fs::path> resourceRoots;
    bool helpRequested = false;
};

struct TextureLibrary {
    std::unordered_map<std::string, osk::texture::DecodedTexture> textures;
    std::vector<std::string> warnings;
    std::size_t packageCount = 0;
    std::size_t decodedCount = 0;
};

struct AtlasRegion {
    float u0 = 0.0F;
    float v0 = 0.0F;
    float u1 = 1.0F;
    float v1 = 1.0F;
    std::uint32_t width = 1;
    std::uint32_t height = 1;
};

struct FaceMaterial {
    AtlasRegion region;
};

struct TextureAtlas {
    std::vector<std::uint8_t> pixels;
    std::uint32_t width = 1;
    std::uint32_t height = 1;
    std::vector<FaceMaterial> faceMaterials;
    std::vector<std::string> warnings;
    std::size_t decodedTextureCount = 0;
};

struct AtlasSource {
    std::string key;
    osk::texture::DecodedTexture texture;
};

float length3(const osk::bsp::Vec3& value) {
    return std::sqrt(value.x * value.x + value.y * value.y + value.z * value.z);
}

std::string lowerKey(std::string value) {
    for (char& c : value) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    return value;
}

float repeat01(float value) {
    if (!std::isfinite(value)) {
        return 0.0F;
    }
    const float wrapped = value - std::floor(value);
    return wrapped < 0.0F ? wrapped + 1.0F : wrapped;
}

osk::bsp::Vec3 rotateView(osk::bsp::Vec3 value, const ViewerCamera& camera) {
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

osk::texture::DecodedTexture makePlaceholderTexture() {
    osk::texture::DecodedTexture texture;
    texture.name = "__openstrike_missing_texture";
    texture.width = 64;
    texture.height = 64;
    texture.rgba.resize(static_cast<std::size_t>(texture.width) * texture.height * 4);

    for (std::uint32_t y = 0; y < texture.height; ++y) {
        for (std::uint32_t x = 0; x < texture.width; ++x) {
            const bool bright = ((x / 8U) + (y / 8U)) % 2U == 0U;
            const std::size_t offset = (static_cast<std::size_t>(y) * texture.width + x) * 4;
            texture.rgba[offset] = bright ? 220 : 40;
            texture.rgba[offset + 1] = bright ? 40 : 220;
            texture.rgba[offset + 2] = 220;
            texture.rgba[offset + 3] = 255;
        }
    }

    return texture;
}

const osk::bsp::BspTextureMetadata* textureMetadataForIndex(const osk::bsp::TextureInfo& info, std::int32_t textureIndex) {
    if (textureIndex < 0) {
        return nullptr;
    }

    const auto wanted = static_cast<std::size_t>(textureIndex);
    for (const osk::bsp::BspTextureMetadata& texture : info.entries) {
        if (texture.index == wanted) {
            return &texture;
        }
    }

    return nullptr;
}

std::vector<fs::path> resourceRootsFromConfig(
    const std::vector<fs::path>& extraRoots,
    bool loadDefaultConfigRoots,
    std::vector<std::string>& warnings) {
    std::vector<fs::path> roots;

    if (loadDefaultConfigRoots) {
        try {
            const fs::path configPath = osk::defaultConfigPath();
            if (fs::exists(configPath)) {
                const osk::EngineConfig config = osk::loadConfigFile(configPath);
                roots.insert(roots.end(), config.resources.roots.begin(), config.resources.roots.end());
            }
        } catch (const std::exception& e) {
            warnings.emplace_back(std::string("failed to read viewer config roots: ") + e.what());
        }
    }

    roots.insert(roots.end(), extraRoots.begin(), extraRoots.end());
    return roots;
}

TextureLibrary loadTextureLibrary(const std::vector<fs::path>& extraRoots, bool loadDefaultConfigRoots) {
    TextureLibrary library;
    const std::vector<fs::path> roots = resourceRootsFromConfig(extraRoots, loadDefaultConfigRoots, library.warnings);
    if (roots.empty()) {
        library.warnings.emplace_back("no texture resource roots configured; using generated checker placeholders");
        return library;
    }

    osk::VirtualFileSystem vfs;
    for (const fs::path& root : roots) {
        std::string error;
        if (!vfs.mountReadOnlyDirectory(root, root.string(), true, &error)) {
            library.warnings.emplace_back("failed to mount texture root '" + root.string() + "': " + error);
        }
    }

    const osk::ResourceIndex index = osk::buildResourceIndex(vfs);
    for (const osk::ResourceFile& wad : index.wads) {
        try {
            const std::vector<std::byte> bytes = osk::texture::loadTexturePackageBytes(wad.absolutePath);
            const osk::texture::TexturePackageSummary summary = osk::texture::parseTexturePackageSummary(bytes);
            ++library.packageCount;

            for (const osk::texture::TexturePackageEntry& entry : summary.entries) {
                if (!entry.mipMetadataAvailable) {
                    continue;
                }

                try {
                    osk::texture::DecodedTexture decoded = osk::texture::decodeIndexedMipTexture(bytes, entry);
                    const std::string key = lowerKey(decoded.name);
                    if (!key.empty() && library.textures.find(key) == library.textures.end()) {
                        library.textures.emplace(key, std::move(decoded));
                        ++library.decodedCount;
                    }
                } catch (const std::exception& e) {
                    library.warnings.emplace_back("skipped texture entry '" + entry.name + "' in " + wad.virtualPath + ": " + e.what());
                }
            }
        } catch (const std::exception& e) {
            library.warnings.emplace_back("skipped texture package '" + wad.virtualPath + "': " + e.what());
        }
    }

    if (library.decodedCount == 0) {
        library.warnings.emplace_back("no decodable textures found in configured read-only roots; using generated checker placeholders");
    }

    return library;
}

TextureAtlas buildTextureAtlas(
    const osk::bsp::BspSummary& summary,
    const osk::bsp::BspWorldMesh& mesh,
    const TextureLibrary& library) {
    constexpr std::uint32_t AtlasWidth = 2048;
    const std::string placeholderKey = "__placeholder__";

    TextureAtlas atlas;
    atlas.faceMaterials.resize(mesh.faces.size());

    std::vector<AtlasSource> sources;
    std::unordered_map<std::string, std::size_t> sourceIndex;

    auto addSource = [&](std::string key, osk::texture::DecodedTexture texture) {
        key = lowerKey(std::move(key));
        if (key.empty() || sourceIndex.find(key) != sourceIndex.end()) {
            return;
        }
        sourceIndex.emplace(key, sources.size());
        sources.push_back(AtlasSource{.key = key, .texture = std::move(texture)});
    };

    addSource(placeholderKey, makePlaceholderTexture());

    std::vector<std::string> faceKeys(mesh.faces.size(), placeholderKey);
    for (std::size_t i = 0; i < mesh.faces.size(); ++i) {
        const osk::bsp::BspMeshFaceRange& face = mesh.faces[i];
        const osk::bsp::BspTextureMetadata* metadata = textureMetadataForIndex(summary.textures, face.textureIndex);
        if (metadata == nullptr || metadata->name.empty()) {
            continue;
        }

        const std::string key = lowerKey(metadata->name);
        const auto found = library.textures.find(key);
        if (found == library.textures.end()) {
            continue;
        }

        faceKeys[i] = key;
        addSource(key, found->second);
    }

    struct Placement {
        std::uint32_t x = 0;
        std::uint32_t y = 0;
        std::uint32_t width = 0;
        std::uint32_t height = 0;
    };

    std::vector<Placement> placements(sources.size());
    std::uint32_t cursorX = 0;
    std::uint32_t cursorY = 0;
    std::uint32_t rowHeight = 0;
    std::uint32_t atlasHeight = 0;

    for (std::size_t i = 0; i < sources.size(); ++i) {
        const osk::texture::DecodedTexture& texture = sources[i].texture;
        if (texture.width == 0 || texture.height == 0 || texture.width > AtlasWidth) {
            atlas.warnings.emplace_back("texture '" + texture.name + "' is too large for the debug atlas; using placeholder where needed");
            continue;
        }

        if (cursorX > 0 && cursorX + texture.width > AtlasWidth) {
            cursorX = 0;
            cursorY += rowHeight;
            rowHeight = 0;
        }

        placements[i] = Placement{.x = cursorX, .y = cursorY, .width = texture.width, .height = texture.height};
        cursorX += texture.width;
        rowHeight = std::max(rowHeight, texture.height);
        atlasHeight = std::max(atlasHeight, cursorY + texture.height);
    }

    if (atlasHeight == 0) {
        atlasHeight = 1;
    }

    atlas.width = AtlasWidth;
    atlas.height = atlasHeight;
    atlas.pixels.assign(static_cast<std::size_t>(atlas.width) * atlas.height * 4, 0);

    std::unordered_map<std::string, AtlasRegion> regions;
    for (std::size_t i = 0; i < sources.size(); ++i) {
        const Placement& placement = placements[i];
        if (placement.width == 0 || placement.height == 0) {
            continue;
        }

        const osk::texture::DecodedTexture& texture = sources[i].texture;
        for (std::uint32_t y = 0; y < texture.height; ++y) {
            const std::size_t src = static_cast<std::size_t>(y) * texture.width * 4;
            const std::size_t dst = (static_cast<std::size_t>(placement.y + y) * atlas.width + placement.x) * 4;
            std::copy_n(texture.rgba.data() + src, static_cast<std::size_t>(texture.width) * 4, atlas.pixels.data() + dst);
        }

        regions.emplace(sources[i].key, AtlasRegion{
            .u0 = static_cast<float>(placement.x) / static_cast<float>(atlas.width),
            .v0 = static_cast<float>(placement.y) / static_cast<float>(atlas.height),
            .u1 = static_cast<float>(placement.x + placement.width) / static_cast<float>(atlas.width),
            .v1 = static_cast<float>(placement.y + placement.height) / static_cast<float>(atlas.height),
            .width = placement.width,
            .height = placement.height,
        });
    }

    const AtlasRegion placeholder = regions.at(placeholderKey);
    for (std::size_t i = 0; i < mesh.faces.size(); ++i) {
        const auto found = regions.find(faceKeys[i]);
        atlas.faceMaterials[i].region = found == regions.end() ? placeholder : found->second;
    }
    atlas.decodedTextureCount = sources.size() > 0 ? sources.size() - 1 : 0;
    return atlas;
}

vector_float2 atlasUv(const osk::bsp::Vec2& textureUv, const AtlasRegion& region) {
    const float localU = repeat01(textureUv.x / static_cast<float>(std::max<std::uint32_t>(region.width, 1)));
    const float localV = repeat01(textureUv.y / static_cast<float>(std::max<std::uint32_t>(region.height, 1)));
    return vector_float2{
        region.u0 + (region.u1 - region.u0) * localU,
        region.v0 + (region.v1 - region.v0) * localV,
    };
}

std::vector<ViewerVertex> buildViewerVertices(
    const osk::bsp::BspWorldMesh& mesh,
    const std::vector<FaceMaterial>& faceMaterials,
    const ViewerCamera& camera) {
    std::vector<ViewerVertex> vertices(mesh.vertices.size());

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

    const float viewScale = 0.9F * camera.zoom;

    for (std::size_t faceIndex = 0; faceIndex < mesh.faces.size(); ++faceIndex) {
        const osk::bsp::BspMeshFaceRange& face = mesh.faces[faceIndex];
        const AtlasRegion region = faceIndex < faceMaterials.size() ? faceMaterials[faceIndex].region : AtlasRegion{};
        for (std::uint32_t local = 0; local < face.vertexCount; ++local) {
            const std::size_t sourceIndex = static_cast<std::size_t>(face.vertexOffset) + local;
            if (sourceIndex >= mesh.vertices.size()) {
                continue;
            }

            const osk::bsp::BspMeshVertex& source = mesh.vertices[sourceIndex];
            const osk::bsp::Vec3 centered{
                .x = source.position.x - center.x,
                .y = source.position.y - center.y,
                .z = source.position.z - center.z,
            };
            const osk::bsp::Vec3 p = rotateView(centered, camera);
            const osk::bsp::Vec3 n = rotateView(source.normal, camera);

            const float z = std::clamp(p.z / (radius * 2.0F) + 0.5F, 0.0F, 1.0F);
            vertices[sourceIndex] = ViewerVertex{
                .position = vector_float3{p.x / radius * viewScale, p.y / radius * viewScale, z},
                .normal = vector_float3{n.x, n.y, n.z},
                .uv = atlasUv(source.textureUv, region),
            };
        }
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
    float2 uv;
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 uv;
};

vertex VertexOut vertex_main(
    const device VertexIn* vertices [[buffer(0)]],
    uint vertexId [[vertex_id]]) {
    VertexIn input = vertices[vertexId];

    VertexOut output;
    output.position = float4(input.position, 1.0);
    output.normal = normalize(input.normal);
    output.uv = input.uv;
    return output;
}

fragment float4 fragment_main(VertexOut input [[stage_in]], texture2d<float> atlas [[texture(0)]]) {
    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float4 texel = atlas.sample(textureSampler, input.uv);
    float shade = 0.50 + abs(normalize(input.normal).z) * 0.50;
    return float4(texel.rgb * shade, texel.a);
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
        << "  OpenStrikeBspView <path/to/map.bsp> [--resource-root <path>]...\n"
        << "\n"
        << "Controls:\n"
        << "  Left mouse drag / arrow keys  Rotate view\n"
        << "  Mouse wheel / + / -           Zoom view\n"
        << "  R                             Reset view\n"
        << "  Esc                           Exit\n"
        << "\n"
        << "The viewer loads texture packages from configured read-only user resource roots\n"
        << "and optional --resource-root paths. It decodes textures in memory only and\n"
        << "does not extract, convert, save, or cache user-provided assets.\n";
}

bool parseArgs(int argc, char** argv, ViewerArgs& args) {
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--help" || arg == "-h") {
            printUsage(std::cout);
            args.helpRequested = true;
            return false;
        }
        if (arg == "--resource-root") {
            if (i + 1 >= argc) {
                std::cerr << "OpenStrikeBspView error: --resource-root requires a path\n";
                return false;
            }
            args.resourceRoots.emplace_back(argv[++i]);
            continue;
        }
        if (!args.mapPath.empty()) {
            std::cerr << "OpenStrikeBspView error: unexpected argument: " << arg << '\n';
            return false;
        }
        args.mapPath = arg;
    }

    if (args.mapPath.empty()) {
        printUsage(std::cerr);
        return false;
    }
    return true;
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
    id<MTLTexture> _atlasTexture;
    NSUInteger _indexCount;
    const osk::bsp::BspWorldMesh* _mesh;
    const std::vector<FaceMaterial>* _faceMaterials;
    const TextureAtlas* _atlas;
    ViewerCamera _camera;
}
- (instancetype)initWithView:(MTKView*)view mesh:(const osk::bsp::BspWorldMesh&)mesh atlas:(const TextureAtlas&)atlas errorMessage:(std::string*)errorMessage;
- (void)rotateByDeltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY;
- (void)zoomByFactor:(float)factor;
- (void)resetView;
@end

@implementation OSKBspMetalRenderer

- (BOOL)rebuildVertexBufferWithErrorMessage:(std::string*)errorMessage {
    const std::vector<ViewerVertex> vertices = buildViewerVertices(*_mesh, *_faceMaterials, _camera);
    if (vertices.empty()) {
        if (errorMessage != nullptr) {
            *errorMessage = "BSP world mesh has no drawable vertices";
        }
        return NO;
    }

    id<MTLBuffer> newVertexBuffer = [_device newBufferWithBytes:vertices.data()
                                                         length:vertices.size() * sizeof(ViewerVertex)
                                                        options:MTLResourceStorageModeManaged];
    if (newVertexBuffer == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal vertex buffer";
        }
        return NO;
    }

    [_vertexBuffer release];
    _vertexBuffer = newVertexBuffer;
    return YES;
}

- (BOOL)createAtlasTextureWithErrorMessage:(std::string*)errorMessage {
    if (_atlas->pixels.empty()) {
        if (errorMessage != nullptr) {
            *errorMessage = "texture atlas has no pixels";
        }
        return NO;
    }

    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                          width:_atlas->width
                                                                                         height:_atlas->height
                                                                                      mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    _atlasTexture = [_device newTextureWithDescriptor:descriptor];
    if (_atlasTexture == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal texture atlas";
        }
        return NO;
    }

    const MTLRegion region = MTLRegionMake2D(0, 0, _atlas->width, _atlas->height);
    [_atlasTexture replaceRegion:region
                      mipmapLevel:0
                        withBytes:_atlas->pixels.data()
                      bytesPerRow:static_cast<NSUInteger>(_atlas->width) * 4U];
    return YES;
}

- (instancetype)initWithView:(MTKView*)view mesh:(const osk::bsp::BspWorldMesh&)mesh atlas:(const TextureAtlas&)atlas errorMessage:(std::string*)errorMessage {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _mesh = &mesh;
    _atlas = &atlas;
    _faceMaterials = &atlas.faceMaterials;
    _device = [view.device retain];
    _commandQueue = [_device newCommandQueue];
    if (_commandQueue == nil) {
        if (errorMessage != nullptr) {
            *errorMessage = "failed to create Metal command queue";
        }
        [self release];
        return nil;
    }

    if (mesh.vertices.empty() || mesh.indices.empty()) {
        if (errorMessage != nullptr) {
            *errorMessage = "BSP world mesh has no drawable geometry";
        }
        [self release];
        return nil;
    }

    if (![self createAtlasTextureWithErrorMessage:errorMessage]) {
        [self release];
        return nil;
    }

    if (![self rebuildVertexBufferWithErrorMessage:errorMessage]) {
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
    [_atlasTexture release];
    [_depthState release];
    [_pipelineState release];
    [_indexBuffer release];
    [_vertexBuffer release];
    [_commandQueue release];
    [_device release];
    [super dealloc];
}

- (void)rotateByDeltaX:(CGFloat)deltaX deltaY:(CGFloat)deltaY {
    _camera.yaw += static_cast<float>(deltaX) * 0.01F;
    _camera.pitch += static_cast<float>(deltaY) * 0.01F;
    _camera.pitch = std::clamp(_camera.pitch, -1.55F, 1.55F);
    (void)[self rebuildVertexBufferWithErrorMessage:nullptr];
}

- (void)zoomByFactor:(float)factor {
    _camera.zoom = std::clamp(_camera.zoom * factor, 0.10F, 10.0F);
    (void)[self rebuildVertexBufferWithErrorMessage:nullptr];
}

- (void)resetView {
    _camera = ViewerCamera{};
    (void)[self rebuildVertexBufferWithErrorMessage:nullptr];
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
    [encoder setFragmentTexture:_atlasTexture atIndex:0];
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

BOOL handleViewerEvent(NSEvent* event, OSKBspMetalRenderer* renderer, OSKBspViewDelegate* windowDelegate, NSWindow* window) {
    switch ([event type]) {
        case NSEventTypeKeyDown: {
            NSString* characters = [event charactersIgnoringModifiers];
            if ([characters length] == 0) {
                return NO;
            }

            const unichar key = [characters characterAtIndex:0];
            if (key == 27) {
                [windowDelegate setCloseRequested:YES];
                [window close];
                return YES;
            }

            switch (key) {
                case 'r':
                case 'R':
                    [renderer resetView];
                    return YES;
                case '+':
                case '=':
                    [renderer zoomByFactor:1.10F];
                    return YES;
                case '-':
                case '_':
                    [renderer zoomByFactor:0.90F];
                    return YES;
                case NSLeftArrowFunctionKey:
                    [renderer rotateByDeltaX:-12.0 deltaY:0.0];
                    return YES;
                case NSRightArrowFunctionKey:
                    [renderer rotateByDeltaX:12.0 deltaY:0.0];
                    return YES;
                case NSUpArrowFunctionKey:
                    [renderer rotateByDeltaX:0.0 deltaY:-12.0];
                    return YES;
                case NSDownArrowFunctionKey:
                    [renderer rotateByDeltaX:0.0 deltaY:12.0];
                    return YES;
                default:
                    return NO;
            }
        }
        case NSEventTypeLeftMouseDragged:
        case NSEventTypeRightMouseDragged:
        case NSEventTypeOtherMouseDragged:
            [renderer rotateByDeltaX:[event deltaX] deltaY:[event deltaY]];
            return YES;
        case NSEventTypeScrollWheel: {
            const float factor = std::exp(static_cast<float>([event scrollingDeltaY]) * 0.02F);
            [renderer zoomByFactor:factor];
            return YES;
        }
        default:
            return NO;
    }
}

namespace osk::debug {

int runBspView(const BspViewOptions& options) {
    if (options.mapPath.empty()) {
        std::cerr << options.logName << " error: missing map path\n";
        return 1;
    }

    try {
        const osk::bsp::BspSummary summary = osk::bsp::loadBspSummary(options.mapPath);
        const osk::bsp::BspWorldMesh mesh = osk::bsp::loadBspWorldMesh(options.mapPath);
        const TextureLibrary textureLibrary = loadTextureLibrary(options.resourceRoots, options.loadDefaultConfigRoots);
        const TextureAtlas atlas = buildTextureAtlas(summary, mesh, textureLibrary);

        @autoreleasepool {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();
            if (device == nil) {
                std::cerr << options.logName << " error: Metal is not available on this system\n";
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
                std::cerr << options.logName << " error: failed to create NSWindow\n";
                return 1;
            }

            NSString* title = [[NSString alloc] initWithFormat:@"%s - %s",
                options.windowTitlePrefix.c_str(),
                options.mapPath.filename().string().c_str()];
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
            OSKBspMetalRenderer* renderer = [[OSKBspMetalRenderer alloc] initWithView:view mesh:mesh atlas:atlas errorMessage:&rendererError];
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

            std::cout << options.logName << " running. Drag to rotate, scroll to zoom, press R to reset, Esc to exit.\n";
            std::cout << "Mesh: " << mesh.vertices.size() << " vertices, "
                << mesh.indices.size() << " indices, "
                << mesh.triangleCount() << " triangles\n";
            std::cout << "Textures: " << textureLibrary.decodedCount << " decoded from "
                << textureLibrary.packageCount << " packages; atlas "
                << atlas.width << "x" << atlas.height << "\n";
            for (const std::string& warning : textureLibrary.warnings) {
                std::cout << "Texture warning: " << warning << '\n';
            }
            for (const std::string& warning : atlas.warnings) {
                std::cout << "Texture warning: " << warning << '\n';
            }

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

                        if (handleViewerEvent(event, renderer, windowDelegate, window)) {
                            continue;
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
        std::cerr << options.logName << " error: " << e.what() << '\n';
        return 1;
    }
}

int runBspViewCli(int argc, char** argv) {
    ViewerArgs args;
    if (!parseArgs(argc, argv, args)) {
        return args.helpRequested ? 0 : 1;
    }

    return runBspView(BspViewOptions{
        .mapPath = args.mapPath,
        .resourceRoots = args.resourceRoots,
    });
}

} // namespace osk::debug
