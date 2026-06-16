# Current Context Contract

Last updated: 2026-06-16

## 1. Project / topic

OpenStrike is a Godot-based reimplementation of Counter-Strike 1.6 that reads
assets from a user's local licensed GoldSrc installation. The project is in the
runtime-spine phase: local input is being routed through an authoritative
runtime session, movement service, trace backend boundary and snapshot
presentation.

## 2. Current accepted decisions

* The repository must not contain Valve assets, extracted asset caches, local
  user paths, telemetry dumps or committed `local_goldsrc.json`.
* External engines and SDKs may be studied for behavior and public constants,
  but their source code must not be copied or translated into OpenStrike.
* Core/game/presentation/dev boundaries are binding:
  `src/core` owns reusable runtime services, `src/game` owns authoritative
  simulation, `src/presentation` owns UI/viewmodel/audio/effects, and
  `src/dev` owns labs and telemetry.
* Gameplay authority must live in the game/runtime layer even for local solo
  play. Presentation and dev labs consume snapshots; they do not own gameplay
  state.
* `goldsrc-godot` is an accepted pre-release dependency under `addons/goldsrc/`
  for presentation/importer work. It remains a dependency risk because the
  vendored snapshot has no license file; public release/package must revisit it.
* `godot_scene_collision` is temporary non-parity. It must not be described as
  GoldSrc hull trace or real clipnode collision parity.
* PR-08B created the first OpenStrike-owned synthetic BSP30 collision reader and
  synthetic clipnode trace backend.
* PR-08B.1 found sanitized real-map evidence that real BSP30 model 0 has
  distinct standing and duck clipnode headnodes. PR-08B Contract A therefore
  remains synthetic-only and must not be promoted to real-map clipnodes.
* PR-08F through PR-08H built `OpenStrikePlayerMoveService` with free-volume
  movement, synthetic trace-slide contact, synthetic step-up and duck-hull
  behavior.
* PR-09A connected `OpenStrikeLocalGameSession` to
  `OpenStrikePlayerMoveService`: player slots own movement state, user commands
  convert to PMove-facing commands and snapshots expose movement state.
* PR-09B is merged through PR #28: the BSP walkable lab now creates a runtime
  session, queues `OpenStrikeUserCommand` input and follows runtime snapshots.
  This did not claim real-map wall-contact parity.
* PR #30 is merged and added the PR-09C and PR-09D plan packets.
* Phase 4 / PR-10A weapon runtime is closed until PR-09C and PR-09D complete
  the real-map runtime collision and telemetry gate.
* Non-trivial project work starts with a compact Task Packet and explicit
  Assumptions per `docs/agent_context_hygiene.md`.
* Every implementation PR updates `CHANGELOG.md`. Documentation/process PRs
  update the changelog when they affect workflow, routing or implementation
  order.

## 3. Deprecated / rejected / historical decisions

* Do not continue ReadyToStrike-style tuning of weapon model offsets or FOV by
  eye in greybox scenes.
* Do not treat `docs/archive/` as an active source of truth. It is historical
  reference only.
* Do not start weapon, HUD, economy, bots, networking or round-logic work before
  the current runtime-spine packet allows it.
* Do not treat imported Godot scene collision as a GoldSrc hull/clipnode
  backend.
* Do not grow gameplay authority inside dev labs, presentation nodes or
  `CharacterBody3D` controllers.
* Do not fake missing assets with placeholder meshes, sounds, sprites or maps.
* Do not make CI claim `local_verified` real asset coverage; CI uses synthetic
  fixtures and local licensed installs remain opt-in.

## 4. Current architecture / state

* `src/core/assets/` contains local GoldSrc config, VFS, semantic asset
  manifests/provider contracts and diagnostics.
* `src/core/maps/goldsrc_bsp_runtime_provider.gd` loads local BSP maps through
  `goldsrc-godot` for presentation/importer use and reports capability gaps
  honestly.
* `src/core/maps/map_entity_index.gd` classifies imported BSP entity metadata
  and exposes sanitized spawn descriptors.
* `src/core/collision/` defines the trace backend boundary and the temporary
  `OpenStrikeGodotSceneTraceBackend`.
* `src/core/bsp/` contains the OpenStrike-owned BSP30 synthetic collision
  reader slice and limited clipnode trace backend. It is not yet a real-map
  gameplay collision authority.
* `src/game/movement/` contains deterministic cvar-backed movement simulation
  and shared movement math.
* `src/game/player/` contains PMove-facing state/command/result DTOs and
  `OpenStrikePlayerMoveService`.
