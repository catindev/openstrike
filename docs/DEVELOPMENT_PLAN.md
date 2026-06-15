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

* Runtime asset-manager implementation.
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

## PR-04B CS 1.6 feel baseline and movement defaults

**Goal:** Bring the accepted CS 1.6 feel baseline into the repository and align
the current movement defaults with that baseline before asset-provider work.

**Includes:**

* `docs/CS_1_6_FEEL.md` as the research baseline for feel-sensitive systems.
* Agent/documentation instructions requiring the baseline before movement,
  weapons, prediction, BSP collision, HUD, viewmodel or feedback changes.
* CS 1.6 movement defaults for 100 Hz simulation, `sv_accelerate=5`,
  `sv_stopspeed=75`, `edgefriction=2` and `sv_maxvelocity=2000`.
* Movement docs listing baseline gaps that remain for later PRs.

**Excludes:**

* Fastrun, bhop FOG, duck/double-duck, edgefriction trace and hull collision
  implementations.
* Asset provider work.

**Acceptance criteria:**

* Movement smoke checks read the accepted 100 Hz CS 1.6 defaults from cvars.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-04C Fastrun and diagonal movement telemetry

**Goal:** Close the nearest movement acceptance gap from `CS_1_6_FEEL.md`
before asset-provider work: M-002 W+A fastrun transient behavior.

**Why before PR-05:** The accepted feel baseline makes fastrun/diagonal
acceleration part of the movement definition, not a presentation detail. Asset
providers and viewmodel work should not build on a movement solver whose
ground-speed transient contract is still untested.

**Includes:**

* GoldSrc-style movement button-state helper for released, just-pressed and
  held directional buttons.
* Smoke coverage for a 250 ups weapon-speed fastrun case:
  first W+A half-state frame near `251.24` ups and held diagonal transient
  peak in the CS 1.6 reference range.
* Movement documentation and changelog entries explaining the plan change.

**Excludes:**

* Full mouse-yaw fastrun lab.
* Bhop FOG, mega-bunny damping, edgefriction traces and hull collision.
* Asset provider work.

**Acceptance criteria:**

* `movement_smoke.gd` fails if diagonal input is normalized into a modern
  no-transient movement model.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-04D Research catalog and dev-lab methodology

**Goal:** Bring the 3kliksphilip community-engineering research notes into the
repository and convert the useful part into project process before asset and
presentation work resumes.

**Why before PR-05:** The notes do not replace GoldSrc references or add exact
CS 1.6 constants. Their useful contribution is methodology: controlled labs,
one changed variable, debug visualization, telemetry export and before/after
evidence. That process should be in place before future asset, viewmodel,
weapon, hitbox and HUD work starts producing subjective feel claims.

**Includes:**

* `docs/3KLIKSPHILIP_RESEARCH_NOTES.md` as the full working research note.
* `docs/SOURCE_CATALOG.md` with source weighting and use/do-not-use rules.
* `docs/DEV_LABS_METHODOLOGY.md` with the lab contract and evidence gates.
* Agent/documentation instructions requiring source catalog updates for new
  research and lab evidence for subjective feel claims.

**Excludes:**

* Implementing `HitboxLab`, `InputLatencyLab`, `HudCostLab` or map fixture
  packs immediately.
* Treating CS:GO/CS2 measurements as CS 1.6 constants.
* Any source-code, asset or value copying from videos or third-party projects.

**Acceptance criteria:**

* The 3kliksphilip material is classified as methodology/symptom reference, not
  a primary CS 1.6 parity source.
* The next implementation PRs have a documented rule for mapping feel claims to
  telemetry, smoke tests, debug overlays or planned labs.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-04E Asset/config contract cleanup

**Goal:** Clean up the local asset/config contracts before provider work and
close the one movement cvar/test mismatch that would otherwise lock in a known
wrong golden model.

**Why before PR-05:** Asset providers should build on stable global class
names, local GoldSrc root semantics and VFS smoke coverage. Also,
`sv_maxvelocity=2000` already exists in default settings while the air-strafe
golden test previously encoded unlimited velocity growth. Fixing that contract
now keeps the test suite from preserving behavior that the config layer already
says should be bounded.

**Includes:**

