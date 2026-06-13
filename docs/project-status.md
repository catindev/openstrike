# Project Status

Last updated: 2026-06-13.

## Current milestone

OpenStrike has reached the first textured map-inspection milestone on macOS and has automated coverage for the config/VFS bootstrap, synthetic texture package decoding, synthetic model metadata parsing, synthetic sprite metadata parsing, synthetic BSP light metadata parsing, synthetic BSP collision trace parsing, and synthetic fixed-tick player movement with crouch basics.

The project can:

- build with CMake on macOS arm64;
- create a macOS app bundle;
- read a config file from the user application support directory;
- mount configured resource roots read-only;
- index compatible local file types;
- run automated tests for config parsing, template generation, VFS mounting, resource indexing, texture package metadata parsing, indexed texture decoding, model metadata parsing, sprite metadata parsing, BSP light metadata parsing, BSP collision point tracing, and trace-backed player movement including crouch hull selection;
- inspect map headers and lump metadata;
- validate map geometry references;
- build a triangulated world mesh;
- inspect legacy texture package headers, directory entries, and safe mip metadata;
- decode indexed mip textures into memory-only RGBA buffers;
- inspect legacy model headers, body part tables, sequence descriptors, texture metadata, and hitboxes;
- inspect legacy sprite headers, palette metadata, single frames, and grouped frame metadata;
- inspect BSP per-face light offsets, styles, estimated lightmap sizes, sample counts, and light data ranges;
- load BSP collision planes, clipnodes, and model hull metadata;
- run a minimal point trace through BSP clipnodes with fraction, plane, normal, and solid flags;
- simulate a minimal fixed-tick player state with gravity, walking, jumping, crouch state, and stand/crouch hull selection against trace-backed collision;
- print synthetic player movement debug ticks without reading user assets;
- show and navigate textured map geometry in a native Metal debug viewer with generated placeholders for missing textures.

## Completed GitHub issues

- #1 - first macOS window lifecycle, completed by PR #4 and expanded by PR #9.
- #2 - map header and lump dump tool, completed by PR #6, PR #7, PR #8, and PR #9.
- #10 - documentation and handoff rules, completed by PR #21.
- #3 - config and VFS automated tests, completed by PR #22.
- #11 - debug viewer navigation, completed by PR #25.
- #12 - texture package metadata reader, completed by PR #33.
- #13 - textured map viewer pass, completed by PR #34.
- #14 - map light data inspection, completed by PR #35.
- #15 - map collision trace prototype, completed by PR #36.
- #16 - player movement sandbox prototype, completed by PR #40.
- #17 - model metadata inspection tool, completed by PR #41.
- #18 - sprite metadata inspection tool, completed by PR #42.

## Open GitHub issues

- #19 - WAV playback prototype.
- #20 - local sandbox app mode.

## Implemented components

```text
apps/client/                  bootstrap client app
engine/config/                config path, template, and parser
engine/assets/                read-only VFS and resource index
engine/assets/loaders/        map summaries, map mesh builders, light metadata, collision trace, texture metadata/decode helpers, model metadata parsing, and sprite metadata parsing
engine/physics/               fixed-tick trace-backed player movement prototype
engine/platform/              native macOS window abstraction and headless fallback
tests/                        config, VFS, texture, model, sprite, BSP light, BSP collision, and player movement regression tests
tools/asset_audit/            repository asset guardrail
tools/bspdump/                map, geometry, mesh, and light metadata CLI
tools/playermove/             synthetic fixed-tick player movement debug CLI
tools/bsptrace/               point collision trace CLI
tools/bspview/                macOS Metal textured debug viewer
tools/modeldump/              model metadata CLI
tools/spritedump/             sprite metadata CLI
tools/texturepkgdump/         texture package metadata CLI
```

## Current limitations

- No lightmap decoding or lightmapped rendering yet.
- No full player physics, step movement, swept player volumes, or movement tuning profiles yet.
- No model rendering, sprite rendering, or audio playback yet.
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

Point collision trace:

```bash
./build/macos-arm64-debug/tools/bsptrace/OpenStrikeBspTrace /absolute/path/to/local/map.bsp --start <x> <y> <z> --end <x> <y> <z>
```

Player movement debug simulation:

```bash
./build/macos-arm64-debug/tools/playermove/OpenStrikePlayerMove --ticks 8 --forward 1 --jump-tick 2 --crouch-from 4
```

Texture package metadata dump:

```bash
./build/macos-arm64-debug/tools/texturepkgdump/OpenStrikeTexturePkgDump /absolute/path/to/local/package.wad
```

Model metadata dump:

```bash
./build/macos-arm64-debug/tools/modeldump/OpenStrikeModelDump /absolute/path/to/local/model.mdl
```

Sprite metadata dump:

```bash
./build/macos-arm64-debug/tools/spritedump/OpenStrikeSpriteDump /absolute/path/to/local/sprite.spr
```

Textured map viewer:

```bash
./build/macos-arm64-debug/tools/bspview/OpenStrikeBspView.app/Contents/MacOS/OpenStrikeBspView /absolute/path/to/local/map.bsp --resource-root /absolute/path/to/local/files
```

Controls:

- Left mouse drag or arrow keys rotate/orbit the view.
- Mouse wheel or `+` / `-` zooms the view.
- `R` resets the view.
- `Esc` closes the viewer.

Do not commit local files used for manual validation.
