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
  `goldsrc-godot` installed may run
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