* `OpenStrike*` prefixes for generic public core `class_name` declarations.
* Local GoldSrc config support for either `half_life_dir` derivation or
  explicit `cstrike_dir + valve_dir` roots without `half_life_dir`.
* Asset VFS smoke coverage for derived roots, explicit roots and invalid config
  diagnostics.
* GoldSrc-style component-wise `sv_maxvelocity` checks at frame start and after
  velocity-changing phases in the movement simulator, plus independent
  short-run and long-run air-strafe smoke expectations.
* Documentation updates explaining that `edgefriction` is loaded but still
  deferred until edge traces exist.

**Excludes:**

* Asset providers, parsers, importers or real GoldSrc fixtures.
* Edgefriction, bhop, duck timing, hull traces, collision plane solving,
  stair solving and weapon speed modifiers.
* Presentation, HUD, viewmodel and weapon lifecycle changes.

**Acceptance criteria:**

* `asset_vfs_smoke.gd` proves both supported local config shapes and invalid
  diagnostics using synthetic `user://` files only.
* No generic public core `class_name` declarations remain without the
  `OpenStrike*` prefix; `CSMovement*` names remain intentionally unchanged.
* Long-run air-strafe smoke would fail against the previous unlimited-speed
  golden model and passes with component-wise `sv_maxvelocity`.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-05 Asset providers for MDL, SPR and WAV

**Goal:** Load core weapon presentation assets through provider APIs.

**Includes:**

* Semantic asset manifest and reference objects.
* Provider result objects that expose diagnostics, VFS resolution details and
  raw bytes for later format decoders.
* GoldSrc provider methods for viewmodel, sprite and sound semantic IDs.
* Legal runtime loading from the user's local installation through VFS only.
* Smoke coverage using synthetic `user://` MDL/SPR/WAV files.
* Diagnostics for missing semantic IDs, missing physical assets and type
  mismatches.

**Excludes:**

* Gameplay weapon authority.
* Procedural placeholder weapons, sounds or muzzle flashes.
* Full MDL, SPR or WAV decoding.
* A real CS 1.6 weapon asset catalog until paths and animation aliases are
  verified.

**Acceptance criteria:**

* Presentation code can request assets by semantic IDs.
* Gameplay code does not contain direct `models/*.mdl`, `sprites/*.spr` or `sound/*.wav` paths.
* Missing assets produce structured diagnostics without placeholder resources.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-05A Asset manifest inspection

**Goal:** Add a preflight diagnostic layer for semantic asset manifests before
weapon/viewmodel presentation starts consuming a real CS 1.6 catalog.

**Why before PR-06:** Viewmodel orchestration should not depend on guessed or
silently incomplete asset mappings. A manifest inspector lets future catalog
PRs prove which semantic IDs resolve against a local installation and which are
missing, without loading or decoding large files.

**Includes:**

* Provider inspection methods that resolve assets through VFS without reading
  bytes.
* Manifest-level inspection report with total, resolved, missing, invalid and
  per-type counts.
* Smoke coverage using synthetic `user://` files and an intentionally missing
  manifest entry.
* Documentation and changelog entries explaining the plan insertion.

**Excludes:**

* Real CS 1.6 asset catalog entries.
* MDL, SPR or WAV decoders.
* Viewmodel rig, animation aliases, weapon lifecycle or presentation events.

**Acceptance criteria:**

* Manifest inspection distinguishes resolved assets, missing physical files and
  invalid manifest/provider entries.
* Inspection does not read raw asset bytes or depend on format decoders.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-05B Pilot weapon asset catalog

**Goal:** Add a small, reviewable CS 1.6 presentation asset catalog for the
pilot weapon set before any viewmodel orchestration consumes it.

**Why before PR-06:** Weapon/viewmodel orchestration needs stable semantic IDs
and relative GoldSrc paths. Keeping the pilot catalog as data first lets
reviewers inspect the mapping, lets CI validate it through synthetic fixtures,
and avoids baking guessed paths into presentation code.

**Includes:**

* `data/assets/cs16_pilot_weapon_assets.json` for AK-47, USP, knife and HE
  grenade viewmodels, fire/reload/knife/grenade sounds and muzzleflash sprites.
* Relative GoldSrc paths only; no proprietary assets and no local absolute
  paths.
* Smoke coverage that loads the catalog, creates synthetic files for every
  catalog path under `user://`, and validates the catalog through manifest
  inspection.
