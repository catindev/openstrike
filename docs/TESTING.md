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

## Current (PR-04D) checklist

For research catalog and dev-lab methodology changes, perform the following
checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh` even when the PR is
  documentation-only, to keep the branch integration-safe.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check`.
* **Source weighting:** Confirm that new external references are classified in
  `SOURCE_CATALOG.md` and do not replace primary GoldSrc/CS 1.6 references.
* **Lab evidence rule:** Confirm that subjective feel claims are linked to
  telemetry, smoke coverage, debug overlays or a planned dev lab through
  `DEV_LABS_METHODOLOGY.md`.
* **Changelog coverage:** Confirm that `CHANGELOG.md` contains an English entry
  explaining any plan-order change.

## Current (PR-04E) checklist

For asset/config contract cleanup and the `sv_maxvelocity` movement-contract
exception, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This must include
  the asset VFS, cvar/config and movement smoke tests.
* **Asset VFS contract:** Confirm that `asset_vfs_smoke.gd` covers
  `half_life_dir`-derived roots, explicit `cstrike_dir + valve_dir` roots
  without `half_life_dir`, and invalid config diagnostics for empty, partial,
  missing and non-object configs.
* **Movement cvar contract:** Confirm that long-run air-strafe smoke uses an
  independent expected calculation with component-wise `sv_maxvelocity`
  semantics, not `min(horizontal_speed, sv_maxvelocity)`.
* **Short air-strafe oracle:** Confirm that the 100-frame air-strafe smoke keeps
  the closed-form `sqrt(max_speed^2 + air_cap^2 * N)` oracle because
  `sv_maxvelocity` is not reached in that case.
* **Ground overlimit input:** Confirm that an over-limit grounded input velocity
  is clamped before friction and before position integration.
* **Deferred cvar honesty:** Confirm that `edgefriction` is documented as
  loaded but deferred until edge-trace movement work exists.
* **Class-name hygiene:** Confirm that generic public core classes use the
  `OpenStrike*` prefix while `CSMovement*` names are intentionally unchanged.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` explains why PR-04E was
  inserted before asset providers.

## Current (PR-05) checklist

For GoldSrc asset provider contract changes, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  asset provider smoke test in addition to project, Asset VFS, cvar/config and
  movement checks.
* **Asset provider contract smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/asset_provider_smoke.gd`
  when iterating locally on provider code. The smoke test must use synthetic
  files created under `user://`, not committed `.mdl`, `.spr` or `.wav`
  fixtures.
* **Semantic request boundary:** Confirm that presentation-facing code can
  request viewmodel, sprite and sound assets by semantic IDs while physical
  GoldSrc paths remain in manifest/provider data only.
* **Diagnostics:** Confirm that missing semantic IDs, missing physical files and
  type mismatches produce structured diagnostics.
* **No parser shortcut:** Confirm that PR-05 does not add placeholder
  resources or incomplete MDL/SPR/WAV decoders in production paths.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` records the provider
  contract and explains why real CS asset mappings remain separate.

## Current (PR-05A) checklist

For asset manifest inspection changes, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  manifest inspection smoke test after provider contract smoke.
* **Manifest inspection smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/asset_manifest_inspection_smoke.gd`
  when iterating locally on inspection/report code.
* **No byte loading:** Confirm that inspection methods resolve through VFS but
  do not populate `raw_bytes` or require MDL/SPR/WAV decoding.
* **Report semantics:** Confirm that reports distinguish resolved assets,
  missing physical files and invalid manifest/provider entries.
* **Synthetic fixtures only:** Confirm that smoke tests create temporary files
  under `user://` and do not commit `.mdl`, `.spr` or `.wav` fixtures.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` records why PR-05A was
  inserted before PR-06.

## Current (PR-05B) checklist

For pilot weapon asset catalog changes, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  pilot asset catalog smoke after manifest inspection.
* **Asset catalog smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/asset_catalog_smoke.gd`
  when iterating locally on catalog data or semantic IDs.
