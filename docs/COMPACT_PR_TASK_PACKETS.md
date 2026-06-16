# OpenStrike — Compact PR Task Packets from GoldSrc Runtime Spine Spec

next steps: take the first unclosed PR packet in this file.

## Global rule for every PR

Every PR must be small enough to review in one sitting.

Every PR must state:

* Goal
* Includes
* Excludes
* Acceptance
* What must not be touched

No PR may combine:

* BSP reader + PMove + weapon loop
* runtime session + HUD + weapon
* clipnode trace + real map golden tests
* dirty lab code + production runtime
* presentation polish + gameplay authority

The project direction:

```text
dirty lab → documented findings → clean runtime contract → production code
```

---

# Phase 0 — Close current runtime leaks

## PR-08A.1 — Runtime spawn descriptors cleanup

### Goal

Remove direct `Node3D` dependency from `OpenStrikeLocalGameSession`.

Runtime must consume sanitized spawn facts, not scene-tree objects.

### Includes

* Add spawn descriptor method to `OpenStrikeMapEntityIndex`.
* Return pure dictionaries:

```text
classname
position
yaw
origin
angles
source
```

* Change `OpenStrikeLocalGameSession` spawn assignment to consume descriptors.
* Update runtime smoke.

### Excludes

* No movement integration.
* No weapon logic.
* No TraceBackend changes.
* No BSP reader.

### Acceptance

* `src/game/runtime` no longer reads `entry["node"]`.
* `OpenStrikeLocalGameSession` does not require `Node3D`.
* Spawn priority still works for CT/T/unassigned.
* Existing smoke checks pass.

---

# Phase 1 — BSP collision vertical slice

## PR-08B — BSP30 collision vertical slice

### Goal

Implement the first verifiable OpenStrike-owned BSP30 collision reader.

This PR must not be reader-only. Minimal trace is the acceptance test for the reader.

### Includes

Add:

```text
src/core/bsp/bsp_binary_reader.gd
src/core/bsp/bsp_lump_table.gd
src/core/bsp/bsp_map_resource.gd
src/core/bsp/bsp_collision_lumps.gd
src/core/bsp/bsp_reader_diagnostic.gd
src/core/bsp/bsp_clipnode_trace_backend.gd
```

Reader parses:

```text
BSP version 30
15 lump entries
planes: 20-byte records
clipnodes: 8-byte records
GoldSrc models: 64-byte records with headnode[4]
```

Backend implements minimal:

```text
trace_hull()
model 0 only
synthetic buffers only
point hull
standing hull
```

### Required synthetic tests

Synthetic BSP:

```text
plane: x=0, normal=(1,0,0)
clipnode:
  planenum = 0
  front = CONTENTS_EMPTY
  back = CONTENTS_SOLID
model:
  GoldSrc dmodel_t, 64 bytes
  headnode[1] = 0
```

Tests:

```text
Point hull x=10 -> x=-10:
  hit=true
  fraction≈0.5

Standing hull x=32 -> x=-32:
  hit=true
  center contact x=16
  fraction≈0.25 under declared contract

Standing hull start x=10:
  start_solid=true

Free trace:
  hit=false
  fraction=1

Invalid planenum:
  diagnostic

Invalid child:
  diagnostic

Empty clipnodes:
  non-solid, no fallback to headnode[0]

Source-style 48-byte dmodel_t:
  rejected/diagnosed
```

### Required decision

Add to `docs/DECISIONS.md`:

```text
Hull extent contract:
A = runtime offset over point-space planes
B = pre-expanded hull-space clipnodes
Chosen contract = ...
Reason = ...
```

### Excludes

* No PMove.
* No PlayerMoveService.
* No LocalGameSession movement.
* No weapon hitscan.
* No fence textures.
* No moving brushes.
* No real map golden tests.
* No WAD/miptexture parsing.
* No render mesh generation.

### Acceptance

* New synthetic smoke passes.
* Existing smoke passes.
* No Valve assets.
* No denylisted source.
* `GodotSceneTraceBackend` remains non-parity.
* `BspClipnodeTraceBackend` exists but is limited/synthetic.

---

## PR-08B.1 — Real BSP Contract A diagnostic

### Goal

Check how the PR-08B synthetic hull-extent Contract A relates to a real local
BSP30 map, without turning the result into gameplay collision authority.