* Source catalog, testing and changelog updates recording the verification
  method.

**Excludes:**

* MDL, SPR or WAV decoders.
* Animation alias tables and event timelines.
* Viewmodel rig, weapon lifecycle, gameplay authority or HUD/effects
  orchestration.
* Unverified asset paths. Missing candidates such as `usp_unsil-2.wav` and
  `grenade_throw.wav` remain out of the catalog until verified.

**Acceptance criteria:**

* The pilot catalog smoke resolves all catalog entries against synthetic files.
* The catalog contains no local paths and no proprietary asset bytes.
* The catalog maps only semantic IDs to relative GoldSrc paths and metadata.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-05C Manifest contract hardening

**Goal:** Tighten semantic asset manifest validation before presentation code
starts treating catalog entries as a stable runtime contract.

**Why before PR-06:** The provider/catalog direction is sound, but soft
manifest validation would still allow mismatched records such as a `sound`
asset pointing at `.mdl`, unsupported providers or unsafe paths. PR-06 should
consume a hardened manifest contract instead of inheriting that ambiguity.

**Includes:**

* Asset type allowlist: `view_model`, `sprite`, `sound`.
* Provider allowlist: `goldsrc`.
* Type-to-extension validation:
  `view_model -> .mdl`, `sprite -> .spr`, `sound -> .wav`.
* Manifest path validation for non-empty relative paths, no absolute paths, no
  URI paths, no parent traversal and no backslash ambiguity.
* Top-level manifest metadata retention in manifests and inspection reports.
* Smoke coverage for bad provider, bad type, extension mismatch, parent
  traversal, absolute path, backslash path and metadata retention.

**Excludes:**

* Viewmodel rig and presentation orchestration.
* Animation alias tables and event timelines.
* Gameplay weapon state.
* MDL, SPR or WAV decoding.
* Real asset bytes or local installation paths.

**Acceptance criteria:**

* Invalid manifest records fail validation before provider/presentation use.
* Inspection reports expose manifest metadata for catalog diagnostics.
* Existing pilot catalog entries pass the hardened contract.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-05D Local asset catalog inspection tool

**Goal:** Add an opt-in developer tool that inspects the pilot asset catalog
against a real local GoldSrc installation without committing local paths or
proprietary assets.

**Why before PR-06:** Weapon/viewmodel orchestration should consume a catalog
that developers can verify on their own licensed installation through the same
provider/VFS contract used by runtime code. This avoids returning to manual
screen-position guessing when a semantic asset is missing, mistyped or
unavailable locally.

**Includes:**

* Headless local catalog inspection command for
  `data/assets/cs16_pilot_weapon_assets.json`.
* `user://local_goldsrc.json` default config support plus explicit
  `--config=...` and `--catalog=...` overrides.
* Sanitised JSON reports that include manifest counts, per-entry status and
  diagnostics without printing absolute local paths, VFS roots or resolved
  filesystem paths.
* Synthetic smoke coverage that exercises the tool in CI without requiring a
  Counter-Strike installation.
* Documentation and changelog entries explaining why this verification step was
  inserted before weapon/viewmodel orchestration.

**Excludes:**

* MDL, SPR or WAV decoding.
* Real asset bytes, local installation paths or committed `local_goldsrc.json`.
* Viewmodel rig, animation alias tables, event timelines or gameplay weapon
  state.
* Replacing the runtime provider/VFS contract with dev-only path checks.

**Acceptance criteria:**

* The inspection tool can run headlessly against a local config or CI synthetic
  fixtures.
* Tool output redacts local absolute paths and does not expose `resolved_path`,
  `root` or VFS `tried` paths.
* The shared smoke script runs the synthetic tool mode without a local CS 1.6
  installation.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-06 Weapon and viewmodel orchestration

**Goal:** Add first-person weapon presentation using semantic events.

**Why atlas-first:** The project goal is a near-complete CS 1.6
reimplementation, not a four-weapon visual spike. PR-06 must start from a
world/viewmodel profile contract, a weapon/model/audio/effect lifecycle
contract and local inspection tooling so OpenStrike does not repeat the
Readytostrike pattern of guessing viewmodel scale, FOV, offsets and timings by
eye.

