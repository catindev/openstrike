# Project Status

Last updated: 2026-06-12.

## Current milestone

OpenStrike has reached the first visual map-inspection milestone on macOS and now has automated coverage for the config/VFS bootstrap.

The project can:

- build with CMake on macOS arm64;
- create a macOS app bundle;
- read a config file from the user application support directory;
- mount configured resource roots read-only;
- index compatible local file types;
- run automated tests for config parsing, template generation, VFS mounting, and indexing;
- inspect map headers and lump metadata;
- validate map geometry references;
- build a triangulated world mesh;
- show that mesh in a native Metal debug wireframe viewer.

## Completed GitHub issues

- #1 - first macOS window lifecycle, completed by PR #4 and expanded by PR #9.
- #2 - map header and lump dump tool, completed by PR #6, PR #7, PR #8, and PR #9.
- #10 - documentation and handoff rules, completed by PR #21.
- #3 - config and VFS automated tests, pending current PR.

## Open GitHub issues

- #11 - debug viewer navigation.
- #12 - texture package metadata reader.
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
engine/assets/loaders/        map summary, geometry, and mesh builders
engine/platform/              native macOS window abstraction and headless fallback
tests/                        config and VFS regression tests
tools/asset_audit/            repository asset guardrail
tools/bspdump/                map metadata CLI
tools/bspview/                macOS Metal wireframe debug viewer
```

## Current limitations

- No interactive viewer navigation yet.
- No texture package loader beyond map-embedded texture metadata.
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

Map wireframe viewer:

```bash
./build/macos-arm64-debug/tools/bspview/OpenStrikeBspView.app/Contents/MacOS/OpenStrikeBspView /absolute/path/to/local/map.bsp
```

Do not commit local files used for manual validation.
