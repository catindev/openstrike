# Project Status

Last updated: 2026-06-13.

## Current milestone

OpenStrike has reached the first textured map-inspection milestone on macOS and now includes a separate playable sandbox runtime shell foundation. Automated coverage exists for the config/VFS bootstrap, synthetic texture package decoding, synthetic model metadata parsing, synthetic sprite metadata parsing, synthetic WAV metadata parsing, synthetic BSP light metadata parsing, synthetic BSP collision trace parsing, synthetic fixed-tick player movement with crouch basics, and synthetic input-to-command mapping.

The project can:

- build with CMake on macOS arm64;
- create a macOS app bundle;
- read a config file from the user application support directory;
- mount configured resource roots read-only;
- index compatible local file types;
- run automated tests for config parsing, template generation, VFS mounting, resource indexing, texture package metadata parsing, indexed texture decoding, model metadata parsing, sprite metadata parsing, WAV metadata parsing, BSP light metadata parsing, BSP collision point tracing, trace-backed player movement including crouch hull selection, and playable input-to-command mapping;
- inspect map headers and lump metadata;
- validate map geometry references;
- build a triangulated world mesh;
- inspect legacy texture package headers, directory entries, and safe mip metadata;
- decode indexed mip textures into memory-only RGBA buffers;
- inspect legacy model headers, body part tables, sequence descriptors, texture metadata, and hitboxes;
- inspect legacy sprite headers, palette metadata, single frames, and grouped frame metadata;
- validate simple PCM WAV metadata and play local WAV files on macOS through a prototype CLI;
- inspect BSP per-face light offsets, styles, estimated lightmap sizes, sample counts, and light data ranges;
- load BSP collision planes, clipnodes, and model hull metadata;
- run a minimal point trace through BSP clipnodes with fraction, plane, normal, and solid flags;
- simulate a minimal fixed-tick player state with gravity, walking, jumping, crouch state, and stand/crouch hull selection against trace-backed collision;
- print synthetic player movement debug ticks without reading user assets;
- launch a technical map window from the main app on macOS using the current BSP debug renderer path;
- launch a separate playable sandbox runtime shell with sampled input, fixed-tick `PlayerCommand` generation, debug command output, and clean exit;
- show and navigate textured map geometry in a native Metal debug viewer with generated placeholders for missing textures;
- open a minimal first-person view of a BSP map from a user-specified spawn position using `--playable-map` together with `--spawn`.

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
- #19 - WAV playback prototype, completed by PR #43.
- #20 - local sandbox app mode technical map-window integration, completed by PR #44.
- #45 - playable sandbox runtime shell and input command pipeline, completed by PR #54.
- #46 - first-person BSP render mode for playable sandbox, completed by this PR.

## Open GitHub issues

There are no active near-term issues at the time of this milestone. Future work will build on the first-person playable path with collision-backed movement, renderer abstraction, and gameplay features. See the roadmap for suggested next tasks.

## Implemented components

```
apps/client/                  bootstrap client app, technical map-window launcher, and playable sandbox launcher
engine/config/                config path, template, and parser
engine/assets/                read-only VFS and resource index
engine/assets/loaders/        map summaries, map mesh builders, light metadata, collision trace, texture metadata/decode helpers, model metadata parsing, sprite metadata parsing, and WAV metadata parsing
engine/input/                 input state and fixed-tick player command mapping
engine/game/                  local playable sandbox runtime shell
engine/physics/               fixed-tick trace-backed player movement prototype
engine/platform/              native macOS window abstraction, input sampling, and headless fallback
tests/                        config, VFS, texture, model, sprite, WAV, BSP light, BSP collision, player movement, and input mapping regression tests
tools/asset_audit/            repository asset guardrail
tools/bspdump/                map, geometry, mesh, and light metadata CLI
tools/playermove/             synthetic fixed-tick player movement debug CLI
tools/bsptrace/               point collision trace CLI
tools/bspview/                macOS Metal textured debug viewer
tools/modeldump/              model metadata CLI
tools/spritedump/             sprite metadata CLI
tools/texturepkgdump/         texture package metadata CLI
tools/wavplay/                WAV metadata and macOS playback prototype CLI
```

## Current limitations

- No lightmap decoding or lightmapped rendering yet.
- No full player physics, step movement, swept player volumes, or movement tuning profiles yet.
- No production audio system, mixer, streaming, emitters, or cross-platform playback backend yet.
- No final renderer abstraction yet; current viewer is a native Metal debug tool.
- The current `--sandbox-map` path reuses the debug BSP renderer and remains a technical map-window mode.
- The `--playable-map` path still does not implement collision-backed movement or full player physics. Without `--spawn` it runs as a runtime/input shell; with `--spawn` it renders the map from the given position using a minimal first-person shader but does not allow movement.
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

Technical map-window integration:

```bash
./build/macos-arm64-debug/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike --sandbox-map /absolute/path/to/local/map.bsp
```

Playable sandbox runtime shell (no render, debug commands):

```bash
./build/macos-arm64-debug/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike \
  --playable-map /absolute/path/to/local/map.bsp \
  --resource-root /absolute/path/to/local/files \
  --debug-input
```

First-person BSP render mode:

```bash
./build/macos-arm64-debug/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike \
  --playable-map /absolute/path/to/local/map.bsp \
  --spawn 0 0 64 \
  --resource-root /absolute/path/to/local/files
```

With a temporary read-only resource root for technical map-window mode:

```bash
./build/macos-arm64-debug/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike \
  --sandbox-map /absolute/path/to/local/map.bsp \
  --resource-root /absolute/path/to/local/files
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

WAV playback prototype:

```bash
./build/macos-arm64-debug/tools/wavplay/OpenStrikeWavPlay --dry-run /absolute/path/to/local/audio.wav
./build/macos-arm64-debug/tools/wavplay/OpenStrikeWavPlay /absolute/path/to/local/audio.wav
```

Textured map viewer:

```bash
./build/macos-arm64-debug/tools/bspview/OpenStrikeBspView.app/Contents/MacOS/OpenStrikeBspView /absolute/path/to/local/map.bsp --resource-root /absolute/path/to/local/files
```

Controls:

- `--playable-map`: `W`/`S` forward/back, `A`/`D` left/right, `Space` jump, `C` crouch, mouse movement look deltas, `Esc` exit. When used with `--spawn`, movement is not implemented yet and the view is fixed; `Esc` closes the window.
- OpenStrikeBspView: left mouse drag or arrow keys rotate/orbit the view, mouse wheel or `+` / `-` zooms the view, `R` resets the view, and `Esc` closes the viewer.

Do not commit local files used for manual validation.