**PR-06A profile preflight:** Before rendering any `.mdl` in a dev scene,
OpenStrike must add the source-value profile fields, smoke-test scale,
GoldSrc-to-Godot coordinate mapping, eye heights, FOV derivation and the
anti-`58.7155`/anti-per-weapon-transform guards described in
`docs/VIEWMODEL_WORLD_PROFILE.md`.

**PR-06B real-asset runtime:** After the profile preflight, load the pilot
`v_*.mdl` files through the GoldSrc GDExtension adapter, run the shared
orientation calibration and render them through the locked profile with zero
per-weapon scale/position/FOV tuning.

**First manual test point:** Before gameplay/gunplay work, use
`src/dev/tools/viewmodel_manual_preflight.gd` with a local licensed install and
the vendored `alanfischer/goldsrc-godot` dependency enabled by
`scripts/bootstrap_gdextensions.sh`. The manual visual path must load real pilot
`v_*.mdl` models at profile scale/FOV with only the shared profile basis
correction. If it fails visually, record the symptom and fix the shared profile,
adapter or one global correction; do not add per-weapon transforms.

**Includes:**

* `docs/VIEWMODEL_WORLD_PROFILE.md` as the required profile contract for unit
  scale, coordinate mapping, eye height, world FOV, viewmodel FOV and
  no-per-weapon-transform rules.
* `docs/CS16_ASSET_ORCHESTRATION_ATLAS.md` as the required asset and lifecycle
  contract for weapon/viewmodel/audio/effect work.
* `docs/COVERAGE_STATUS_CONTRACT.md`,
  `gen/coverage_status_matrix.json` and the generated
  `data/schemas/coverage_status.schema.json` contract for scanner, generated
  atlas and coverage report status fields.
* GoldSrc GDExtension adapter boundary for `alanfischer/goldsrc-godot` rather
  than project-owned MDL/SPR decoders.
* `data/config/viewmodel_world_profile.json`, profile smoke and a manual
  preflight tool for real local viewmodel inspection/rendering.
* `goldsrc_asset_atlas` scanner skeleton or equivalent local inspection command
  that mounts `cstrike` and `valve`, builds a case-insensitive inventory and
  reports model, sprite, sound, HUD, map and dependency coverage without
  copying assets or printing local absolute paths.
* Local inspection output for pilot weapons that reports model availability,
  sequence names, sequence durations, attachments/events when exposed,
  HUD/effect candidates and sound/sprite availability.
* Viewmodel rig or camera layer for first-person models.
* Weapon animation alias resolver.
* Weapon event timeline for draw, fire, reload, melee, grenade release, shell
  eject and muzzle flash, with source-confidence metadata.
* Audio and effect orchestration boundaries.

**Excludes:**

* Damage, armor and full combat model.
* Full weapon catalog completion beyond the pilot set unless inspection proves
  the mappings.
* Per-weapon model scale/position tuning as the primary fix for incorrect
  world/viewmodel FOV or unit-scale contracts.
* BSP runtime/map collision implementation beyond scanner coverage.

**Acceptance criteria:**

* `VIEWMODEL_WORLD_PROFILE.md` source values exist in config or a profile
  resource and profile smoke covers scale, coordinate determinant, eye heights,
  FOV derivation, `KEEP_HEIGHT`, anti-`58.7155` and no per-weapon transform keys.
* The GoldSrc renderable adapter reports real `goldsrc-godot` API capabilities
  and keeps attachments/sockets/MDL events marked as requiring an OpenStrike MDL
  reader or upstream API until verified.
* The manual preflight tool can inspect and, when the vendored
  `goldsrc-godot` dependency is enabled for the current platform, visually load
  a pilot real `v_*.mdl` through the locked profile without printing local paths
  or committing asset bytes.
* Coverage status smoke proves the generated schema/document sections are in
  sync with `gen/coverage_status_matrix.json`, validates status fixtures and
  directly asserts the verified/absence/provenance invariants.
* Weapon/viewmodel code consumes semantic IDs and atlas-backed contracts, not
  direct `models/*.mdl`, `sprites/*.spr` or `sound/*.wav` paths.
* Scanner/inspection output produces reviewable diagnostics for actual local MDL
  sequences/durations, model roles, HUD candidates, audio, sprite/effect and
  map coverage, clearly marking `verified`, `manual_unverified` and `unknown`.
