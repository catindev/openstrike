# Current Context Contract

Last updated: 2026-06-16

## 1. Project / topic

OpenStrike is a Godot-based reimplementation of Counter-Strike 1.6 that reads
assets from a user's local licensed GoldSrc installation. The project is
currently building foundations for CS 1.6-like movement, asset loading,
viewmodel/map runtime and eventual gameplay authority.

## 2. Current accepted decisions

* The repository must not contain Valve assets, extracted asset caches, local
  user paths or committed `local_goldsrc.json`.
* External engines and SDKs may be studied for behavior and public constants,
  but their source code must not be copied.
* Core/game/presentation/dev boundaries are binding:
  `src/core` owns reusable runtime services, `src/game` owns authoritative
  simulation, `src/presentation` owns UI/viewmodel/audio/effects, and
  `src/dev` owns labs and telemetry.
* Local config/VFS, cvars and smoke gates are established before gameplay.
* Movement currently has a deterministic cvar-backed core and shared
  `CSMovementMath`, but not final GoldSrc collision, water, ladders, surfing
  or edgefriction traces.
* `alanfischer/goldsrc-godot` is vendored under `addons/goldsrc/` as an
  accepted pre-release dependency risk. The vendored snapshot has no license
  file; public release/package must revisit, replace or explicitly decide this
  dependency.
* PR-06 viewmodel runtime uses `goldsrc-godot` through OpenStrike adapters
  rather than project-owned MDL/SPR/WAV decoders.
* PR-07 validated real local BSP map loading through `goldsrc-godot` and a
  manual walkable lab before more greybox/weapon tuning.
* PR-07.2 added `OpenStrikeTraceBackend` and `OpenStrikeMapEntityIndex`.
  `godot_scene_collision` is temporary non-parity with unverified confidence;
  GoldSrc hull trace, clipnodes and `point_contents` still require an
  OpenStrike BSP reader or verified loader API.
* PR-08A added the first `src/game/runtime` local authoritative session
  skeleton: fixed ticks, player slots, user command acceptance, round-state
  skeleton data, team-aware spawn assignment from sanitized map descriptors and
  deterministic snapshots.
* PR-08A.1 completes the runtime spawn descriptor cleanup: runtime consumes
  pure spawn descriptors with `classname`, `position`, `yaw`, `origin`,
  `angles` and `source`, and does not require `Node3D`.
* PR-08B adds the first synthetic OpenStrike-owned BSP30 collision vertical
  slice: typed header/lump parsing for planes, clipnodes and GoldSrc 64-byte
  models, plus a limited synthetic `OpenStrikeBspClipnodeTraceBackend`.
* PR-08B.1 adds a local real-BSP Contract A diagnostic. A sanitized
  `maps/de_dust2.bsp` inspection found distinct model-0 standing and duck
  clipnode headnodes with non-empty reachable trees, so PR-08B runtime
  plane-offset Contract A remains synthetic-only and must not be promoted to
  real-map clipnodes without a later contact-level diagnostic.
* PR-08C adds dev/smoke-only trace backend selection for the temporary Godot
  scene backend and the synthetic BSP clipnode backend, plus shared trace-result
  smoke coverage. It does not connect movement, runtime sessions or
  presentation to the BSP backend.
* PR-08D reconciliation confirms the original local BSP typed-load inspection
  acceptance criteria were satisfied by PR-08B.1. No additional PR-08D
  implementation packet remains unless a new typed-load diagnostic is scoped.
* PR-08E adds pure `src/game/player` data types:
  `OpenStrikePlayerState`, `OpenStrikePlayerMoveCommand` and
  `OpenStrikePlayerMoveResult`, with dictionary roundtrip smoke coverage and no
  `CharacterBody3D` dependency.
* PR-08F adds `OpenStrikePlayerMoveService` as the first PMove-facing
  free-volume movement service. It delegates movement equations to the existing
  cvar-backed movement simulator/math and keeps trace backend data as metadata
  only; it does not add contact movement, step-up or runtime session movement
  integration.
* PR-08G adds a minimal synthetic-BSP-only trace-slide contact loop to
  `OpenStrikePlayerMoveService`: up to four hull traces, stop on clear
  fraction, slide velocity by plane normal and record contact summaries. Godot
  scene collision remains telemetry-only/non-golden for PMove contact.
* PR-08H adds first synthetic-only step and duck-hull contact behavior to
  `OpenStrikePlayerMoveService`: standing/duck hull selection, simple
  `sv_stepsize` step attempts and synthetic low-ceiling/stair smoke coverage.
  These checks do not promote backend Contract A numbers to real-map goldens.
