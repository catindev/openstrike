# Development Plan

This plan defines the first pull requests for OpenStrike. Each PR must be a
small, reviewable step. The project follows GitHub Flow: one conceptual change
per branch, with documentation and changelog updates in the same PR.

## PR-00 Bootstrap

**Goal:** Create the minimal Godot project and legal/documentation baseline.

**Includes:**

* Godot project configuration and `scenes/app/Main.tscn`.
* Repository structure for `src/core`, `src/game`, `src/presentation`, `src/dev` and `data`.
* Initial legal, architecture, asset pipeline, testing and roadmap documents.
* `AGENTS.md` with non-negotiable agent and legal rules.

**Excludes:**

* Gameplay, asset loading, movement, weapons, HUD and networking.
* Any Valve, Half-Life, Counter-Strike or extracted GoldSrc assets.

**Acceptance criteria:**

* The project opens in Godot and the main scene runs.
* No local user paths or proprietary assets are committed.

## PR-01 Bootstrap integrity and project contract

**Goal:** Keep the project bootable and align documentation around the new
implementation order before adding subsystems.

**Includes:**

* Valid `project.godot` with a working main scene entry point.
* Decision log for legal, architecture and reuse boundaries.
* Roadmap and development plan aligned with the GoldSrc reimplementation strategy.
* Changelog entry for all project-contract changes.

**Excludes:**

* Runtime AssetManager implementation.
* Gameplay logic.
* Migration of Readytostrike weapon/viewmodel code.

**Acceptance criteria:**

* `Godot --headless --path . --quit` succeeds.
* Documentation agrees that VFS/cvars precede movement and weapon presentation.
* The changelog records the change in English.

## PR-02 Local configuration and VFS skeleton

**Goal:** Introduce the local GoldSrc configuration and raw file resolution layer.

**Includes:**

* `local_goldsrc.json` schema documentation and loader.
* Local path validation for `valve/` and `cstrike/`.
* VFS interfaces for GoldSrc-like search paths and case-insensitive lookup.
* Diagnostics for missing, invalid or incomplete installations.

**Excludes:**

* BSP, MDL, SPR, WAD, PAK or WAV parsing.
* Any bundled proprietary asset or cached extracted asset.

**Acceptance criteria:**

* Given a valid local config, the VFS can resolve and read raw files from the configured installation.
* Missing files produce structured diagnostics, not placeholders.

## PR-03 Cvars, config and binds

**Goal:** Make configuration values authoritative before implementing movement or gameplay.

**Includes:**

* Cvar registry with defaults from `data/cvars/default.cfg`.
* Read-only default config loading and user override hooks.
* Command/bind data structures for later console and menu integration.

**Excludes:**

* Networked console commands.
* Gameplay systems that only consume cvars later.

**Acceptance criteria:**

* Cvars can be defined, queried, changed at runtime and serialized for user config.
* Movement and weapon PRs have a stable config API to consume.

## PR-03A CI and config hygiene

**Goal:** Put an automated smoke and repository hygiene gate in place before
movement work starts.

**Includes:**

* GitHub Actions workflow for Godot headless project smoke, asset VFS smoke,
  cvar/config smoke, whitespace checks and forbidden asset scans.
* Local scripts that run the same checks outside CI.
* Parser hardening for quoted config/bind values.
* Cvar unit documentation and corrected CS-style defaults where needed.
* Godot metadata policy for committed `.gd.uid` sidecars.

**Excludes:**

* New movement mechanics.
* Asset format parsing.
* Weapon/viewmodel presentation work.

**Acceptance criteria:**

* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass locally and in CI.
* Quoted `//` sequences in cvar and bind values are preserved.
* The changelog and testing docs record the new gate.

## PR-04 Movement parity

**Goal:** Implement CS 1.6-like player movement on top of cvars.

**Includes:**

* Ground acceleration, friction, jump, air acceleration, ducking and step behavior.
* Telemetry capture for movement tests.
* Public GoldSrc/CS movement constants marked as reference data.

**Excludes:**

* Weapon handling, recoil, viewmodel bob or presentation.

**Acceptance criteria:**

* Telemetry matches expected ranges for maxspeed, air wishspeed cap, air-strafe
  gain, jump-frame order and friction behavior.

## PR-04A Air acceleration parity fix

**Goal:** Correct the first movement-core parity gap before asset provider work.

**Includes:**

* GoldSrc-style air acceleration with separate full and capped wishspeed values.
* Jump-frame ordering where ground acceleration runs before takeoff.
* Discriminating 100 fps air-strafe telemetry smoke coverage.
* Documentation updates for OpenStrike-specific parity cvars and helper-only
  step-up behavior.

**Excludes:**

* Collision plane solver, water, ladders, surfing, edgefriction and basevelocity.
* Weapon speed modifiers.
* Asset provider work.
* `class_name` or local GoldSrc config contract cleanup.

**Acceptance criteria:**

* `movement_smoke.gd` fails on the pre-fix capped-wishspeed implementation and
  passes with independently calculated air-strafe gain.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-05 Asset providers for MDL, SPR and WAV

**Goal:** Load core weapon presentation assets through provider APIs.

**Includes:**

* Provider interfaces for view models, sprites and audio streams.
* Legal runtime loading from the user's local installation.
* Diagnostics for missing animations, sprites and sounds.

**Excludes:**

* Gameplay weapon authority.
* Procedural placeholder weapons, sounds or muzzle flashes.

**Acceptance criteria:**

* Presentation code can request assets by semantic IDs.
* Gameplay code does not contain direct `models/*.mdl`, `sprites/*.spr` or `sound/*.wav` paths.

## PR-06 Weapon and viewmodel orchestration

**Goal:** Add first-person weapon presentation using semantic events.

**Includes:**

* Viewmodel rig or camera layer for first-person models.
* Weapon animation alias resolver.
* Weapon event timeline for draw, fire, reload, shell eject and muzzle flash.
* Audio and effect orchestration boundaries.

**Excludes:**

* Damage, armor and full combat model.

**Acceptance criteria:**

* A weapon can be deployed, fired and reloaded through semantic events.
* Missing assets produce diagnostics and disabled features, not fake fallback meshes or sounds.

## PR-07 BSP map pipeline

**Goal:** Load real GoldSrc maps through the asset pipeline.

**Includes:**

* BSP discovery and map definitions.
* Entity-lump metadata extraction.
* Spawn point discovery.
* Initial collision/import integration.

**Excludes:**

* Full PVS optimization and all interactive map entities.

**Acceptance criteria:**

* A local BSP map can be selected, loaded and used for player spawning without committing map assets.

## PR-08 Server-authoritative local game loop

**Goal:** Run offline gameplay through a server-style game layer.

**Includes:**

* GameDirector or equivalent local authoritative simulation root.
* Round state skeleton, teams and spawn assignment.
* Deterministic weapon runtime state.

**Excludes:**

* LAN networking and lag compensation.

**Acceptance criteria:**

* Single-player/offline play uses the same game-layer authority that future networking will use.
