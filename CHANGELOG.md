# Changelog

All notable changes to this project will be documented in this file.  The format is inspired by [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

* Added the first `src/game/runtime` local authoritative session skeleton:
  player slots, user commands, round-state skeleton data, fixed-tick stepping,
  team-aware spawn assignment from `OpenStrikeMapEntityIndex` and deterministic
  snapshots.
* Added `src/dev/smoke/local_game_session_smoke.gd` and wired it into shared
  smoke checks so PR-08A runtime state stays independent from dev labs,
  presentation and direct asset loading.
* Added `docs/agent_context_hygiene.md` as the required Task Packet,
  Assumptions and handoff workflow for preventing context rot in long agent
  sessions.
* Added `docs/current_context_contract.md` as the live compact context file
  that new agents should read after `AGENTS.md` and before relying on chat
  history.
* Added `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md` as the runtime-spine
  reference spec for BSP30 reader, clipnode trace, PMove contracts, denylist
  and acceptance criteria.
* Added `docs/COMPACT_PR_TASK_PACKETS.md` as the execution order for the
  GoldSrc runtime-spine PR sequence.
* Added the first synthetic OpenStrike-owned BSP30 collision slice under
  `src/core/bsp`: typed header/lump parsing, collision lump parsing for
  planes, clipnodes and GoldSrc 64-byte models, and a limited
  `OpenStrikeBspClipnodeTraceBackend` for model-0 synthetic hull traces.
* Added `src/dev/smoke/bsp30_clipnode_trace_smoke.gd` and wired it into shared
  smoke checks to prove point-hull hit, standing-hull hit, start-solid
  detection, free trace, malformed clipnode diagnostics, empty clipnodes as
  non-solid and Source-style 48-byte model rejection without Valve assets.
* Added `OpenStrikeTraceBackend`, `OpenStrikeCollisionTrace`,
  `OpenStrikeCollisionHull` and `OpenStrikeGodotSceneTraceBackend` as the
  narrow collision/query boundary for BSP runtime work. The current Godot scene
  backend reports `godot_scene_collision`, unverified confidence and
  `goldsrc_parity=false`, while `trace_hull` and `point_contents` remain
  blocked on an OpenStrike BSP reader.
* Added `OpenStrikeMapEntityIndex` to classify imported BSP entity metadata for
  player spawns, buyzones, bomb targets, illusionary brushes, trigger-like
  volumes and unknown classes outside the dev lab runner.
* Added trace backend and map entity index smoke checks and wired them into
  `scripts/run_smoke_checks.sh`.
* Added `docs/test_reports/2026-06-15_tracebackend_map_entity_index.md` with
  the local auto-exit BSP runner trace/backend/entity-index verification.
* Added `docs/TAINTED_LABS_POLICY.md`, `docs/TAINT_LEDGER.md` and
  `docs/PUBLIC_OPEN_SOURCE_EXIT_PLAN.md` so dirty labs, unlicensed dependency
  risk and public release gates are explicit before more runtime work builds on
  PR-07.
* Added `docs/test_reports/2026-06-15_bsp_reader_inventory.md` to record that
  the current repository has no `addons/hl_core`, OpenStrike-owned BSP reader,
  `trace_hull` or `point_contents` implementation.
* Added `scripts/check_taint_scope.sh` and wired it into shared smoke checks to
  keep accepted pre-release risk entries documented and block production imports
  from future `src/dev/tainted` paths.
* Added `CSMovementMath` as the production-owned shared movement math helper for
  acceleration, air acceleration, friction, wish direction and GoldSrc-style
  component maxvelocity checks.
* Added `OpenStrikeGoldSrcBspRuntimeProvider` to load local GoldSrc BSP maps
  through the existing VFS and vendored `alanfischer/goldsrc-godot`, reporting
  BSP/WAD/PVS/entity/imported-collision capabilities without claiming GoldSrc
  hull-trace parity.
* Added `src/dev/smoke/goldsrc_bsp_runtime_provider_smoke.gd` and wired it
  into the shared smoke script so BSP capabilities stay honest on platforms
  with and without the native GDExtension.
* Added `src/dev/labs/bsp_walkable/bsp_walkable_lab.gd`, a real-map manual
  test path that loads `maps/de_dust2.bsp`, spawns a first-person
  `CharacterBody3D`, uses the shared world profile/cvar-scaled movement values
  and writes per-tick JSONL telemetry plus a session summary under
  `user://telemetry/bsp_walkable/`.
* Added BSP-referenced WAD discovery so map-specific archives such as
  `cs_dust.wad` are loaded from the local VFS before map meshes are built.
* Vendored `alanfischer/goldsrc-godot` under `addons/goldsrc/` as the
  project-owned GoldSrc loader dependency for PR-06 viewmodel preflight,
  without committing Valve asset bytes or local generated imports.
* Added the shared `viewmodel_basis_correction=rotate_y_180` profile setting
  after visual preflight proved `goldsrc-godot` runtime MDL geometry otherwise
  sits behind Godot cameras.
* Added `scripts/bootstrap_gdextensions.sh` to manage local
  `.godot/extension_list.cfg`, enable the GoldSrc GDExtension only when a
  matching native library exists, and clear macOS quarantine attributes from
  vendored dylibs.
* Added `docs/THIRD_PARTY_DEPENDENCIES.md` to track committed dependency
  provenance, license status, vendored paths and operational rules.
* Added `docs/CS16_ASSET_ORCHESTRATION_ATLAS.md` as the required working map
  for CS 1.6 asset coverage levels, weapon/model/audio/effect/HUD/map domains,
  scanner outputs and PR-06 generated-atlas acceptance criteria.
* Added `docs/VIEWMODEL_WORLD_PROFILE.md` as the required PR-06A profile
  contract for GoldSrc unit scale, coordinate mapping, eye height, world FOV,
  viewmodel FOV, no-per-weapon-transform rules and profile smoke obligations.
* Added `docs/COVERAGE_STATUS_CONTRACT.md`,
  `gen/coverage_status_matrix.json`, `gen/generate.py` and the generated
  `data/schemas/coverage_status.schema.json` contract for scanner, generated
  atlas and coverage report status pairs.
* Added `src/dev/smoke/coverage_status_smoke.gd` and wired it into the shared
  smoke script to verify generated coverage status artifacts, schema fixtures
  and the verified/absence/provenance invariants.
* Added `data/config/viewmodel_world_profile.json`,
  `OpenStrikeViewmodelWorldProfile` and
  `src/dev/smoke/viewmodel_world_profile_smoke.gd` so PR-06 scale,
  GoldSrc-to-Godot mapping, eye height, FOV and no-per-weapon-transform rules
  are executable checks before real MDL rendering.
* Added a closed asset manifest entry allow-list so per-weapon transform keys
  cannot enter semantic asset catalog entries.
* Added `OpenStrikeGoldSrcRenderableProvider`,
  `src/dev/smoke/goldsrc_renderable_adapter_smoke.gd` and the
  `viewmodel_manual_preflight.gd` tool to bridge semantic pilot viewmodels to
  `alanfischer/goldsrc-godot` without adding project-owned MDL/SPR decoders.
* Added `docs/VIEWMODEL_MANUAL_PREFLIGHT.md` with the first local manual test
  point for loading and visually inspecting real pilot `v_*.mdl` files through
  the locked profile.
* Added agent/documentation instructions requiring future world/viewmodel scale,
  coordinate mapping, eye height, camera FOV and first-person placement work to
  read and update the viewmodel/world profile.
* Added agent/documentation instructions requiring future asset scanner,
  generated atlas and coverage report status changes to read the coverage
  status contract and edit only the matrix source of truth by hand.
* Added agent/documentation instructions requiring future weapon/viewmodel,
  animation, audio, muzzle flash, shell ejection, impact, grenade and HUD
  weapon-sprite work to read and update the asset orchestration atlas.
* Added an opt-in headless local asset catalog inspection tool for checking the
  pilot CS 1.6 weapon presentation catalog against `user://local_goldsrc.json`
  or an explicit config path without exposing local absolute paths in reports.
* Added synthetic smoke coverage for the local asset catalog inspection tool so
  CI validates the provider/VFS inspection path without requiring a local
  Counter-Strike installation.
* Added hard manifest-contract validation for asset type allowlists, provider
  allowlists, type-to-extension checks and safe GoldSrc-relative paths.
* Added manifest metadata retention in asset manifests and inspection reports.
* Added manifest contract smoke coverage for bad provider, bad type,
  type/extension mismatch, parent traversal, absolute paths, backslash paths
  and metadata retention.
* Added `data/assets/cs16_pilot_weapon_assets.json` with verified relative
  GoldSrc asset paths for the pilot AK-47, USP, knife and HE grenade
  presentation set.
* Added asset catalog smoke coverage that validates the pilot catalog through
  manifest inspection against synthetic `user://` fixtures.
* Added asset manifest inspection APIs that resolve semantic manifest entries
  through the GoldSrc VFS without reading asset bytes, returning resolved,
  missing and invalid counts for diagnostics.
* Added an asset manifest inspection smoke test with synthetic `user://`
  fixtures to verify preflight catalog reports before viewmodel orchestration.
* Added GoldSrc asset provider contracts for semantic asset manifests, asset
  references, provider results and raw local MDL/SPR/WAV byte loading through
  `OpenStrikeAssetManager`.
* Added an asset provider smoke test with synthetic `user://` MDL/SPR/WAV files
  to verify semantic viewmodel, sprite and sound requests without committing
  proprietary fixtures.
* Added `docs/AGENT_SKILLS/GODOT_OPENSTRIKE_SKILL.md` as the required
  project-specific Godot/GDScript workflow guide for AI agents.
* Added `docs/3KLIKSPHILIP_RESEARCH_NOTES.md` as a community-engineering
  research note for Counter-Strike experiment design, dev labs, latency,
  hitboxes, mapping, performance, HUD and viewmodel cost.
* Added `docs/SOURCE_CATALOG.md` to classify external references by source
  weight and document use/do-not-use rules.
* Added `docs/DEV_LABS_METHODOLOGY.md` to define the lab contract for turning
  subjective feel claims into telemetry, debug overlays and acceptance criteria.
* Added a project decision that subjective feel claims require source
  classification and lab-backed evidence.
* Added `docs/CS_1_6_FEEL.md` as the research baseline for movement, weapon,
  prediction, presentation, map and feedback feel.
* Added agent/documentation instructions to read the CS 1.6 feel baseline before
  feel-sensitive work.
* Added `docs/GDSCRIPT_AGENT_NOTES.md` to record GDScript/Godot pitfalls that
  slow agents down, starting with `clamp()` type inference and cascade preload
  errors.
* Added explicit fastrun/diagonal movement smoke coverage for the CS 1.6
  M-002 acceptance case.
* Added a cvar-backed CS-style movement simulation core for ground
  acceleration, friction, air acceleration, jump, duck and step-height checks.
* Added movement telemetry snapshots for smoke tests and future golden
  comparisons.
* Added a movement smoke test and included it in the shared smoke-check script.
* Added `docs/MOVEMENT.md` to document movement scope, cvars and reference-only
  constants.
* Added GitHub Actions CI for Godot headless project smoke, Asset VFS smoke,
  cvar/config smoke, whitespace checks and forbidden asset scans.
* Added local smoke and forbidden asset scan scripts for the same checks used
  by CI.
* Added a project decision to commit Godot `.gd.uid` sidecar files for stable
  resource UIDs.
* Added cvar unit documentation for movement and round-rule defaults.
* Added `OpenStrikeCvarRegistry`, `OpenStrikeConfigLoader` and
  `OpenStrikeBindRegistry` for default cvars, user-style overrides,
  serialization and key-command binding data.
* Added a headless cvar/config smoke test for default cvar loading, overrides, serialization and bind/unbind parsing.
* Added `docs/CVARS_AND_CONFIG.md` to document the cvar, config and bind layer.
* Added `OpenStrikeAssetManager`, `OpenStrikeGoldSrcLocalConfig`,
  `OpenStrikeGoldSrcVFS` and structured asset diagnostics for raw local asset
  resolution.
* Added a headless Asset VFS smoke test that uses synthetic files under `user://`.
* Added `docs/LOCAL_GOLDSRC_CONFIG.md` to document the local config schema, search order and VFS path rules.
* Added `docs/DECISIONS.md` to record legal, architecture, reuse, fallback and changelog rules.
* Added a PR-01 bootstrap integrity and project-contract plan before asset, movement and weapon work.
* Added testing checklist coverage for bootstrap integrity, documentation consistency and changelog updates.

### Changed

* Changed local runtime spawn assignment to consume sanitized spawn descriptors
  from `OpenStrikeMapEntityIndex` instead of reading `Node3D` scene objects
  from entity entries.
* Extended `OpenStrikeCollisionTrace` with `hit`, `start_solid`, `all_solid`,
  `contents` and `model_index` report fields so synthetic BSP clipnode traces
  can use the existing TraceBackend result contract instead of creating a
  duplicate trace DTO.
* Extended sanitized spawn descriptors with a `source` field and changed the
  local runtime smoke to use a descriptor-only index with no `Node3D`
  dependency.
* Changed the BSP walkable lab to consume `OpenStrikeMapEntityIndex` for spawn
  selection and non-blocking entity collision policy instead of keeping a
  hardcoded class list in the runner.
* Extended BSP walkable lab telemetry with trace backend source, confidence,
  `goldsrc_parity_collision=false` and a map entity index report, so manual
  tests can distinguish temporary Godot scene collision from future GoldSrc
  hull trace.
* Changed the BSP walkable lab to consume shared movement math instead of
  owning duplicate friction, acceleration and maxvelocity equations. Its air
  branch now preserves the PR-04A rule that full wishspeed drives acceleration
  amount while the air cap limits only add-speed.
* Clarified `alanfischer/goldsrc-godot` as an accepted pre-release risk: the
  vendored snapshot has no license file, absence of a license does not grant
  redistribution rights and the OpenStrike MIT license does not cover the
  vendored dependency.
* Updated the near-term plan so the next manual validation point is a walkable
  real BSP map with trace logging, not further greybox or weapon tuning.
* Adjusted the walkable BSP lab after the first manual run: no-weapon movement
  is capped to 250 ups, non-blocking trigger-like brush entities are removed
  from player collision, step-up attempts are logged, and lab lighting is
  reduced to avoid washing out imported textures.
* Extended the walkable BSP lab to render local GoldSrc skybox faces from
  `worldspawn.skyname` as an environment panorama, hide imported BSP `sky`
  render meshes that otherwise occlude the background, open the manual test
  fullscreen by default, and play local first-person movement WAVs for
  footsteps, jump and landing events.
* Added a dev-lab reporting rule and recorded the first BSP walkable lab report
  after the user-assisted `de_dust2` skybox/audio test.
* Removed Esc-to-quit from the walkable BSP lab so accidental key presses do
  not terminate manual telemetry sessions; use Cmd+Q or close the window.
* Documented `godot_scene_collision` as the first BSP lab's temporary collision
  bridge while GoldSrc clipnodes, player hulls and hull traces remain
  `requires_openstrike_bsp_reader`.
* Updated PR-06 documentation so `goldsrc-godot` is treated as a vendored
  OpenStrike dependency while real CS 1.6 assets remain local-only and
  user-licensed.
* Extended the shared smoke-check script to bootstrap GDExtension registration
  before Godot headless checks, preserving `extension_missing` behavior on
  platforms without committed native binaries.
* Extended the shared smoke-check script to run the local asset catalog
  inspection tool in synthetic mode after pilot catalog validation and before
  cvar/movement checks.
* Tightened semantic asset manifests before PR-06 so presentation code cannot
  consume mismatched types, unsupported providers or unsafe paths as stable
  catalog data.
* Extended the shared smoke-check script to run the pilot asset catalog smoke
  after manifest inspection and before cvar/movement checks.
* Extended the shared smoke-check script to run asset manifest inspection after
  provider contract smoke and before cvar/movement checks.
* Extended the shared smoke-check script to run the asset provider contract
  smoke before cvar and movement checks.
* Updated local GoldSrc config validation so `half_life_dir` can derive
  `cstrike_dir` and `valve_dir`, while explicit `cstrike_dir + valve_dir`
  roots are valid without `half_life_dir`.
* Prefixed generic public core GDScript classes with `OpenStrike*` while
  intentionally keeping domain-specific `CSMovement*` names unchanged.
* Implemented `sv_maxvelocity` as a GoldSrc-style component-wise velocity check
  at frame start and after velocity-changing phases, added ground over-limit
  smoke coverage, and aligned long-run air-strafe smoke expectations with that
  contract while keeping the short air-strafe oracle analytical.
* Documented that `edgefriction` is loaded from cvars but deferred until an
  edge-trace movement PR introduces the needed collision context.
* Updated agent reading instructions so Godot, GDScript, scene, resource,
  presentation, asset-provider and Godot smoke/CI work starts from the
  OpenStrike Godot skill.
* Updated agent and documentation rules so new external research must be
  classified in the source catalog and subjective feel claims must map to a lab,
  telemetry artifact, smoke test or debug overlay.
* Aligned movement defaults with the CS 1.6 feel baseline: 100 Hz simulation,
  `sv_accelerate=5`, `sv_stopspeed=75`, `edgefriction=2` and
  `sv_maxvelocity=2000`.
* Added GoldSrc-style directional button-state input helpers so smoke tests can
  distinguish released, just-pressed and held movement buttons.
* Updated movement smoke checks to use the cvar-backed fixed timestep.
* Fixed movement air acceleration to use separate full and capped wishspeed
  values for GoldSrc-style air-strafe gain.
* Updated jump-frame movement order so ground acceleration runs before takeoff.
* Clarified that `sv_air_max_wishspeed` and `sv_jumpvelocity` are
  OpenStrike-specific parity knobs.
* Clarified that current step-up movement coverage is a helper, not a
  collision-integrated stair solver.
* Fixed config and bind parsing so `//` inside quoted strings is preserved
  while real comments are still stripped.
* Corrected `mp_buytime` to `1.5` minutes instead of a seconds-style value.
* Updated Godot scene metadata to use Godot 4 Control offsets.
* Normalized `project.godot` with current Godot 4 metadata and committed
  generated UID sidecars.
* Reworked the roadmap around the GoldSrc reimplementation sequence: bootstrap, local config/VFS, cvars, movement, asset providers, viewmodel orchestration, BSP, game loop and gameplay systems.
* Updated the development plan so local asset resolution and cvar authority come before movement and weapon presentation.
* Clarified asset pipeline responsibilities: raw file resolution and diagnostics precede format parsing.
* Documented the initial local GoldSrc config and VFS implementation classes.
* Clarified architecture boundaries for semantic gameplay events, presentation orchestration and provider-driven assets.
* Restored `project.godot` to a valid Godot 4 configuration with an explicit main scene.

### Process

* Inserted PR-08A before the full local game loop and weapon-loop work so
  future gameplay features have a server-authoritative owner instead of
  growing inside BSP/dev-lab scripts.
* Added a context hygiene rule to `AGENTS.md` and the docs reading order:
  non-trivial project work starts from a compact Task Packet, explicit
  Assumptions and the live Current Context Contract.
* Adopted the compact runtime-spine task packets: the next package after
  PR-08A.1 is `PR-08B BSP30 collision vertical slice`, while runtime movement
  integration is deferred to a later package.
* Recorded the PR-08B synthetic hull-extent decision: the smoke fixture uses
  runtime plane offsets over point-space planes, scoped to synthetic BSP30
  clipnodes and not asserted as the final real-map hull-space contract.
* Inserted PR-07.2 as a boundary cleanup before LocalGameServer or weapon-loop
  work, so BSP map tests expose TraceBackend and MapEntityIndex contracts
  without pretending a GoldSrc BSP reader already exists.
* Inserted PR-07.1 as a cleanup-only runtime spine step before TraceBackend,
  weapons or LocalGameServer work, so PR-07 remains a dev lab and does not
  become production architecture by accident.
* Inserted PR-07 as a map-first walkable BSP lab after review and manual-test
  feedback showed that greybox-only tuning risks moving OpenStrike away from
  CS 1.6 map scale, lighting, collision and spawn constraints.
* Paused roadmap feature work to close the ReadyToStrike reuse gap by making
  `goldsrc-godot` an explicit OpenStrike project dependency instead of relying
  on symlinks, per-machine addon installs or project-owned duplicate decoders.
* Tightened PR-06 into a profile/scanner-first sequence: PR-06A locks and
  smoke-tests the world/viewmodel profile before real `.mdl` rendering, and
  PR-06B consumes local GoldSrc assets through generated atlas diagnostics
  instead of eyeballed model scale, FOV, offset or timing guesses.
* Inserted PR-05D before weapon/viewmodel orchestration so the pilot catalog can
  be checked against a developer's licensed local installation through the same
  provider/VFS contract before PR-06 consumes it.
* Inserted PR-05C before weapon/viewmodel orchestration after review identified
  that the provider/catalog foundation was directionally correct but the
  manifest contract still needed defense-in-depth validation.
* Inserted PR-05B before weapon/viewmodel orchestration because the pilot
  weapon presentation catalog should be reviewable data and smoke-validated
  before presentation code depends on those semantic asset IDs.
* Inserted PR-05A before weapon/viewmodel orchestration so real CS 1.6 asset
  catalogs can be inspected against a local installation and reported as data
  before presentation code depends on them.
* Started PR-05 with semantic provider contracts and synthetic smoke coverage
  before adding a real CS 1.6 asset catalog, so provider work does not hardcode
  guessed model, sprite, sound or animation mappings.
* Inserted PR-04E before asset providers because review identified two contract
  cleanups that should not be inherited by provider work: generic core
  `class_name` collisions and an air-strafe golden test that encoded unlimited
  speed despite `sv_maxvelocity=2000` being part of default config.
* Inserted PR-04D before asset providers because the 3kliksphilip research
  notes add a missing methodology gate: future feel-sensitive work should be
  evidence-backed before presentation and asset work resumes.
* Inserted PR-04C before asset providers because the accepted
  `CS_1_6_FEEL.md` baseline identifies fastrun/diagonal acceleration as a
  movement acceptance criterion; this keeps PR-05 from building presentation
  work on an unverified movement contract.
* Added a process rule requiring future GDScript/Godot stumbling blocks to be
  documented in `docs/GDSCRIPT_AGENT_NOTES.md` in the same PR.
* Closed superseded pull request #3 without merge in favor of a smaller bootstrap/project-contract branch from `main`.

## [0.1.0] – Bootstrap

* Initial repository structure and Godot 4 project created.
* Added documentation: roadmap, development plan, legal originality, architecture, asset pipeline, knowledge base and testing strategy.
* Added `AGENTS.md` with strict guidelines for AI agents.
* Configured `.gitignore` and `.gitattributes` to exclude caches, imported assets and local configuration files.
* Implemented a simple `Main.tscn` scene that displays a bootstrap screen.