* PR-09A connects `OpenStrikeLocalGameSession` to
  `OpenStrikePlayerMoveService`: player slots own movement state, user commands
  convert to PMove-facing commands, fixed ticks apply movement and snapshots
  expose origin, velocity, view angles, duck state, ground state and nested
  movement state.
* PR-09A commands carry raw forward/side axes plus view angles; the runtime
  movement layer resolves wish direction relative to command `view_yaw`.
* PR-09B is not yet implemented. It must not move the BSP walkable lab to
  runtime snapshots unless wall-blocking behavior is preserved through a
  lab-only collision bridge or an equivalent behavioral gate.
* `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md` and
  `docs/COMPACT_PR_TASK_PACKETS.md` define the accepted runtime-spine
  contracts, denylist and PR order. Follow only the current packet.
* Non-trivial project work starts with a compact Task Packet and explicit
  Assumptions per `docs/agent_context_hygiene.md`.
* Every implementation PR updates `CHANGELOG.md`; every user-assisted dev-lab
  run should be followed by trace/log analysis and a report under
  `docs/test_reports/`.

## 3. Deprecated / rejected / historical decisions

* Do not continue the ReadyToStrike-style approach of tuning weapon model
  offsets/FOV by eye in a greybox. OpenStrike restarted to avoid that path.
* Do not add project-owned MDL/SPR/WAV decoders before using the available
  `goldsrc-godot` adapter path, unless a reviewed capability gap requires it.
* Do not treat `godot_scene_collision` as GoldSrc hull/clipnode parity.
* Do not grow gameplay authority inside dev labs or presentation nodes.
* Do not fake missing assets with placeholder meshes, sounds, sprites or maps.
* Do not make CI claim `local_verified` real asset coverage; CI uses synthetic
  fixtures and local licensed installations remain opt-in.

## 4. Current architecture / state

After PR-09A, current runtime-spine state is the synthetic BSP30 collision
vertical slice plus synthetic-BSP trace-slide, step and duck-hull behavior in
the PMove-facing service, with local runtime sessions now applying
view-relative movement commands:

* `src/core/assets/` contains local GoldSrc config, VFS, semantic asset
  manifests/provider contracts and diagnostics.
* `src/core/maps/goldsrc_bsp_runtime_provider.gd` loads local BSP maps through
  `goldsrc-godot`, reports capabilities and keeps hull trace/clipnodes
  deferred.
* `src/core/bsp/` contains the synthetic BSP30 collision reader slice and
  limited clipnode trace backend. It is a clean OpenStrike-owned proof for
  synthetic buffers, not yet a real-map gameplay collision authority.
* `src/dev/tools/bsp30_real_map_contract_a_inspect.gd` provides an opt-in
  local typed-load diagnostic for licensed BSP30 maps. It reports sanitized
  reader/headnode/clipnode-tree facts and has a CI-safe synthetic smoke mode.
* `src/dev/smoke/trace_backend_dev_selector.gd` is a dev-only selector for
  backend smoke checks. It can create `godot_scene_collision` or a synthetic
  BSP clipnode backend behind the same trace boundary, but production runtime
  must not import it.
* `src/core/maps/map_entity_index.gd` classifies imported BSP entity metadata
  for spawns, buyzones, bomb targets, illusionary brushes, triggers and
  collision policy, and exposes sanitized spawn descriptors for runtime
  consumers.
* `src/core/collision/` defines the TraceBackend boundary and current
  `OpenStrikeGodotSceneTraceBackend`.
* `src/game/movement/` contains current deterministic movement simulation and
  smoke-tested math helpers.
* `src/game/player/` contains PMove-facing state/command/result DTOs plus
  `OpenStrikePlayerMoveService`. The service can drive backend-independent
  free-volume movement through existing movement contracts and can apply a
  synthetic-BSP trace-slide contact loop with first step-up and duck-hull
  behavior. It resolves command forward/side axes relative to `view_yaw`, but
  does not yet implement edgefriction or real-map contact goldens.
* `src/game/runtime/` contains `OpenStrikeLocalGameSession`,
  `OpenStrikePlayerSlot`, `OpenStrikeUserCommand`, `OpenStrikeRoundState` and
  `OpenStrikeGameSnapshot`. Runtime consumes sanitized spawn descriptors from
  `OpenStrikeMapEntityIndex`, applies `OpenStrikePlayerMoveService` during fixed
  ticks and must not read scene nodes directly.
* `src/presentation/viewmodel/` contains `OpenStrikeGoldSrcRenderableProvider`
  for `goldsrc-godot` viewmodel/sprite loading.
* `src/dev/labs/bsp_walkable/` contains the manual real-BSP walkable lab with
  telemetry under `user://telemetry/bsp_walkable/`. It still owns the dev-lab
  character-controller movement path so real BSP wall blocking is not regressed
  before PR-09B adds a runtime collision-safe replacement.
