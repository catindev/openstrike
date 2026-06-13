# OpenStrike Architecture

OpenStrike is structured as a modular clean-room engine/client. The current focus is macOS-first resource inspection and map visualization.

## Current modules

```text
apps/client/                  bootstrap executable and future game client
engine/core/                  logging and low-level utilities
engine/config/                config path resolution, config template, minimal parser
engine/assets/                read-only VFS and resource indexing
engine/assets/loaders/        map summaries, mesh builders, light metadata, texture metadata, and texture decode helpers
engine/platform/              native macOS window abstraction and headless fallback
tools/asset_audit/            repository guardrail against proprietary asset commits
tools/bspdump/                map, geometry, mesh, and light metadata CLI
tools/bspview/                macOS Metal textured debug viewer
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
  -> BspLightSummary
  -> OpenStrikeBspDump / OpenStrikeBspView

configured texture package roots
  -> read-only VirtualFileSystem
  -> ResourceIndex.wads
  -> TexturePackageSummary
  -> memory-only decoded texture RGBA
  -> generated debug atlas
  -> OpenStrikeBspView textured pass

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
- embedded texture metadata summary with texture names and dimensions;
- face, surfedge, edge, and vertex geometry validation;
- triangulated world mesh generation;
- per-face light offset, style, estimated lightmap dimension, sample count, and lighting range inspection;
- native Metal textured debug visualization.

Not implemented yet:

- light data atlas construction;
- lightmapped rendering;
- visibility set traversal;
- collision tracing;
- entity adaptation into gameplay objects.

## Light data inspection status

Implemented:

- read-only BSP lighting lump range accounting;
- face style and light offset inspection;
- estimated per-face lightmap width and height from face vertices and texinfo axes;
- sample count and byte-range validation for RGB light samples;
- missing, empty, malformed, or truncated lighting data reporting without crashes;
- synthetic BSP-like tests without proprietary fixtures.

Not implemented by design in this milestone:

- lightmap pixel decoding beyond metadata/range accounting;
- lightmap rendering or texture atlas composition;
- collision, movement, model, sprite, or audio integration.

## Texture package loader status

Implemented:

- WAD2/WAD3-style header validation;
- directory range and entry metadata validation;
- safe texture name, width, height, and mip-offset metadata inspection;
- indexed mip texture decode into memory-only RGBA buffers;
- read-only metadata dump CLI;
- synthetic parser and decode tests without proprietary fixtures.

Not implemented by design in the current milestone:

- texture extraction, conversion, saving, or caching;
- proprietary fixture loading;
- lightmap composition.

## Debug viewer texture pass

`OpenStrikeBspView` uses `BspWorldMesh` face texture indices to look up BSP texture names, then resolves those names against decoded textures loaded from configured read-only user resource roots. Missing or unsupported textures use a generated checker placeholder. The viewer builds a transient in-memory texture atlas for Metal and does not write decoded texture data to disk.

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

The current Metal viewer is a debug tool. It exists to validate mesh extraction and texture lookup visually. It should not be treated as the final engine renderer without an ADR that promotes or replaces it.