* `src/game/runtime/` contains `OpenStrikeLocalGameSession`,
  `OpenStrikePlayerSlot`, `OpenStrikeUserCommand`, `OpenStrikeRoundState` and
  `OpenStrikeGameSnapshot`.
* `src/dev/labs/bsp_walkable/` is now a runtime snapshot consumer for manual BSP
  testing. The latest known real-map runtime telemetry still reports
  `movement_state.last_trace_summary.mode=free_volume`, so real-map wall
  contact is not verified.
* `docs/test_reports/` contains sanitized reports for BSP reader inventory,
  real-BSP Contract A, trace backend/entity index and PR-09B runtime snapshot
  testing.

## 5. Active constraints

* Legal: no Valve assets, no local absolute paths, no copied Valve/HLSDK/Xash3D
  code, no GPL code reuse.
* Architecture: runtime simulation must remain server-authoritative and must
  not import dev labs or presentation.
* Current scope: PR-09C.0 is docs-only source-of-truth repair. It must not touch
  runtime, movement, BSP collision, telemetry, weapons, HUD, economy, bots or
  round logic.
* Current routing: after PR-09C.0 merges, the next implementation packet is
  PR-09C real-map clipnode trace (Contract B), then PR-09D walkable telemetry
  invariants.
* Testing before PR: run `scripts/run_smoke_checks.sh`,
  `scripts/check_no_forbidden_assets.sh` and `git diff --check`.

## 6. Open questions / risks

* Real-map clipnode tracing is not implemented yet. The BSP backend still has
  synthetic-only confidence/capabilities.
* PR-09C must introduce honest real-BSP Contract B capabilities/confidence and
  must not apply PR-08B runtime plane offsets to real clipnodes.
* Runtime fixed-tick movement has known follow-up risks from issue #31:
  no-command ticks can freeze movement state, and backlog/duplicate commands can
  apply multiple full movement steps in one tick. These are not fixed in
  PR-09C.0.
* PR-09D telemetry would be misleading until PR-09C and fixed-tick honesty are
  addressed.
* `goldsrc-godot` license status remains unresolved for public redistribution.

## 7. Immediate next task

Complete PR-09C.0 docs source-of-truth repair:

* make `AGENTS.md` and `docs/README.md` agree on active docs, archive/future
  routing and current project state;
* keep current workflow docs outside `docs/archive/`;
* record that PR-09A/09B and PR #30 are merged;
* make Phase 4 / PR-10A explicitly closed until PR-09C/09D complete;
* add a changelog entry and run the standard checks.

After PR-09C.0 merges, continue with PR-09C, not PR-10A.

## 8. Definition of done for the next task

* Active paths from `AGENTS.md` exist or intentionally point to `docs/future/`
  for deferred Phase 4+ material.
* `docs/README.md`, `AGENTS.md`, `docs/current_context_contract.md` and
  `docs/COMPACT_PR_TASK_PACKETS.md` agree on the next packet and Phase 4 gate.
* `docs/archive/` is not presented as an active source of truth.
* `CHANGELOG.md` records the workflow/routing repair.
* Smoke checks, forbidden asset scan and whitespace checks pass.

## 9. Sources of truth

* `AGENTS.md`
* `docs/README.md`
* `docs/agent_context_hygiene.md`
* `docs/current_context_contract.md`
* `docs/COMPACT_PR_TASK_PACKETS.md`
* `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md`
* `docs/DECISIONS.md`
* `docs/TESTING.md`
* `docs/GDSCRIPT_AGENT_NOTES.md`
* `CHANGELOG.md`
* Current git state and GitHub issue/PR state.

Deferred/current-only-when-needed sources:

* `docs/future/VIEWMODEL_WORLD_PROFILE.md`
* `docs/future/VIEWMODEL_MANUAL_PREFLIGHT.md`
* `docs/future/CS16_ASSET_ORCHESTRATION_ATLAS.md`
* `docs/future/COVERAGE_STATUS_CONTRACT.md`

Historical reference only:

* `docs/archive/`

## 10. Instructions to the next agent

* Start by forming a Task Packet and explicit Assumptions.
* Do not rely on stale chat history over this contract or repository files.
* Verify local repository state and GitHub state before making code claims.
* Follow only the first unclosed packet in
  `docs/COMPACT_PR_TASK_PACKETS.md`.
* Do not start PR-10A or Phase 4 work until PR-09C and PR-09D complete.
* If new evidence contradicts this contract, update the Task Packet before
  continuing and update this contract in the same PR if project state changes.