* **Synthetic fixtures only:** Confirm that catalog smoke creates temporary
  synthetic files under `user://` for every catalog path and does not commit
  `.mdl`, `.spr` or `.wav` fixtures.
* **Catalog hygiene:** Confirm that `data/assets/cs16_pilot_weapon_assets.json`
  contains relative GoldSrc paths only, no local absolute paths and no extracted
  asset content.
* **Source classification:** Confirm that `SOURCE_CATALOG.md` records local
  licensed filename inspection as path-availability verification only.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` records why PR-05B was
  inserted before PR-06.

## Current (PR-05C) checklist

For manifest contract hardening changes, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  manifest contract negative cases through the manifest inspection smoke.
* **Manifest inspection smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/asset_manifest_inspection_smoke.gd`
  when iterating locally on manifest validation.
* **Negative contract cases:** Confirm smoke coverage for unsupported provider,
  unsupported type, type/extension mismatch, parent traversal, absolute path
  and backslash path.
* **Metadata retention:** Confirm that manifest metadata appears in
  `OpenStrikeAssetManifest.to_dictionary()` and inspection report output.
* **Pilot catalog compatibility:** Confirm that
  `data/assets/cs16_pilot_weapon_assets.json` still passes the hardened
  contract through `asset_catalog_smoke.gd`.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` records why PR-05C was
  inserted before PR-06.

## Current (PR-05D) checklist

For local asset catalog inspection tool changes, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  local catalog inspection tool in `--synthetic-smoke` mode, so CI does not
  require a local Counter-Strike installation.
* **Local tool smoke:** Run
  `Godot --headless --path . --script res://src/dev/tools/asset_catalog_inspect_local.gd -- --synthetic-smoke --summary-only`
  when iterating on the tool.
* **Real install preflight:** Developers with a licensed local installation may
  run
  `Godot --headless --path . --script res://src/dev/tools/asset_catalog_inspect_local.gd -- --config=user://local_goldsrc.json --catalog=res://data/assets/cs16_pilot_weapon_assets.json`.
  This is opt-in and must not become a required CI gate.
* **Report redaction:** Confirm tool output does not expose local absolute
  paths, `resolved_path`, VFS roots or VFS `tried` paths.
* **Provider boundary:** Confirm the tool uses `OpenStrikeAssetManager` and
  manifest inspection rather than direct filesystem path checks.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` records why PR-05D was
  inserted before PR-06.

## Current (PR-06) checklist

For weapon viewmodel orchestration profile, adapter and coverage-status contract
changes, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  coverage status, viewmodel/world profile and GoldSrc renderable adapter
  smoke checks after the local catalog inspection tool smoke.
* **Viewmodel/world profile smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/viewmodel_world_profile_smoke.gd`
  when iterating on unit scale, coordinate mapping, eye height, FOV or
  per-weapon transform lint.
* **GoldSrc renderable adapter smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/goldsrc_renderable_adapter_smoke.gd`
  when iterating on the `alanfischer/goldsrc-godot` adapter boundary.
* **Manual preflight capability smoke:** Run
  `Godot --headless --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --capability-smoke`
  to confirm the local manual tool reports extension availability honestly
  without requiring real assets in CI.
* **Local visual preflight:** Developers with a licensed local installation and
  a matching vendored `goldsrc-godot` native library may run
  `scripts/bootstrap_gdextensions.sh` and then
  `Godot --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --asset-id=weapon.ak47.viewmodel --visual`.
  This is opt-in and must not become a CI gate.
* **Coverage status smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/coverage_status_smoke.gd`
  when iterating on coverage status stages, confidence values or generated
  artifacts.
* **Generated artifact check:** Run `python3 gen/generate.py --check` and
  confirm that `data/schemas/coverage_status.schema.json` and the generated
  sections in `docs/COVERAGE_STATUS_CONTRACT.md` match
  `gen/coverage_status_matrix.json`.