### Includes

* Local-only developer command:

```text
--map=maps/de_dust2.bsp
```

* Load the map through `OpenStrikeAssetManager` / GoldSrc VFS into
  `OpenStrikeBspMapResource`.
* Report sanitized facts only:

```text
version
lump lengths/counts
planes count
clipnodes count
models count
model 0 headnode[0..3]
standing/duck reachable clipnode summary
diagnostics
```

* Add a CI-safe synthetic smoke mode that writes only temporary `user://`
  fixtures.
* Add a local test report and decision update explaining whether Contract A can
  be promoted beyond synthetic fixtures.

### Excludes

* No real BSP files or extracted lump bytes.
* No local absolute paths in committed docs or output.
* No real-map contact assertions or golden fractions.
* No PMove.
* No PlayerMoveService.
* No LocalGameSession movement.
* No weapon, HUD, economy, bots or networking.
* No WAD/miptexture parsing.
* No production backend switch.

### Acceptance

* The local command can inspect a licensed BSP when `user://local_goldsrc.json`
  is available.
* Shared smoke checks cover the tool through synthetic `user://` fixtures.
* `docs/DECISIONS.md` and `docs/test_reports/` record the Contract A status.
* Contract A remains synthetic-only unless real-map contact evidence proves
  otherwise.
* CI does not require Valve assets.

---

## PR-08C — Clipnode backend capability integration

### Goal

Make `BspClipnodeTraceBackend` a selectable backend behind existing `OpenStrikeTraceBackend`, without using it for player movement yet.

### Includes

* Backend capabilities report.
* Trace result fields finalized:

```text
all_solid
contents_code
model_index
```

* Shared trace-result smoke for:

```text
GodotSceneTraceBackend
BspClipnodeTraceBackend
```

* Add backend selector only in dev/smoke or dev lab options, not production runtime.

### Excludes

* No PMove.
* No BSP lab default switch.
* No real map golden tests.
* No weapon.

### Acceptance

* Both backends satisfy same interface.
* Godot backend reports `godot_collision_unverified`.
* BSP backend reports limited synthetic support.
* `point_contents()` API remains backward-compatible.

---

## PR-08D — Local BSP typed-load inspection

Initial Contract A inspection was pulled forward into PR-08B.1. Keep PR-08D
only for broader local typed-load diagnostics beyond that scoped hull-extent
question.

Status after PR-08D reconciliation: no additional implementation packet remains
for the original PR-08D acceptance criteria. PR-08B.1 added the local VFS-backed
diagnostic and synthetic smoke, and the local `de_dust2` report confirms model
0 headnodes. Continue with PR-08E unless a new, separately scoped typed-load
diagnostic is requested.

### Goal

Load a real local BSP into `BspMapResource` as opt-in developer smoke, without committing assets and without contact golden tests.

### Includes

* Local-only command/tool:

```text
--map=maps/de_dust2.bsp
```

* Reports:

```text
version
lump table
planes count
clipnodes count
models count
headnode[0..3]
diagnostics
```

* Add local test report.

### Excludes

* No real-map contact assertions.
* No movement.
* No presentation.
* No replacement of `goldsrc-godot`.

### Acceptance

* Local load smoke can inspect a licensed BSP.
* CI does not require Valve assets.
* Report confirms whether model 0 has hull headnodes.
* No real map data committed.

---

# Phase 2 — Movement authority

## PR-08E — Player state and command model

### Goal

Introduce clean player movement state/command types for future PMove.

### Includes

Add:

```text
src/game/player/player_state.gd
src/game/player/player_move_command.gd
src/game/player/player_move_result.gd
```

State contains:

```text
origin
velocity
view_yaw
view_pitch
ducked
on_ground
flags
last_trace_summary
```

Command contains:

```text
forward_move
side_move
wants_jump
wants_duck
view_yaw
view_pitch
frametime
```

### Excludes

* No movement algorithm yet.
* No LocalGameSession integration.
* No clipnode dependency.

### Acceptance

* Types serialize to dictionary.
* Smoke verifies defaults and roundtrip.
* No Godot `CharacterBody3D`.

---

## PR-08F — PlayerMoveService free-volume movement

### Goal

Create `PlayerMoveService` using existing `CSMovementMath` for free-volume movement.

### Includes

Add:

