# OpenStrike Architecture

OpenStrike is structured as a modular clean-room engine/client. The current focus is macOS-first resource inspection and map visualization.

## Current modules

```text
apps/client/                  bootstrap executable and future game client
engine/core/                  logging and low-level utilities
engine/config/                config path resolution, config template, minimal parser
engine/assets/                read-only VFS and resource indexing
engine/assets/loaders/        map summaries, mesh builders, light metadata, collision trace, texture metadata/decode helpers, model metadata parsing, and sprite metadata parsing
engine/physics/               fixed-tick trace-backed player movement prototype
engine/platform/              native macOS window abstraction and headless fallback
tools/asset_audit/            repository guardrail against proprietary asset commits
tools/bspdump/                map, geometry, mesh, and light metadata CLI
tools/playermove/             synthetic fixed-tick player movement debug CLI
tools/bsptrace/               point collision trace CLI
tools/bspview/                macOS Metal textured debug viewer
tools/modeldump/              model metadata CLI
tools/spritedump/             sprite metadata CLI
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
  -> BspCollisionData
  -> OpenStrikeBspDump / OpenStrikeBspTrace / OpenStrikeBspView

BspCollisionData
  -> tracePoint()
  -> PlayerMovementState fixed-tick update
  -> OpenStrikePlayerMove synthetic debug ticks

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

local model path
  -> ModelMetadataSummary
  -> OpenStrikeModelDump

local sprite path
  -> SpriteMetadataSummary
  -> OpenStrikeSpriteDump
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
- collision plane, clipnode, and model hull metadata loading;
- minimal point trace over BSP clipnodes with hit fraction, hit normal, and solid flags;
- trace-backed fixed-tick player movement state update for gravity, walking, jumping, and crouch hull selection;
- native Metal textured debug visualization.

Not implemented yet:

- light data atlas construction;
- lightmapped rendering;
- visibility set traversal;
- full player movement sandbox, swept player volumes, step movement, and player height/eye offset transitions;
- entity adaptation into gameplay objects.

## Collision trace status

Implemented:

- read-only BSP plane, clipnode, and model headnode loading;
- minimal point segment trace through one model/hull;
- hit fraction, hit plane index, hit normal, start-solid, and all-solid reporting;
- CLI trace tool for local user-provided maps;
- synthetic clipnode tests without proprietary fixtures.

Not implemented by design in this milestone:

- swept player volumes, step movement, or full physics;
- multiplayer or gameplay movement integration.

## Player movement prototype status

Implemented:

- `PlayerMovementState` with position, velocity, and grounded flag;
- fixed-tick `stepPlayerMovement()` update;
- clamped X/Y walking velocity;
- gravity integration;
- single-tick jump impulse from grounded state;
- crouch state with configurable stand/crouch hull indices;
- blocked-uncrouch reporting when the stand hull starts solid;
- collision integration through `tracePoint()` against `BspCollisionData`;
- synthetic movement debug output through `OpenStrikePlayerMove`;
- synthetic ground-plane tests for walking, falling/landing, jumping, crouch hull selection, blocked uncrouch, grounded gravity stability, and missing trace context warnings.

Not implemented by design in this step:

- full gameplay loop;
- weapon logic;
- step climbing;
- swept hull movement;
- friction, acceleration, air control, or game-specific movement tuning;
- player height, eye offset, and smooth crouch transitions;
- map entity adaptation into spawn points or gameplay objects.

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

## Model metadata loader status

Implemented:

- legacy model header magic/version/name/length validation;
- safe table range validation for body parts, sequences, textures, and hitboxes;
- body part name, model count, base, and model offset inspection;
- sequence label, fps, frame count, activity, event count, bounding box, and sequence group metadata inspection;
- texture name, dimensions, flags, and data-offset metadata inspection without pixel decoding;
- hitbox bone, group, and bounds metadata inspection;
- read-only metadata dump CLI;
- synthetic parser tests without proprietary fixtures.

Not implemented by design in the current milestone:

- mesh, bone, animation, or texture extraction;
- model rendering;
- proprietary fixture loading;
- writes, caches, or generated files next to user resources.

## Sprite metadata loader status

Implemented:

- legacy sprite header magic/version/type/texture-format validation;
- palette color-count and RGB table range validation;
- single-frame metadata inspection with origin, dimensions, pixel data offset, and pixel byte count;
- grouped-frame metadata inspection with subframe count and intervals;
- read-only metadata dump CLI;
- synthetic parser tests without proprietary fixtures.

Not implemented by design in the current milestone:

- sprite pixel decoding;
- frame extraction, conversion, saving, or caching;
- sprite rendering;
- proprietary fixture loading;
- writes or generated files next to user resources.

## Debug viewer texture pass

`OpenStrikeBspView` uses `BspWorldMesh` face texture indices to look up BSP texture names, then resolves those names against decoded textures loaded from configured read-only user resource roots. Missing or unsupported textures use a generated checker placeholder. The viewer builds a transient in-memory texture atlas for Metal and does not write decoded texture data to disk.

## Near-term modules

```text
engine/input/           keyboard, mouse, action maps
engine/renderer/        future renderer abstraction beyond debug tools
engine/world/           map/world representation and entity adapter
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
