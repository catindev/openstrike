# OpenStrike Architecture

OpenStrike is structured as a modular clean-room engine/client. The current focus is macOS-first resource inspection and map visualization.

## Current modules

```text
apps/client/                  bootstrap executable and future game client
engine/core/                  logging and low-level utilities
engine/config/                config path resolution, config template, minimal parser
engine/assets/                read-only VFS and resource indexing
engine/assets/loaders/        map summary, geometry summary, mesh builders, and texture package metadata readers
engine/platform/              native macOS window abstraction and headless fallback
tools/asset_audit/            repository guardrail against proprietary asset commits
tools/bspdump/                map metadata CLI
tools/bspview/                macOS Metal wireframe debug viewer
tools/texturepkgdump/         texture package metadata CLI
```

## Current data flow

```text
config.toml
  -> resource roots
  -> read-only VirtualFileSystem
  -> ResourceIndex
  -> local map path
  -> BspSummary
  -> BspGeometrySummary
  -> BspWorldMesh
  -> OpenStrikeBspDump / OpenStrikeBspView

local texture package path
  -> TexturePackageSummary
  -> OpenStrikeTexturePkgDump
```

## Resource model

The engine reads only from configured local resource roots. These roots are mounted read-only. The repository does not contain proprietary resources and the engine must not write into configured user directories.

Initial resource discovery indexes the following extensions:

- `.bsp` maps;
- `.wad` texture packages;
- `.mdl` models;
- `.spr` sprites;
- `.wav` sounds.

Overlapping roots are supported. The VFS deduplicates identical physical files while preserving mount-order precedence.

## Map loader status

Implemented:

- BSP v30 header and 15-lump table validation;
- lump range and element-size validation;
- entity block count summary;
- embedded texture metadata summary;
- face, surfedge, edge, and vertex geometry validation;
- triangulated world mesh generation;
- native Metal wireframe visualization.

Not implemented yet:

- normalized texture UVs using texture dimensions;
- light data atlas construction;
- visibility set traversal;
- collision tracing;
- entity adaptation into gameplay objects.

## Texture package loader status

Implemented:

- WAD2/WAD3-style header validation;
- directory range and entry metadata validation;
- safe texture name, width, height, and mip-offset metadata inspection;
- read-only metadata dump CLI;
- synthetic parser tests without proprietary fixtures.

Not implemented yet:

- texture pixel decoding;
- texture extraction or conversion;
- renderer upload path;
- integration with textured map rendering.

## Near-term modules

```text
engine/input/           keyboard, mouse, action maps
engine/renderer/        future renderer abstraction beyond debug tools
engine/world/           map/world representation and entity adapter
engine/physics/         collision, traces, player movement
engine/game/            local game rules, weapons, damage, rounds
engine/audio/           audio backend, mixer, emitters
engine/ui/              original debug/runtime UI
engine/bots/            waypoint and local AI systems
engine/net/             local transport first, custom multiplayer later
```

## Compatibility boundary

OpenStrike provides format compatibility for user-provided files. It does not load proprietary game logic binaries, connect to official servers, implement official network protocols, or bypass DRM or anti-cheat systems.

## Renderer note

The current Metal viewer is a debug tool. It exists to validate mesh extraction visually. It should not be treated as the final engine renderer without an ADR that promotes or replaces it.