* `docs/test_reports/` contains persistent reports for BSP reader inventory,
  de_dust2 skybox/audio manual testing and TraceBackend/MapEntityIndex runner
  verification.

## 5. Active constraints

* Legal: no Valve assets, no local absolute paths, no copied Valve/HLSDK/Xash3D
  code, no GPL code reuse.
* Architecture: gameplay must be server-authoritative, even offline; gameplay
  must not load GoldSrc files directly.
* Process: every non-trivial task starts with a Task Packet and explicit
  Assumptions per `docs/agent_context_hygiene.md`.
* Process: read `AGENTS.md`, `docs/agent_context_hygiene.md` and this file
  before relying on chat history.
* Process: read profile docs before changing their areas:
  `CS_1_6_FEEL.md`, `VIEWMODEL_WORLD_PROFILE.md`,
  `CS16_ASSET_ORCHESTRATION_ATLAS.md`, `COVERAGE_STATUS_CONTRACT.md`,
  `TAINTED_LABS_POLICY.md`, `GDSCRIPT_AGENT_NOTES.md`, etc.
* Testing: run `scripts/run_smoke_checks.sh`,
  `scripts/check_no_forbidden_assets.sh` and `git diff --check` before PR.
* User preference: keep changes small, sequential, documented in English
  changelog entries and pushed as reviewable PRs.

## 6. Open questions / risks

* `goldsrc-godot` license is absent in the vendored snapshot; public
  redistribution remains blocked until resolved.
* The OpenStrike-owned BSP reader/clipnode backend is currently synthetic-only.
  Real local BSP typed-load inspection exists for sanitized diagnostics, but
  real-map contact traces and real-map collision authority are still future
  tasks.
* The local `de_dust2` Contract A diagnostic is evidence for distinct
  hull-specific clipnode trees, but it is not a contact golden and does not
  decide the final real-map plane-space trace contract.
* Real map collision currently uses imported Godot scene collision, useful for
  labs but not final CS 1.6 parity. `GodotSceneTraceBackend` remains
  telemetry-only for PMove contact and real-map contact parity is still future
  work.
* Weapon runtime, HUD, economy, buy menu, bot logic and full local server loop
  are not implemented on `main`.
* `goldsrc-godot` currently has macOS binaries; Linux CI validates
  extension-missing paths unless binaries/build are added.
* The Current Context Contract can become stale. Update it after merged PRs
  that change accepted decisions, architecture state or the immediate next
  task.

## 7. Immediate next task

No active implementation task is selected after PR-09A.

Maintainer instruction:

* Do not start PR-10A or neighboring gameplay packets before PR-09B is handled
  or explicitly deferred by the maintainer.
* PR-09B remains the next packet in `docs/COMPACT_PR_TASK_PACKETS.md`, but it
  needs an explicit wall-collision behavior gate before migrating the BSP lab to
  runtime snapshots.
* Keep the repository clean after finishing/pushing PR-09A.

## 8. Definition of done for the next task

The current handoff is done when:

* PR-09A implementation and documentation are complete;
* smoke checks, forbidden asset scan and whitespace checks pass;
* the worktree is clean;
* PR-09A changes are reviewable and PR-09B/PR-10A work has not started in this
  branch.

## 9. Sources of truth

* `AGENTS.md`
* `docs/agent_context_hygiene.md`
* `docs/current_context_contract.md`
* `docs/DECISIONS.md`
* `docs/DEVELOPMENT_PLAN.md`
* `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md`
* `docs/COMPACT_PR_TASK_PACKETS.md`
* `docs/TESTING.md`
* `docs/ARCHITECTURE.md`
* `docs/MOVEMENT.md`
* `docs/CS_1_6_FEEL.md`
* `docs/VIEWMODEL_WORLD_PROFILE.md`
* `docs/CS16_ASSET_ORCHESTRATION_ATLAS.md`
* `docs/COVERAGE_STATUS_CONTRACT.md`
* `docs/TAINTED_LABS_POLICY.md`
* `docs/TAINT_LEDGER.md`
* `docs/PUBLIC_OPEN_SOURCE_EXIT_PLAN.md`
* `docs/GDSCRIPT_AGENT_NOTES.md`
* `CHANGELOG.md`
* Local `git status`, `git log`, current branch and GitHub PR state.

## 10. Instructions to the next agent

* Start by forming a Task Packet and explicit Assumptions.
* Do not rely on stale chat history over this contract or repository files.
* Verify local repository state and GitHub PR state before making code claims.
* Keep PRs narrow; do not combine process docs, runtime architecture and
  gameplay features unless explicitly requested.
* Prefer current decisions and smoke-tested contracts over old chat messages.
* If new evidence contradicts this file, update the Task Packet before
  continuing and update this contract in the same PR if project state changes.
