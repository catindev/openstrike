# Public Open-Source Exit Plan

OpenStrike is currently in pre-release engineering mode. Before public release,
package distribution or broad licensing claims, the project must pass this exit
gate.

## Required Gate Checks

* No Valve, Half-Life or Counter-Strike asset bytes are committed or packaged.
* No private local configs, absolute user paths, import caches or telemetry
  dumps with local paths are committed or packaged.
* No dirty or tainted implementation code is imported by `src/core`, `src/game`
  or `src/presentation`.
* `docs/TAINT_LEDGER.md` has been reviewed and every open item has a release
  decision.
* `addons/goldsrc/` is license-reviewed, replaced, excluded from release
  artifacts or explicitly accepted under a documented maintainer decision.
* The OpenStrike MIT license scope is clear and does not imply coverage of
  vendored third-party dependencies.
* Xash3D, HLSDK, GPL or no-license code has not been copied into shipped code.
* Release scripts exclude dirty/dev-only pieces unless those pieces are
  explicitly approved for release.

## Current Blockers

* `addons/goldsrc/` is an accepted pre-release risk with no license file in the
  vendored snapshot.
* PR-07 map walking uses `godot_scene_collision`, which is a temporary
  non-parity backend, not a final GoldSrc clipnode/hull trace implementation.

## Intended Direction

OpenStrike may keep using temporary bridges to reach a playable slice quickly,
but each bridge should sit behind an interface or isolated lab boundary. Public
release requires either a clean replacement or an explicit exclusion decision
for every unresolved bridge.