* **Single editable source:** Confirm that coverage status changes are made by
  editing only `gen/coverage_status_matrix.json` by hand, then regenerating
  schema and documentation with `gen/generate.py`.
* **Status invariants:** Confirm that smoke coverage rejects verified trust
  before parse, verified absence outside `source_missing`, and
  `hand_seeded`/`manual_unverified` outside semantic intent stages.
* **Local verification boundary:** Confirm that CI fixtures do not claim
  `local_verified` or `local_verified_absence` for real CS 1.6 assets. Those
  confidence states come only from local licensed-install scanner output, and
  that output must remain uncommitted.
* **No fake sockets/events:** Confirm that attachment/socket and MDL animation
  event capability remains `requires_openstrike_mdl_reader` until a loader API
  spike proves those fields are exposed.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` records the coverage
  status contract and why it was added before scanner/coverage report work.

## Current (PR-07) checklist

For the walkable BSP lab and real-map validation slice, perform the following
checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  GoldSrc BSP runtime provider smoke after the renderable adapter smoke.
* **BSP provider smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/goldsrc_bsp_runtime_provider_smoke.gd`
  when iterating on BSP capabilities. It must pass even when the native
  GDExtension is absent by reporting `extension_missing`.
* **BSP lab capability smoke:** Run
  `Godot --headless --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --capability-smoke`
  to confirm the manual lab's dependency contract without real assets.
* **Local BSP load smoke:** Developers with a licensed local installation may
  run `scripts/bootstrap_gdextensions.sh` and then
  `Godot --headless --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --load-smoke --map=maps/de_dust2.bsp`.
  This should report map-specific referenced WADs such as `cs_dust.wad` for
  `de_dust2`. It is opt-in and must not become a CI gate because CI does not
  have Valve assets.
* **Manual BSP walk test:** Developers with a licensed local installation may
  run
  `Godot --path . --script res://src/dev/labs/bsp_walkable/bsp_walkable_lab.gd -- --map=maps/de_dust2.bsp`.
  Controls are WASD, mouse look, Space jump, Ctrl/C duck, F2 mouse release and
  Cmd+Q or window close to quit. Esc is intentionally not bound to quit so
  accidental key presses do not end manual telemetry sessions. The manual lab
  opens fullscreen by default; add `--windowed` for windowed debugging.
  It should render local `gfx/env/<skyname>*` skybox faces when the BSP
  `worldspawn.skyname` is present, and play local `sound/player/pl_step*.wav`,
  `pl_jump*.wav` and `pl_jumpland2.wav` movement sounds.
* **Telemetry review:** After manual testing, inspect
  `user://telemetry/bsp_walkable/<session_id>/summary.json` and
  `trace.jsonl`. The trace should record
  `collision_source=godot_scene_collision`, movement input/state, floor
  normals, slide collisions, step-up attempts, movement audio events and speed
  in UPS. The summary should include `lab_max_speed_ups=250` for the no-weapon
  walkable lab, a report of disabled trigger-like brush collisions,
  `skybox.status=loaded` for `de_dust2`, and loaded movement WAV counts.
  After the trace/log review, write a report under `docs/test_reports/` with
  observations, telemetry facts, conclusions and next actions.
