# Project Status

Last updated: 2026-06-13.

## Current milestone

OpenStrike has reached the first visual map-inspection milestone on macOS and now has automated coverage for the config/VFS bootstrap.

The project can:

- build with CMake on macOS arm64;
- create a macOS app bundle;
- read a config file from the user application support directory;
- mount configured resource roots read-only;
- index compatible local file types;
- run automated tests for config parsing, template generation, VFS mounting, resource indexing, and texture package metadata parsing;
- inspect map headers and lump metadata;
- validate map geometry references;
- build a triangulated world mesh;
- show and navigate that mesh in a native Metal debug wireframe viewer;
- inspect legacy texture package headers, directory entries, and safe mip metadata.

## Completed GitHub issues

- #1 - first macOS window lifecycle, completed by PR #4 and expanded by PR #9.
- #2 - map header and lump dump tool, completed by PR #6, PR #7, PR #8, and PR #9.
- #10 - documentation and handoff rules, completed by PR #21.
- #3 - config and VFS automated tests, completed by PR #22.
- #11 - debug viewer navigation, completed by PR #25.
- #12 - texture package metadata reader, completed by PR #33.

## Open GitHub issues

- #13 - textured map viewer pass.
- #14 - map light data inspection.
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
engine/assets/loaders/        map summaries, map mesh builders, and texture package metadata readers
engine/platform/              native macOS window abstraction and headless fallback
tests/                        config, VFS, and texture package metadata regression tests
tools/asset_audit/            repository asset guardrail
tools/bspdump/                map metadata CLI
tools/bspview/                macOS Metal wireframe debug viewer
tools/texturepkgdump/         texture package metadata CLI
```

## Current limitations

- No texture pixel decoding or renderer upload path yet.
- No textured map rendering yet.
- No light data visualization yet.
- No collision tracing yet.
- No player movement yet.
- No model, sprite, or audio decoding yet.
- No final renderer abstraction yet; current viewer is a native Metal debug tool.

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

Map dump:

```bash
./build/macos-arm64-debug/tools/bspdump/OpenStrikeBspDump /absolute/path/to/local/map.bsp
```

Texture package metadata dump:

```bash
./build/macos-arm64-debug/tools/texturepkgdump/OpenStrikeTexturePkgDump /absolute/path/to/local/package.wad
```

Map wireframe viewer:

```bash
./build/macos-arm64-debug/tools/bspview/OpenStrikeBspView.app/Contents/MacOS/OpenStrikeBspView /absolute/path/to/local/map.bsp
```

Controls:

- Left mouse drag or arrow keys rotate/orbit the view.
- Mouse wheel or `+` / `-` zooms the view.
- `R` resets the view.
- `Esc` closes the viewer.

Do not commit local files used for manual validation.