```text
src/game/player/player_move_service.gd
```

Implement only backend-independent movement:

```text
friction
ground acceleration
air acceleration
jump impulse
gravity
maxvelocity clamp
duck state height metadata
```

Use `TraceBackend` only as dependency placeholder; do not do contact movement yet.

### Excludes

* No step-slide.
* No ramps.
* No hull contact.
* No edgefriction.
* No LocalGameSession movement.
* No real BSP.

### Acceptance

* Existing movement smoke can be driven through `PlayerMoveService`.
* Air-strafe regression remains guarded.
* No `move_and_slide`.
* No duplicate movement equations.

---

## PR-08G — PlayerMoveService contact loop on synthetic backend

### Goal

Add minimal trace-slide contact movement using synthetic `BspClipnodeTraceBackend`.

### Includes

* Up to 4 trace iterations.
* Stop on clear fraction.
* Slide velocity by plane normal.
* Contact summary in move result.

### Excludes

* No step-up yet.
* No edgefriction.
* No real map golden.
* No Godot backend contact golden.

### Acceptance

* Synthetic wall stops player.
* Synthetic open space moves freely.
* Contact golden tests use BSP backend only.
* Godot contact remains telemetry only.

---

## PR-08H — Step-up and duck hull on synthetic backend

### Goal

Add first step/duck contact logic only against synthetic BSP backend.

### Includes

* Standing hull vs duck hull selection.
* Simple step-up attempt:

```text
up by sv_stepsize
move
trace down
choose farther valid path
```

* Synthetic stair fixture.

### Excludes

* No real map golden.
* No moving platforms.
* No ladders/water.
* No surf.

### Acceptance

* Standing hull blocked where duck hull can pass in synthetic fixture.
* Step-up succeeds on synthetic 18-unit step.
* Step-up fails on too-high step.
* Backend A numbers are not golden.

---

# Phase 3 — Runtime session integration

## PR-09A — LocalGameSession applies movement commands

Status: merged in PR #28.

### Goal

Connect `OpenStrikeLocalGameSession` to `PlayerMoveService`.

### Includes

* Player slot gains movement state.
* `OpenStrikeUserCommand` converts to `PlayerMoveCommand`.
* Fixed tick applies movement.
* Snapshot includes player origin/velocity/view.

### Excludes

* No weapon.
* No HUD.
* No damage.
* No real BSP default.

### Acceptance

* Synthetic backend session moves player deterministically.
* Commands advance player position.
* Snapshot contains movement state.
* Runtime still does not import dev lab or presentation.

---

## PR-09B — BSP lab consumes runtime snapshot

Status: merged in PR #28.

### Goal

Make BSP walkable lab a presentation consumer of runtime state, not the owner of gameplay movement.

### Includes

* Lab creates runtime session.
* Lab queues commands.
* Lab displays snapshot position/camera.
* Existing telemetry retained.

### Excludes

* No weapon.
* No HUD.
* No replacing Godot collision fully.
* No real map golden.

### Acceptance

* Lab still runs.
* Runtime owns player state.
* Presentation follows snapshot.
* No movement equations in lab.

---

## PR-09C.0 — Docs source-of-truth repair

Status: current docs-only packet.

### Goal

Make `AGENTS.md`, `docs/README.md` and `docs/current_context_contract.md`
agree on the active documentation map after docs consolidation and PR #30.
Prevent new agents from loading stale archive context or broken paths before
runtime-spine work continues.

### Includes

* Restore current workflow docs that agents must read to active `docs/` paths.
* Update `AGENTS.md` links so every active path exists or intentionally points
  to deferred `docs/future/` material.
* Update `docs/README.md` to state the current routing:
  PR-09C.0, then PR-09C, then PR-09D, with Phase 4 closed.
* Update `docs/current_context_contract.md` for merged PR-09A/09B and PR #30.
* Record the process/routing repair in `CHANGELOG.md`.

### Excludes

* No runtime code.
* No movement fixes.
* No BSP/collision backend changes.
* No real-map telemetry or trace diagnostics.
* No weapon, HUD, economy, bots, networking or round logic.
* No Valve assets, BSP files, local paths or telemetry dumps.

### Acceptance

* A new agent can read `AGENTS.md`, `docs/README.md` and
  `docs/current_context_contract.md` and get the same current project map.
