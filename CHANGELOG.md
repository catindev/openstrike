# Changelog

All notable changes to this project will be documented in this file.  The format is inspired by [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

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