* **Collision honesty:** Confirm that manual/test output never describes the
  imported Godot scene collision as GoldSrc hull trace parity. Clipnodes,
  hull sizes and hull trace stay `requires_openstrike_bsp_reader`.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh` and
  confirm that no proprietary GoldSrc assets or local config files are tracked.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.
* **Changelog coverage:** Confirm that `CHANGELOG.md` explains why the next
  manual test moved to a real BSP map before more greybox/gunplay tuning.

## PR-07.1 runtime spine cleanup checklist

For cleanup work immediately after the walkable BSP lab, perform the following
checks:

* **Taint scope:** Run `scripts/check_taint_scope.sh`. It must pass when
  `addons/goldsrc/` is present and documented in `docs/TAINT_LEDGER.md`, and
  production paths must not import `src/dev/tainted`.
* **BSP reader inventory:** Confirm that
  `docs/test_reports/2026-06-15_bsp_reader_inventory.md` reflects the current
  repository state for `addons/hl_core`, `bsp_reader.gd`, `bsp_clipnode.gd`,
  `trace_hull`, `point_contents` and OpenStrike-owned BSP reader presence.
* **Movement ownership:** Confirm that
  `src/dev/labs/bsp_walkable/bsp_walkable_runner.gd` does not define local
  authoritative acceleration, friction or maxvelocity equations. It should
  consume production-owned movement math from `src/game/movement`.
* **Air acceleration:** Run the movement smoke through
  `scripts/run_smoke_checks.sh` and verify that PR-04A air acceleration remains
  green. Air acceleration must use full wishspeed for acceleration amount while
  capping only the add-speed target.
* **Collision honesty:** Keep `godot_scene_collision` documented as temporary
  non-parity. Do not add contact movement golden tests on the Godot collision
  backend.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh`.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.

## PR-07.2 TraceBackend and MapEntityIndex checklist

For the trace boundary and entity-index cleanup, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  trace backend and map entity index smoke checks after BSP provider smoke.
* **Trace backend smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/trace_backend_smoke.gd`
  when iterating on `src/core/collision`. It must prove
  `OpenStrikeGodotSceneTraceBackend` reports `godot_scene_collision`,
  unverified confidence, `goldsrc_parity=false`, and no fake `trace_hull` or
  `point_contents` support.
* **Map entity index smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/map_entity_index_smoke.gd`
  when iterating on imported entity classification. It must prove spawn
  priority and player-collision-disable policy for buyzones, bomb targets,
  illusionary and trigger-like entities.
* **BSP lab ownership:** Confirm
  `src/dev/labs/bsp_walkable/bsp_walkable_runner.gd` consumes
  `OpenStrikeMapEntityIndex` and no longer owns a hardcoded
  non-blocking-entity class list.
* **Telemetry contract:** Confirm the BSP lab summary and trace entries include
  backend source, confidence and `goldsrc_parity_collision=false`.
* **Collision honesty:** Do not add contact movement golden tests on
  `godot_scene_collision`; GoldSrc hull trace remains blocked on an
  OpenStrike-owned BSP reader.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh`.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.

## PR-08A local game runtime skeleton checklist

For the first server-authoritative local runtime skeleton, perform the
following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  local game session smoke after movement smoke.
* **Local game session smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/local_game_session_smoke.gd`
  when iterating on `src/game/runtime`. It must prove fixed-tick stepping,
  known-player command acceptance, unknown-player command rejection,
  deterministic snapshots and team-priority spawn assignment from a
  descriptor-only spawn index with no `Node3D` dependency.
* **Map entity index smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/map_entity_index_smoke.gd`
  when changing spawn extraction. It must prove spawn descriptors expose pure
  `classname`/`position`/`yaw`/`origin`/`angles`/`source` facts and do not leak
  scene nodes to game runtime consumers.
* **Layer boundary:** Confirm `src/game/runtime` does not import
  `src/dev/labs`, `src/presentation` or direct GoldSrc asset paths.
* **Scope boundary:** Confirm the PR does not add weapon firing, HUD, economy,
  buy menu, bots, networking or full round win conditions.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh`.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.

## PR-08B BSP30 collision vertical slice checklist

