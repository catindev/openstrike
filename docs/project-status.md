# Project Status

Last updated: 2026-06-13.

## Current milestone

OpenStrike has reached the first textured map-inspection milestone on macOS and has automated coverage for the config/VFS bootstrap, synthetic texture package decoding, and synthetic BSP light metadata parsing.

The project can:

- build with CMake on macOS arm64;
- create a macOS app bundle;
- read a config file from the user application support directory;
- mount configured resource roots read-only;
- index compatible local file types;
- run automated tests for config parsing, template generation, VFS mounting, resource indexing, texture package metadata parsing, indexed texture decoding, and BSP light metadata parsing;
- inspect map headers and lump metadata;
- validate map geometry references;
- build a triangulated world mesh;
- inspect legacy texture package headers, directory entries, and safe mip metadata;
- decode indexed mip textures into memory-only RGBA buffers;
- inspect BSP per-face light offsets, styles, estimated lightmap sizes, sample counts, and light data ranges;
- show and navigate textured map geometry in a native Metal debug viewer with generated placeholders for missing textures.

## Completed GitHub issues

- #1 - first macOS window lifecycle, completed by PR #4 and expanded by PR #9.
- #2 - map header and lump dump tool, completed by PR #6, PR #7, PR #8, and PR #9.
- #10 - documentation and handoff rules, completed by PR #21.
- #3 - config and VFS automated tests, completed by PR #22.
- #11 - debug viewer navigation, completed by PR #25.
- #12 - texture package metadata reader, completed by PR #33.
- #13 - textured map viewer pass, completed by PR #34.
- #14 - map light data inspection, completed by this PR.

## Open GitHub issues

- #15 - map collision trace prototype.
- #16 - player movement sandbox prototype.
- #17 - model metadata inspection tool.
- #18 - sprite metadata inspection tool.
- #19 - WAV playback prototype.
- #20 - local sandbox app mode.

## Implemented components

```text
apps/client/                  bootstrap client app
engine/config/                config path, template, and parser
engine/assets/                read-only VFS and resource index
engine/assets/loaders/        map summaries, map mesh builders, light metadata, texture metadata, and texture decode helpers
engine/platform/              native macOS window abstraction and headless fallback
tests/                        config, VFS, texture, and BSP light metadata regression tests
tools/asset_audit/            repository asset guardrail
tools/bspdump/                map, geometry, mesh, and light metadata CLI
tools/bspview/                macOS Metal textured debug viewer
tools/texturepkgdump/         texture package metadata CLI
```

## Current limitations

- No lightmap decoding or lightmapped rendering yet.
- No collision tracing yet.
- No player movement yet.
- No model, sprite, or audio decoding yet.
- No final renderer abstraction yet; current viewer is a native Metal debug tool.
- No decoded texture cache or asset extraction path by design.

## Manual validation commands

Build:

```bash
cmake --preset macos-arm64-debug
cmake --build build/macos-arm64-debug
```

Test:

```bash
ctest --test-dir build/macos-arm64-debug --output-on-failure
```

Config validation:

```bash
./build/macos-arm64-debug/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike --validate-config
```

Map and light metadata dump:

```bash
./build/macos-arm64-debug/tools/bspdump/OpenStrikeBspDump /absolute/path/to/local/map.bsp
```

Texture package metadata dump:

```bash
./build/macos-arm64-debug/tools/texturepkgdump/OpenStrikeTexturePkgDump /absolute/path/to/local/package.wad
```

Textured map viewer:

```bash
./build/macos-arm64-debug/tools/bspview/OpenStrikeBspView.app/Contents/MacOS/OpenStrikeBspView /absolute/path/to/local/map.bsp --resource-root /absolute/path/to/user/owned/files
```

Controls:

- Left mouse drag or arrow keys rotate/orbit the view.
- Mouse wheel or `+` / `-` zooms the view.
- `R` resets the view.
- `Esc` closes the viewer.

Do not commit local files used for manual validation.