* Active docs do not point at missing paths.
* `docs/archive/` is historical reference only, not active source of truth.
* Phase 4 / PR-10A is explicitly closed until PR-09C and PR-09D complete.
* Smoke checks, forbidden-asset scan and whitespace checks pass.

---

## PR-09C — Real-map clipnode trace (Contract B)

Status: next implementation packet after PR-09C.0.

### Goal
Extend BspClipnodeTraceBackend from synthetic fixture to a real BspMapResource
(de_dust2), so the walkable lab collides with actual map geometry. Replace the
GodotSceneTraceBackend stub in the lab with this backend.

### Includes
- Load real BspMapResource (model 0) into BspClipnodeTraceBackend.
- trace_hull over real clipnodes under Contract B (compiled hull-space planes):
  NO runtime plane offset (per DECISIONS 0023; offset would double-count).
- Wire this backend into bsp_walkable_runner instead of GodotSceneTraceBackend.
- Spec reference: CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md §5.

### Excludes
- No weapons, no fence textures, no moving brushes (later).
- No runtime offset on real clipnodes (Contract A is synthetic-only).
- Do not commit .bsp / Valve assets / local paths.

### Acceptance
- On real de_dust2 the player stands on the floor and is blocked by walls
  (no more sliding on one plane).
- goldsrc_parity flag reflects real-map trace honestly.
- Manual run confirms walkable geometry; smoke + forbidden-asset scan pass.

---

## PR-09D — Walkable telemetry invariants

### Goal
Verify movement on real de_dust2 by numbers, not by eye.

### Includes
- Manual lab run on real map producing JSONL telemetry.
- A parser/check asserting: max horizontal speed <= 250 u/s; diagonal not faster
  than straight; presentation_snapshot_position_delta == 0; jump height in range;
  air-strafe gains speed.

### Excludes
- No full CS parity claim (needs reference CS telemetry, out of scope).

### Acceptance
- Telemetry invariants pass on a real-map run; report committed (no asset bytes).

---

# Phase 4 — First gameplay loop

## PR-10A — One weapon runtime state

### Goal

Add one minimal weapon state without presentation polish.

### Includes

```text
weapon_runtime_state.gd
weapon_command.gd
weapon_result.gd
```

Support:

```text
idle
fire cooldown
ammo
reload stub
```

### Excludes

* No full CS arsenal.
* No recoil parity.
* No buy menu.
* No viewmodel animation parity.

### Acceptance

* Weapon state ticks in LocalGameSession.
* Fire command produces semantic event.
* Cooldown prevents spam.
* Snapshot includes weapon event.

---

## PR-10B — Hitscan via TraceBackend

### Goal

Make one weapon fire a ray through `TraceBackend`.

### Includes

* `trace_ray()` path.
* Impact result:

```text
hit / miss
position
normal
model/collider info
source/confidence
```

* Debug impact event.

### Excludes

* No damage yet.
* No decals beyond debug.
* No material effects.
* No clipnode point-hull parity claims if unsupported.

### Acceptance

* Synthetic backend ray hits wall.
* Godot backend ray works in BSP lab with non-parity confidence.
* No raw `RayCast3D` in game runtime.

---

## PR-10C — Dummy target and damage feedback

### Goal

Make shooting produce visible gameplay feedback.

### Includes

* Dummy target entity.
* Health.
* Damage event.
* Death/reset.
* Debug hit marker/log.

### Excludes

* No bots.
* No hitboxes.
* No armor.
* No round win condition.

### Acceptance

* Player can shoot dummy.
* Dummy loses health.
* Death is reported in snapshot.
* Presentation can show simple feedback.

---

## PR-10D — Minimal HUD

### Goal

Add only the HUD needed for playability.

### Includes

```text
crosshair
health
ammo
debug hit feedback
```

### Excludes

* No buy menu.
* No scoreboard.
* No radar.
* No CS HUD parity.

### Acceptance

* HUD reads snapshot only.
* HUD does not own gameplay.
* Missing assets are diagnostic, not silent failure.

---

# Phase 5 — Map gameplay semantics

## PR-11A — Authoritative entity-lump parser

### Goal

Move map entity truth toward OpenStrike-owned BSP data.

### Includes

* Parse entity lump from `BspMapResource`.
* Preserve unknown entities.
* Build entity descriptors compatible with `MapEntityIndex`.