For the first OpenStrike-owned BSP30 collision reader proof, perform the
following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  synthetic BSP30 clipnode trace smoke after the trace-backend smoke.
* **BSP30 clipnode trace smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/bsp30_clipnode_trace_smoke.gd`
  when iterating on `src/core/bsp`. It must build synthetic BSP30 bytes in
  memory and prove point-hull hit, standing-hull hit, start-solid detection,
  free trace, malformed planenum/child diagnostics, empty clipnodes as
  non-solid and Source-style 48-byte model rejection.
* **Synthetic fixture only:** Confirm the PR commits no Valve `.bsp` files,
  extracted lumps or real-map golden traces. CI must not require a licensed
  local installation.
* **Scope boundary:** Confirm the PR does not add PMove, `PlayerMoveService`,
  `LocalGameSession` movement, weapon loop, HUD, economy, bots, fence texture
  pass-through, moving brush support, WAD/miptexture parsing or real-map
  contact goldens.
* **Trace boundary:** Confirm no duplicate `TraceBackend` or trace DTO classes
  are created. The BSP backend must use the existing
  `OpenStrikeTraceBackend` / `OpenStrikeCollisionTrace` contract.
* **Collision honesty:** Confirm `OpenStrikeGodotSceneTraceBackend` still
  reports `godot_scene_collision`, unverified confidence and
  `goldsrc_parity=false`.
* **Clean-room boundary:** Confirm no denylisted Xash3D/HLSDK source files were
  opened or copied while implementing matching BSP/collision modules.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh`.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.

## PR-08B.1 real BSP Contract A diagnostic checklist

For the local real-BSP hull-extent diagnostic, perform the following checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  Contract A diagnostic in `--synthetic-smoke --summary-only` mode, so CI does
  not require Valve assets.
* **Synthetic diagnostic smoke:** Run
  `Godot --headless --path . --script res://src/dev/tools/bsp30_real_map_contract_a_inspect.gd -- --synthetic-smoke --summary-only`
  when iterating on the tool.
* **Local real-BSP diagnostic:** Developers with a licensed local installation
  may run
  `Godot --headless --path . --script res://src/dev/tools/bsp30_real_map_contract_a_inspect.gd -- --config=user://local_goldsrc.json --map=maps/de_dust2.bsp`.
  This is opt-in and must not become a required CI gate.
* **Report redaction:** Confirm tool output does not expose local absolute
  paths, VFS roots, `resolved_path` or VFS `tried` paths. Committed reports may
  include sanitized relative map names and aggregate counts/headnodes only.
* **Contract honesty:** Confirm the report does not claim real-map contact
  parity or promote PR-08B runtime plane offsets beyond synthetic fixtures.
* **Scope boundary:** Confirm the PR does not add PMove,
  `PlayerMoveService`, `LocalGameSession` movement, weapon loop, HUD, economy,
  bots, WAD/miptexture parsing or a production backend switch.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh`.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.

## PR-08C Clipnode backend capability integration checklist

For the selectable trace-backend capability integration, perform the following
checks:

* **Godot smoke checks:** Run `scripts/run_smoke_checks.sh`. This includes the
  shared trace backend smoke after the original Godot backend smoke.
* **Shared trace backend smoke:** Run
  `Godot --headless --path . --script res://src/dev/smoke/trace_backend_shared_smoke.gd`
  when iterating on backend capabilities or trace-result fields.
* **Selector scope:** Confirm the backend selector lives only in dev/smoke or
  dev-lab paths and is not imported by `src/game`, production runtime or
  presentation.
* **Collision honesty:** Confirm `OpenStrikeGodotSceneTraceBackend` still
  reports `godot_scene_collision`, `godot_collision_unverified` and
  `goldsrc_parity=false`.
* **BSP scope:** Confirm `OpenStrikeBspClipnodeTraceBackend` still reports
  synthetic-only support and does not promote real-map Contact A behavior.
* **Point contents:** Confirm `point_contents()` remains unsupported/deferred
  for the BSP backend while preserving the API shape.
* **Scope boundary:** Confirm the PR does not add PMove,
  `PlayerMoveService`, `LocalGameSession` movement, weapon loop, HUD, economy,
  bots, WAD/miptexture parsing or a production backend switch.
* **Forbidden asset scan:** Run `scripts/check_no_forbidden_assets.sh`.
* **Whitespace check:** Run `git diff --check` and `git diff --cached --check`
  before pushing.

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
