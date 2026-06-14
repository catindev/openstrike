# Testing Strategy

This document outlines the testing strategy for OpenStrike.  As of milestone 0.1.0, the focus is on establishing basic smoke tests and planning for future comprehensive test suites.

## Current (PR‑00) checklist

For the bootstrap milestone, manual verification is sufficient:

* **Godot project smoke test:** Open the project in Godot 4.x and run the main scene.  Verify that the bootstrap screen appears with the project name, version and legal notice.  There should be no errors or warnings in the output.
* **No bundled Valve assets:** Search the repository for any prohibited file types (.bsp, .mdl, .spr, .wad, .wav, .bmp).  Ensure none are present.
* **Configuration files:** Ensure that no `local_goldsrc.json` or other user‑specific configuration files are committed.
* **Documentation coverage:** Confirm that documentation has been updated or created to reflect any new changes.

## Current (PR-01) checklist

For bootstrap integrity and project-contract changes, perform the following
checks:

* **Godot project smoke test:** Run `Godot --headless --path . --quit` or open
  the project manually. The project must have a valid main scene and must not
  report `no main scene defined`.
* **Documentation consistency:** Confirm that `ROADMAP.md`,
  `DEVELOPMENT_PLAN.md`, `ARCHITECTURE.md`, `ASSET_PIPELINE.md` and
  `DECISIONS.md` agree on implementation order: local config/VFS and cvars
  come before movement, viewmodel and weapon presentation work.
* **Changelog coverage:** Confirm that `CHANGELOG.md` contains an English entry
  for the PR.
* **No bundled Valve assets:** Search the repository for prohibited file types
  (`.bsp`, `.mdl`, `.spr`, `.wad`, `.wav`, `.bmp`) and ensure none are present.
* **Configuration hygiene:** Ensure that no `local_goldsrc.json` or user-specific
  path is committed.

## Current (PR-02) checklist

For local GoldSrc configuration and VFS skeleton changes, perform the following
checks:

* **Godot project smoke test:** Run `Godot --headless --path . --quit`.
* **Asset VFS smoke test:** Run
  `Godot --headless --path . --script res://src/dev/smoke/asset_vfs_smoke.gd`.
  This creates a synthetic temporary tree under `user://` and verifies
  case-insensitive lookup, cstrike-over-valve overlay order, fallback lookup,
  path traversal rejection and raw byte reads.
* **No real GoldSrc fixtures:** Confirm that the repository still contains no
  `.bsp`, `.mdl`, `.spr`, `.wad`, `.wav`, `.bmp` or committed
  `local_goldsrc.json` files.
* **Documentation coverage:** Confirm that `ASSET_PIPELINE.md` and
  `LOCAL_GOLDSRC_CONFIG.md` describe the implemented schema and VFS behavior.
* **Changelog coverage:** Confirm that `CHANGELOG.md` contains an English entry
  for the PR.

## Current (PR-03) checklist

For cvar, config and bind changes, perform the following checks:

* **Godot project smoke test:** Run `Godot --headless --path . --quit`.
* **Asset VFS smoke test:** Run
  `Godot --headless --path . --script res://src/dev/smoke/asset_vfs_smoke.gd`
  to ensure asset-layer work still compiles.
* **Cvar config smoke test:** Run
  `Godot --headless --path . --script res://src/dev/smoke/cvar_config_smoke.gd`.
  This verifies default cvar loading, user-style overrides, serialization and
  bind/unbind parsing.
* **No real GoldSrc fixtures:** Confirm that the repository still contains no
  `.bsp`, `.mdl`, `.spr`, `.wad`, `.wav`, `.bmp` or committed
  `local_goldsrc.json` files.
* **Documentation coverage:** Confirm that `CVARS_AND_CONFIG.md` describes the
  implemented cvar and bind scope.
* **Changelog coverage:** Confirm that `CHANGELOG.md` contains an English entry
  for the PR.

## Current (PR-03A) checklist

For CI and configuration hygiene changes, perform the following checks:

* **Godot project smoke test:** Run `scripts/run_smoke_checks.sh`. This runs
  the Godot headless project smoke test, the asset VFS smoke test and the
  cvar/config smoke test using `GODOT_BIN` when it is provided.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check`.
* **CI coverage:** Confirm that `.github/workflows/ci.yml` runs the same smoke
  and repository hygiene checks on pull requests and pushes to `main`.
* **Godot metadata hygiene:** Commit `.gd.uid` sidecars generated for committed
  project scripts/resources so Godot resource UIDs remain stable.
* **Documentation coverage:** Confirm that `DECISIONS.md`,
  `CVARS_AND_CONFIG.md` and this testing document describe the changed rules.
* **Changelog coverage:** Confirm that `CHANGELOG.md` contains an English entry
  for the PR.

## Current (PR-04) checklist

For movement parity changes, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  movement smoke test in addition to project, asset VFS and cvar/config smoke.
* **Movement smoke test:** Run
  `Godot --headless --path . --script res://src/dev/smoke/movement_smoke.gd`
  when iterating locally on movement.
* **Movement telemetry:** Confirm that `movement_smoke.gd` records telemetry for
  maxspeed, fastrun and air-wishspeed assertions. Air-strafe expected ranges
  must be calculated independently from the reference equation, not copied from
  the current implementation output. Fastrun checks must keep the first
  half-state W+A frame and held-diagonal transient ranges explicit.
* **Explicit timestep:** Movement smoke tests must state the `delta` they use.
  Current parity smoke checks use `movement_sim_hz = 100`, or `0.01` seconds,
  for 100 fps reference cases.
* **No presentation coupling:** Confirm that `src/game/movement` does not load
  assets, viewmodels, HUD, sounds or Godot scene nodes.
* **Documentation coverage:** Confirm that `MOVEMENT.md`,
  `CS_1_6_FEEL.md`, `CVARS_AND_CONFIG.md` and `KNOWLEDGE_BASE.md` describe any
  changed movement constants or TODO-verification gaps.
* **Changelog coverage:** Confirm that `CHANGELOG.md` contains an English entry
  for the PR.

## Future plans

As the project matures, automated testing will become essential.  Planned areas include:

* **Config loading tests:** Verify that cvar files and user configuration files load correctly and produce expected values.
* **Asset provider tests:** Unit tests for each asset provider (BSP, MDL, WAD, SPR, WAV) to ensure parsers handle valid and malformed data.
* **Movement telemetry tests:** Automated comparison of movement trajectories against golden data to ensure parity with reference behaviour.
* **Golden‑file fixtures:** For file parsers, create non‑proprietary fixtures and compare parsed output to golden results.
* **Expanded CI:** Build GDExtensions with sanitizers (ASan/UBSan), add parser
  fixtures and report regressions beyond the current smoke gate.
* **Network simulation tests:** When networking is introduced, simulate client/server scenarios to detect desynchronisation.

Testing will be expanded incrementally with each milestone to cover new functionality.