* A weapon can be deployed, fired and reloaded through semantic events.
* Knife primary/secondary and grenade select/throw/switch rules are represented
  as lifecycle states, even if the first runtime surface remains limited.
* Missing assets produce diagnostics and disabled features, not fake fallback meshes or sounds.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-07 Walkable BSP lab

**Goal:** Make the next manual test happen on a real GoldSrc BSP map, not a
custom greybox, so movement, scale, FOV, lighting and collision feedback are
evaluated in the environment OpenStrike must actually reproduce.

**Why before more gunplay tuning:** The project already proved that visual
weapon tests on a surrogate scene invite eye-balled offsets and scale tweaks.
The narrower PR-07 target is a local `de_dust2`-style BSP walk test with
telemetry. That gives reviewers and manual testers evidence about map loading,
spawn selection, imported collision, floor/wall contacts and movement feel
before weapons are judged in a non-CS space.

**Includes:**

* `OpenStrikeGoldSrcBspRuntimeProvider` capability reporting for
  `alanfischer/goldsrc-godot` BSP/WAD loading.
* Real local BSP loading through the existing GoldSrc VFS, without committing
  `.bsp`, `.wad` or local config files.
* Referenced WAD discovery from BSP metadata so map-specific texture archives
  such as `cs_dust.wad` are loaded instead of relying only on common WADs.
* Entity metadata inspection, class counts and `info_player_*` spawn discovery.
* A manual `bsp_walkable_lab` command that loads `maps/de_dust2.bsp`, spawns a
  first-person `CharacterBody3D`, applies the shared world profile FOV/scale and
  uses CS cvar-scaled movement values with a 250 ups lab maxspeed for a
  no-weapon walkable test.
* Runtime disabling of trigger-like/non-solid brush collisions such as
  buyzones, bomb targets and illusionary brushes so the lab does not treat CS
  trigger volumes as walls.
* JSONL per-tick trace and summary output under `user://telemetry/bsp_walkable/`
  containing map path, collision source, movement input/state, speed, floor
  normals, slide contacts and step-up attempts.
* Smoke coverage proving the BSP provider does not claim GoldSrc clipnode,
  hull-size or hull-trace support before those APIs exist.

**Excludes:**

* Full GoldSrc BSP reader, clipnode traversal or hull trace parity.
* PVS optimization beyond capability reporting.
* Interactive map entities, bombsites, buyzones, doors, breakables, water,
  ladders, soundscape, material-aware footsteps, decals or weapon combat.
* Treating `godot_scene_collision` as final CS 1.6 collision parity.

**Acceptance criteria:**

* The provider reports BSP scene loading, imported scene collision, PVS and WAD
  capabilities honestly and marks clipnodes/hull trace as requiring an
  OpenStrike BSP reader.
* A local `maps/de_dust2.bsp` load smoke can resolve WADs, build the map, count
  entity/spawn metadata, report referenced WADs and confirm imported collision
  shapes.
* A manual tester can run the BSP walkable lab, move/jump/duck around the real
  map in fullscreen, see the local GoldSrc skybox, hear basic movement
  footsteps/jump/landing sounds and quit with trace/summary files written to
  `user://telemetry/`.
* Documentation and changelog explain that PR-07 temporarily prioritizes
  real-map validation over further greybox/weapon tuning.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-07.1 Runtime spine cleanup

**Goal:** Close the architecture and release-risk gaps opened by the useful
PR-07 BSP lab without adding gameplay features.

**Includes:**

* Dirty/tainted lab policy, taint ledger and public open-source exit gate docs.
* A BSP reader inventory report proving whether `addons/hl_core`,
  `bsp_reader.gd`, `bsp_clipnode.gd`, `trace_hull` or `point_contents` exist
  in the current repository.
* Shared production-owned movement math helper used by both
  `CSMovementSimulator` and the BSP walkable lab, so the lab no longer owns
  duplicate acceleration/friction/maxvelocity equations.
* Documentation that `goldsrc-godot` is an accepted pre-release risk with no
  license file in the vendored snapshot, and that `godot_scene_collision`
  remains a temporary non-parity backend.
* A taint scope smoke gate.

**Excludes:**

* TraceBackend, ClipnodeTraceBackend, box trace or BSP reader implementation.
* Weapon loop, HUD, economy, buy menu, LocalGameServer, bots or round logic.
* A large PlayerMoveService migration.