### Excludes

* No collision trace changes.
* No buy/C4 gameplay yet.

### Acceptance

* Synthetic entity lump parses.
* Real local BSP entity report works opt-in.
* `MapEntityIndex` can be built from authoritative entity descriptors, not only imported scene metadata.

---

## PR-11B — Team spawns and round restart

### Goal

Turn local session into a basic team sandbox.

### Includes

* CT/T team assignment.
* Spawn groups.
* Restart round command.
* Alive/dead reset.

### Excludes

* No economy.
* No C4.
* No buy menu.

### Acceptance

* CT and T spawn at proper groups.
* Round restart respawns players.
* Snapshot reports round/player state.

---

## PR-11C — Buyzone and bombsite semantic volumes

### Goal

Make map objective volumes exist as runtime facts.

### Includes

* `func_buyzone` descriptors.
* `func_bomb_target` / `info_bomb_target` descriptors.
* Trigger membership checks through positions/volumes as available.

### Excludes

* No buy menu.
* No C4 plant yet.

### Acceptance

* Runtime knows whether player is in buyzone/bombsite.
* Data source is `MapEntityIndex` / entity descriptors.
* No direct scene-node dependency in game runtime.

---

# Phase 6 — CS-like round loop

## PR-12A — Round FSM

### Goal

Implement minimal round phases.

### Includes

```text
warmup
freeze_time
live
ended
restart
```

### Excludes

* No economy.
* No C4.
* No scoreboard.

### Acceptance

* Round phase transitions are deterministic.
* Commands can be blocked/allowed by phase.
* Snapshot reports phase.

---

## PR-12B — Elimination win condition

### Goal

Allow a round to end by killing all enemies.

### Includes

* Team alive counts.
* CT/T win by elimination.
* Round end event.

### Excludes

* No bomb objective.
* No economy.

### Acceptance

* Killing last enemy ends round.
* Winner is recorded.
* Restart works.

---

## PR-12C — C4 skeleton

### Goal

Add first bomb objective.

### Includes

```text
bomb carrier
plant command
plant timer
defuse command
defuse timer
explosion timer
round win by bomb
```

### Excludes

* No full animations.
* No economy.
* No advanced UI.

### Acceptance

* Plant only in bombsite.
* Defuse can win for CT.
* Explosion can win for T.
* Snapshot exposes bomb state.

---

## PR-12D — Economy and buy flow

### Goal

Add the first economy loop after combat/rounds exist.

### Includes

* Money.
* Buy command.
* Buyzone requirement.
* One or two purchasable weapons.
* Round rewards stub.

### Excludes

* No full CS shop UI.
* No complete arsenal.

### Acceptance

* Player can buy weapon in buyzone.
* Money changes.
* Buy blocked outside buyzone.

---

# Phase 7 — AI and multiplayer later

## PR-13A — Bot v0

### Goal

Add a dumb enemy to validate combat.

### Includes

* Static bot target with team.
* Line of sight via TraceBackend.
* Fire at player.
* Reaction delay.

### Excludes

* No navigation.
* No squad tactics.

### Acceptance

* Bot can shoot player.
* Player can kill bot.
* Round loop works with bot.

---

## PR-13B — Bot navigation v1

### Goal

Give bots simple movement.

### Includes

* Spawn-to-point movement.
* Basic path samples or manually generated points.
* Collision via TraceBackend/PlayerMoveService.

### Excludes

* No full navmesh.
* No AI Director.

### Acceptance

* Bot can move between points.
* Bot respects movement service.
* Bot does not use separate physics.

---

## PR-14A — Listen server boundary

### Goal

Prepare for LAN without rewriting gameplay.

### Includes

* Separate local client command queue.
* Snapshot serialization boundary.
* No real networking yet.

### Excludes

* No prediction.
* No lag compensation.
* No server browser.

### Acceptance

* Runtime can run without direct presentation dependency.
* Commands/snapshots are serializable dictionaries.

---

# Review checkpoints

After every 2–3 PRs, stop and review:

```text
Are labs still labs?
Does game runtime import presentation/dev code?
Do tests prove behavior or just structure?
Did Codex create duplicate classes?
Are Godot collision results still marked non-parity?
Is dirty code kept out of production?
```

If any answer is wrong, pause feature work and clean the architecture first.
