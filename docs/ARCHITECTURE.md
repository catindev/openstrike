# Architecture Overview

OpenStrike is organised into clear layers to promote separation of concerns and testability.  This document describes the intended structure of the codebase and the responsibilities of each layer.

## Directory structure

```
src/core/            # independent engine components and utilities
src/game/            # game rules and authoritative simulation
src/presentation/    # UI, HUD, viewmodel and other visual/audio presentation
src/dev/             # development‑time diagnostics, sandboxes and telemetry

data/                # configuration files, cvars and manifests
addons/              # Godot addons or GDExtensions

scenes/app/Main.tscn # entry point scene for the application
```

## Layer responsibilities

### `src/core/`

This layer contains reusable engine‑level functionality that does not depend on *Counter‑Strike* rules or assets.  Examples include logging, configuration management, mathematics, virtual file system abstractions and asset management.  Code in `core` should be portable and testable in isolation.

Map runtime contracts also live in `core`. `OpenStrikeTraceBackend` defines the
query boundary for `trace_ray`, `trace_hull`, `point_contents` and capability
reporting; `OpenStrikeGodotSceneTraceBackend` is only the current walkable-lab
bridge to imported Godot scene collision and is not GoldSrc hull/clipnode
parity. `src/core/bsp` owns the first BSP30 typed collision slice: synthetic
header/lump parsing for planes, clipnodes and GoldSrc 64-byte models, plus a
limited `OpenStrikeBspClipnodeTraceBackend` for synthetic model-0 hull traces.
That backend is not yet a real-map gameplay collision authority.
`OpenStrikeMapEntityIndex` owns imported BSP entity classification such as
spawns, buyzones, bomb targets, illusionary brushes and trigger-like volumes,
so dev labs and future game systems do not duplicate entity-policy lists.

### `src/game/`

The game layer implements the actual game rules and authoritative simulation.  This includes movement mechanics, physics constants, weapon logic, economy, round rules and team management.  It should not depend on any particular source of assets; instead it consumes abstracted data via the asset manager or configuration.

Even single‑player or offline modes should go through a server‑authoritative simulation to ensure correctness and consistency with potential multiplayer modes.

The first local runtime path is `OpenStrikeLocalGameSession`. It is a pure
game-layer service that owns fixed ticks, player slots, user command acceptance,
round-state skeleton data, spawn assignment and snapshots. It may consume
sanitized map/entity facts such as `OpenStrikeMapEntityIndex`, but it must not
load maps, GoldSrc assets, presentation nodes or dev-lab scripts directly.

### `src/presentation/`

Presentation code handles everything related to displaying the game state to the player: UI, HUD, viewmodels, particle effects, sounds and input handling.  It reads data from the game layer to render the appropriate visuals but does not drive gameplay logic itself.  This separation ensures that core mechanics remain deterministic and testable without a rendering context.

### `src/dev/`

Development utilities live here.  They include diagnostics overlays, telemetry collectors, sandboxes for experimenting with systems and any tooling that assists development but is not part of the shipping game.  These tools should be disabled or compiled out in production builds.

## Application entry point

The Godot project’s main scene is defined in `project.godot` as `res://scenes/app/Main.tscn`.  The `Main.tscn` scene creates the initial bootstrap screen for the project.  In future milestones this scene will be responsible for initialisation, configuration loading and handing over control to the game layer.

## Guiding principles

* **Separation of concerns:** Keep engine, game logic and presentation distinct.  Avoid coupling these layers.
* **Server‑authoritative simulation:** Even for single‑player, run the game through a server logic layer to maintain determinism and avoid divergent client states.
* **Reference, don’t copy:** Code from GoldSrc, Xash3D or HLSDK may be studied to understand behaviours and file formats but should never be copied.  Only open specifications and numerical constants should inform the reimplementation.
* **Incremental migration:** Prototypes such as Readytostrike serve as references.  Port functionality intentionally and incrementally through focused PRs rather than wholesale copying.

## Asset and presentation orchestration

Gameplay code uses semantic IDs and state transitions. It must not know file
paths such as `models/v_ak47.mdl`, `sprites/muzzleflash1.spr` or
`sound/weapons/ak47-1.wav`.

The intended flow is:

```
input -> game state -> weapon state -> semantic event
      -> presentation orchestration -> asset manager/provider
      -> viewmodel, audio, effect, HUD and diagnostics
```

Near-term orchestrators should be introduced only after the local GoldSrc VFS
and cvar/config foundations exist:

* `OpenStrikeAssetManager` and providers resolve local GoldSrc files.
* Game systems own authoritative weapon, movement and round state.
* Presentation systems own viewmodels, animation aliases, event timelines,
  audio, muzzle flashes, shell ejection, tracers, impacts, HUD and menus.
* Missing assets produce diagnostics and disabled features, not fake fallback
  content.