**Acceptance criteria:**

* BSP lab still runs and writes telemetry.
* Movement equations are no longer duplicated in the BSP lab runner.
* PR-04A air acceleration behavior remains covered by movement smoke.
* `addons/hl_core` / OpenStrike-owned BSP reader absence or presence is
  recorded in `docs/test_reports/`.
* `godot_scene_collision` is documented as temporary non-parity.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-07.2 TraceBackend and MapEntityIndex

**Goal:** Put a narrow collision/query boundary and map-entity semantic index
between the PR-07 walkable lab and later gameplay work, without implementing a
new BSP reader or weapon loop.

**Why before PR-08:** The walkable lab already proved that real BSP maps are
useful, but its first version still knew entity collision policy directly and
reported imported scene collision as a single string. Before server/gameplay
systems consume map state, OpenStrike needs an explicit backend contract that
can be replaced by a GoldSrc clipnode implementation later, plus an entity
index that owns spawn, buyzone, bomb target, illusionary and trigger-like
classification.

**Includes:**

* Minimal `OpenStrikeTraceBackend` contract with `trace_ray`, `trace_hull`,
  `point_contents` and capability reporting.
* `OpenStrikeGodotSceneTraceBackend` as a temporary non-parity backend for
  imported Godot scene collision. It supports ray queries only when a `World3D`
  is provided and keeps `trace_hull` / `point_contents` marked as requiring an
  OpenStrike BSP reader.
* `OpenStrikeMapEntityIndex` for imported scene entity metadata, spawn
  selection, buyzone/bomb target/illusionary/trigger classification and
  player-collision policy.
* BSP walkable lab telemetry that records backend source, confidence and
  `goldsrc_parity=false`, and consumes `MapEntityIndex` instead of hardcoding
  entity collision truth in the runner.
* Smoke checks for the trace backend contract and entity-index classification.

**Excludes:**

* OpenStrike-owned BSP reader, clipnode traversal, `ClipnodeTraceBackend`,
  box trace or GoldSrc hull-trace parity.
* Weapon loop, HUD, economy, buy menu, LocalGameServer, bots or round logic.
* Contact movement golden tests on `godot_scene_collision`.

**Acceptance criteria:**

* `godot_scene_collision` remains explicitly marked as temporary non-parity
  with unverified confidence.
* `trace_hull` and `point_contents` exist as API boundaries but do not fake
  support before a BSP reader exists.
* The BSP lab runner no longer owns the list of non-blocking entity classes.
* Trace summaries include backend source/confidence and map entity index
  reports for later manual-test analysis.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-08A Local game runtime skeleton

**Goal:** Add the first server-authoritative local runtime owner before weapon
or HUD work starts using dev-lab state directly.

**Why before full PR-08:** PR-07 through PR-07.2 made real BSP maps testable
and exposed spawn/entity/collision boundaries. The next step should create a
small game-layer session/tick/snapshot contract so future weapon and round
work has an authoritative owner, but without implementing combat, economy or
full round rules in the same PR.

**Includes:**

* Pure `src/game/runtime` data/service objects for local session, player slot,
  user command, round state and snapshot.
* Fixed-tick local session stepping independent from render framerate.
* Command queue acceptance/rejection for known player IDs.
* Team-aware spawn assignment from `OpenStrikeMapEntityIndex` snapshots.
* Smoke coverage with synthetic entity metadata.

**Excludes:**

* Weapon state, firing, damage, HUD, economy, buy menu, bots and networking.
* Full round win conditions, freeze-time timers or map objective logic.
* Direct map loading or dev-lab dependencies from `src/game/runtime`.

**Acceptance criteria:**

* A local session can add players, start a round, assign team-priority spawns,
  step fixed ticks and emit a deterministic snapshot.
* Runtime code remains in `src/game` and does not load GoldSrc assets, scenes
  or dev-lab scripts directly.
* `scripts/run_smoke_checks.sh`, `scripts/check_no_forbidden_assets.sh` and
  `git diff --check` pass.

## PR-08A.1 Runtime spawn descriptors cleanup

**Goal:** Finish the runtime spawn-descriptor boundary from
`docs/COMPACT_PR_TASK_PACKETS.md`.

**Includes:**

* `OpenStrikeMapEntityIndex.spawn_descriptors_for_classes()` returns pure
  `classname`, `position`, `yaw`, `origin`, `angles` and `source` facts.
* `OpenStrikeLocalGameSession` consumes spawn descriptors only.
* Runtime smoke uses a descriptor-only index and does not require `Node3D`.

**Excludes:**

* Movement integration, weapon logic, TraceBackend changes and BSP reader work.

**Acceptance criteria:**

* `src/game/runtime` does not read `entry["node"]` or require `Node3D`.
* CT/T/unassigned spawn priority still works.
* Existing smoke checks pass.

## Runtime spine packet order

For the GoldSrc runtime spine, follow `docs/COMPACT_PR_TASK_PACKETS.md` in
order and do not pull neighboring packet scope forward. PR-08B is the
synthetic BSP30 reader/clipnode trace proof described in
`docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md`; after that, run the narrow
PR-08B.1 real-BSP Contract A diagnostic, then continue with PR-08C backend
capability integration, not runtime movement integration.

## PR-08B BSP30 collision vertical slice

**Goal:** Add the first OpenStrike-owned BSP30 collision reader proof with a
minimal synthetic clipnode hull trace.

**Includes:**

* Typed BSP30 header/lump parsing for 15 lump entries.
* Collision-relevant lump parsing for planes, clipnodes and GoldSrc 64-byte
  models with `headnode[4]`.
* `OpenStrikeBspClipnodeTraceBackend.trace_hull()` for model 0 synthetic
  point and standing hull fixtures.
* Synthetic smoke coverage for point hull, standing hull, start solid, free
  trace, invalid planenum, invalid child, empty clipnodes and Source-style
  48-byte model rejection.

**Excludes:**

* PMove, `PlayerMoveService`, `LocalGameSession` movement, weapons, HUD,
  economy, bots, real-map golden tests, fence texture pass-through, moving
  brush models and WAD/miptexture parsing.

**Acceptance criteria:**

* `bsp30_clipnode_trace_smoke.gd` passes and is part of
  `scripts/run_smoke_checks.sh`.
* No Valve assets or real `.bsp` files are committed.
* `OpenStrikeGodotSceneTraceBackend` remains temporary non-parity.
* The hull-extent contract decision is recorded in `docs/DECISIONS.md`.

## PR-08B.1 Real BSP Contract A diagnostic

**Goal:** Check the PR-08B synthetic hull-extent Contract A against sanitized
facts from a real local BSP30 map without promoting real-map collision
authority.

**Includes:**

* Opt-in headless diagnostic command for a local licensed BSP such as
  `maps/de_dust2.bsp`.
* Loading through `OpenStrikeAssetManager` and GoldSrc VFS into
  `OpenStrikeBspMapResource`.
* Sanitized output for BSP version, collision-relevant lump counts, model-0
  `headnode[0..3]`, reachable standing/duck clipnode summaries and reader
  diagnostics.
* Synthetic `user://` smoke mode wired into shared checks.
* Test report and decision update that keep Contract A scoped correctly.

**Excludes:**

* Real BSP files, extracted lumps, local absolute paths, committed telemetry or
  real-map contact goldens.
* PMove, `PlayerMoveService`, `LocalGameSession` movement, backend switching,
  weapon loop, HUD, economy, bots or networking.

**Acceptance criteria:**

* The diagnostic can inspect a licensed local BSP when a local config exists.
* CI validates the tool through synthetic fixtures only.
* Contract A is not promoted beyond PR-08B synthetic fixtures unless
  contact-level real-map evidence proves that plane-space contract.

## PR-08C Clipnode backend capability integration

**Goal:** Make the synthetic BSP clipnode backend selectable behind the
existing `OpenStrikeTraceBackend` boundary for dev/smoke use, without using it
for player movement.

**Includes:**

* Dev-only backend selector for `godot_scene_collision` and the synthetic BSP
  clipnode backend.
* Shared trace-result smoke coverage for both selectable backends.
* Capability checks that preserve Godot scene collision as temporary
  non-parity and the BSP backend as synthetic-only.
* BSP `point_contents()` unsupported/deferred reporting that keeps the API
  shape and backend identity clear.

**Excludes:**

* PMove, `PlayerMoveService`, `LocalGameSession` movement, weapon loop, HUD,
  economy, bots, WAD/miptexture parsing, real-map contact goldens and a
  production backend switch.

**Acceptance criteria:**

* Both selectable backends expose the same trace-result fields.
* Godot scene collision reports `godot_collision_unverified`.
* The BSP clipnode backend reports limited synthetic support and does not use
  the real-BSP Contract A diagnostic to claim map collision authority.

## PR-08D Local BSP typed-load inspection reconciliation

**Goal:** Close the original local typed-load inspection packet after PR-08B.1
pulled its necessary implementation forward for the Contract A diagnostic.

**Result:** No additional code packet remains for the original PR-08D
acceptance criteria. `src/dev/tools/bsp30_real_map_contract_a_inspect.gd`
already loads a licensed BSP through the GoldSrc VFS into
`OpenStrikeBspMapResource`, reports version/lump counts/model-0 headnodes and
has CI-safe synthetic smoke coverage. The local `de_dust2` report records the
model-0 headnode facts without committing map bytes or local paths.

**Next:** Continue with PR-08E player state and command model before any
movement algorithm, runtime movement integration or gameplay features.

## PR-08E Player state and command model

**Goal:** Add pure player movement state, command and result data types for
future PMove work.

**Includes:**

* `OpenStrikePlayerState` with origin, velocity, view angles, duck/ground state,
  flags and last trace summary.
* `OpenStrikePlayerMoveCommand` with forward/side movement, jump/duck intent,
  view angles and frametime.
* `OpenStrikePlayerMoveResult` with resulting state, source command, trace
  summary and diagnostics.
* Smoke coverage for defaults, dictionary roundtrips and no `CharacterBody3D`
  dependency.

**Excludes:**

* Movement algorithms, `PlayerMoveService`, trace-slide contact movement,
  LocalGameSession integration, weapons, HUD, economy, bots and real-map
  contact goldens.

**Acceptance criteria:**

* The new types serialize to dictionaries and roundtrip through dictionaries.
* The smoke test proves defaults and keeps the new data layer free of Godot
  character-controller dependencies.

## PR-08F PlayerMoveService free-volume movement

**Goal:** Create `OpenStrikePlayerMoveService` over existing movement math for
backend-independent movement before contact solving.

**Includes:**

* `src/game/player/player_move_service.gd`.
* Conversion between PR-08E player DTOs and the existing cvar-backed movement
  simulator/math.
* Friction, ground acceleration, air acceleration, jump impulse, gravity,
  component maxvelocity and duck hull metadata through existing movement
  contracts.
* Trace backend capability metadata as a placeholder only.
* Smoke coverage proving service-driven ground acceleration and air-strafe
  gain while guarding against `CharacterBody3D`, `move_and_slide` and
  `trace_hull` use.

**Excludes:**

* Trace-slide contact movement, step-up, ramps, edgefriction, real-map contact
  goldens, `LocalGameSession` movement integration, weapons, HUD, economy and
  bots.

**Acceptance criteria:**

* Existing free-volume movement behavior can be driven through
  `OpenStrikePlayerMoveService`.
* The PR does not duplicate acceleration/friction equations outside the
  existing movement core.
* No authoritative Godot character controller or contact trace is introduced.

## PR-08G PlayerMoveService contact loop on synthetic backend

**Goal:** Add a minimal trace-slide contact loop through the synthetic BSP
clipnode backend.

**Includes:**

* Synthetic-BSP-only contact movement in
  `src/game/player/player_move_service.gd`.
* Up to four `trace_hull` iterations per move when the selected backend reports
  `goldsrc_hull_trace` with synthetic fixture support.
* Stop on clear trace fraction and slide velocity by the hit plane normal when
  blocked.
* Contact summaries in `OpenStrikePlayerMoveResult.trace_summary`.
* Smoke coverage for synthetic wall blocking, clear-space movement and Godot
  scene collision remaining telemetry-only for contact movement.

**Excludes:**

* Step-up, edgefriction, real-map contact goldens, Godot backend contact
  goldens, `LocalGameSession` movement integration, weapons, HUD, economy and
  bots.

**Acceptance criteria:**

* A synthetic wall stops player movement through the BSP clipnode backend.
* Synthetic open space moves freely.
* Contact golden checks use the BSP backend only.
* Godot contact remains telemetry-only/non-golden.

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
