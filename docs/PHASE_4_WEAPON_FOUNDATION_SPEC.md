# Phase 4 Weapon Foundation Spec

Status: **Draft / blocked for implementation until the runtime gate is closed**.  
Role: system analysis / architecture planning.  
Related issues: #31, #38, #39.

This document is a planning artifact for the future Phase 4. It is not an
implementation task for Codex and it does not open Phase 4 development. Codex
implementation tasks must still be formulated by the tech lead after the runtime
gate is closed.

## 1. Purpose

Phase 4 establishes the first authoritative weapon runtime foundation for
OpenStrike. The goal is to add a narrow, deterministic, fixed-tick weapon layer
that can later grow into CS 1.6 weapon behavior without mixing gameplay authority
with presentation, dev labs, viewmodels or asset loading.

Phase 4 is intentionally not a full gameplay-loop phase. It is the smallest
weapon foundation that proves:

```text
UserCommand -> LocalGameSession fixed tick -> weapon runtime state -> weapon events -> snapshot -> dev/presentation consumers
```

The first weapon vertical slice is `usp`.

## 2. Implementation gate

Phase 4 implementation is blocked until the runtime-spine gate below is closed:

```text
1. PR-09C.0: docs source-of-truth repair.
2. PR-09C: real-map clipnode trace / Contract B.
3. Runtime fix: alive players move every fixed tick even without input command.
4. Runtime fix: max one movement command per player/tick, with explicit stale,
   duplicate and backlog policy.
5. PR-09D: walkable telemetry invariants proving max speed, jump height,
   no teleport, and free_volume != contact.
```

Rationale: weapon runtime must not be built on top of a false playable-looking
state where the player can move in a real BSP lab but runtime movement still uses
`free_volume`, freezes without commands, or applies multiple movement steps in
one fixed tick.

## 3. Phase 4 scope

Tech lead decision: Phase 4 is **weapon runtime foundation only**.

Phase 4 includes:

```text
- authoritative USP weapon state;
- weapon command normalization;
- fixed-tick fire/reload command processing;
- ammo and cooldown state;
- semantic weapon events in snapshots;
- later in the phase: hitscan through TraceBackend;
- later in the phase: a simple dummy target health/death proof.
```

Phase 4 excludes:

```text
- full arsenal;
- buy menu;
- economy / money;
- HUD clone;
- viewmodel animation parity;
- real CS asset rendering requirements;
- bot logic;
- networking / listen-server;
- CS damage parity;
- hitgroups;
- armor / helmet behavior;
- recoil parity;
- spread parity;
- grenades;
- melee;
- moving brushes / doors / func_* gameplay.
```

## 4. Baseline decisions from #38

The following decisions are accepted and should not be reopened inside Phase 4
planning unless the maintainer explicitly changes them:

```text
Phase 4 boundary: weapon runtime foundation only.
First weapon: USP.
Demo outcome: dev-lab visible, built incrementally.
Damage: no damage in PR-10A; hitscan without damage in PR-10B; dummy target in PR-10C.
Assets: semantic references only, no required rendering.
Spec format: document first, PR task packets second.
```

Planned progression:

```text
PR-10A: USP weapon state/events/snapshot, headless smoke-verifiable.
PR-10B: hitscan trace through TraceBackend, debug-visible in a lab.
PR-10C: dummy target + health + death, visible result allowed through a lab consumer.
```

## 5. Authority boundary

Authoritative weapon logic belongs to `src/game` only:

```text
src/game/weapons
  Owns weapon state, command normalization, fire/reload acceptance, ammo,
  cooldown and semantic weapon events.

src/game/runtime
  Applies weapon commands during `OpenStrikeLocalGameSession` fixed ticks and
  publishes weapon state/events in snapshots.
```

Non-authoritative consumers:

```text
src/presentation/viewmodel
src/presentation/effects
src/presentation/audio
  May consume semantic weapon events later. They must not decide whether a shot
  happened, whether ammo changed, or whether cooldown allows firing.

src/dev/labs
  May render debug labels, trace lines, dummy target proofs and telemetry. Dev
  labs must not own weapon authority.
```

Hard rule:

```text
src/game must not import src/dev or src/presentation.
```

## 6. Runtime integration model

Weapon runtime is processed inside `OpenStrikeLocalGameSession` fixed ticks.

A fixed tick should conceptually do this after the runtime-spine movement gate is
fixed:

```text
1. Resolve exactly one user command for each alive/movable player for this tick.
   If no input command exists, synthesize a no-op command that preserves the last
   view angles and has no pressed action buttons.
2. Apply movement for every alive/movable player every fixed tick.
3. Apply weapon command processing for every alive player every fixed tick.
4. Advance cooldowns/reload timers deterministically.
5. Collect transient weapon events produced by this tick.
6. Publish snapshot with movement state, weapon state and weapon events.
```

Phase 4 must not reintroduce a model where simulation advances only when input
commands arrive.

## 7. Command model

`OpenStrikeUserCommand` is the per-player, per-tick player intent. Phase 4 should
extend the input model without creating a second independent timing source.

Recommended normalized command shape:

```text
OpenStrikeUserCommand
  tick
  player_id
  movement axes/buttons
  view_yaw
  view_pitch
  weapon_command
```

Where `weapon_command` is either an embedded dictionary or a typed DTO, for
example:

```text
OpenStrikeWeaponCommand
  tick
  player_id
  active_weapon_id
  primary_attack_pressed
  reload_pressed
  requested_weapon_id / requested_slot (deferred if not needed in PR-10A)
```

PR-10A should keep command scope minimal:

```text
primary_attack_pressed
reload_pressed
```

Deferred command fields:

```text
primary_attack_held
secondary_attack_pressed
weapon slot switching
weapon drop
buy commands
grenade throw states
```

### Accepted and rejected commands

A weapon command is **accepted** when the authoritative weapon runtime changes
state or produces an accepted semantic event.

Examples:

```text
fire accepted -> ammo decremented, cooldown starts, weapon.fire.accepted emitted
reload accepted -> reload state starts, weapon.reload.started emitted
```

A weapon command is **rejected** when the command is valid input but cannot be
applied under current state.

Examples:

```text
fire rejected because cooldown > 0
fire rejected because magazine empty
reload rejected because magazine full
reload rejected because reserve ammo is 0
```

Rejected commands are useful debug/runtime events and should be visible in
smoke snapshots, but they must not trigger presentation effects as if the shot
happened.

## 8. Weapon state model

Minimum PR-10A USP state:

```text
active_weapon_id: "usp"
state: idle | firing | reloading
ammo_in_magazine: int
ammo_reserve: int
cooldown_remaining_ticks: int
reload_remaining_ticks: int (optional in PR-10A if reload is a stub)
last_fire_tick: int
```

Initial values for PR-10A should be non-parity smoke values unless explicitly
verified. Example:

```text
weapon_id = "usp"
ammo_in_magazine = 12
ammo_reserve = 24
cooldown_ticks = configured value, not claimed as CS parity
```

Do not claim CS 1.6 USP timing, spread, recoil or reserve-ammo parity in Phase 4.
If exact CS values are needed later, they must be introduced through a separate
verified data-driven weapon tuning task.

## 9. Weapon event model

Weapon events are semantic gameplay/runtime events. They are not animation
markers and not presentation commands.

Minimum event types:

```text
weapon.fire.accepted
weapon.fire.rejected
weapon.reload.started
weapon.reload.rejected
weapon.reload.committed (optional after reload commit is implemented)
weapon.cooldown.tick (not usually needed in snapshot; keep internal unless useful for debug)
```

Recommended event fields:

```text
type
player_id
tick
weapon_id
state_before
state_after
reason (for rejected events)
ammo_in_magazine
ammo_reserve
trace_result (PR-10B+ only)
target_result (PR-10C+ only)
```

Events should be transient per fixed tick: a snapshot contains events produced by
the last `step(delta)` call, not an unbounded event log.

If a single `step(delta)` advances multiple fixed ticks, the snapshot may contain
events from all fixed ticks advanced by that call, but every event must carry its
own `tick`.

## 10. Snapshot contract

Minimum snapshot shape for Phase 4:

```json
{
  "players": [
    {
      "player_id": 1,
      "active_weapon_id": "usp",
      "weapon_state": {
        "weapon_id": "usp",
        "state": "idle",
        "ammo_in_magazine": 12,
        "ammo_reserve": 24,
        "cooldown_remaining_ticks": 0
      },
      "weapon_events": [
        {
          "type": "weapon.fire.accepted",
          "tick": 42,
          "player_id": 1,
          "weapon_id": "usp",
          "ammo_in_magazine": 11,
          "ammo_reserve": 24
        }
      ]
    }
  ]
}
```

Decision: weapon state should live on the player snapshot because Phase 4 only
has player-owned weapons. A future inventory/team/world-entity design may add a
session-level weapon or dropped-weapon section later.

### PR-10A mandatory snapshot fields

```text
active_weapon_id
weapon_state.weapon_id
weapon_state.state
weapon_state.ammo_in_magazine
weapon_state.ammo_reserve
weapon_state.cooldown_remaining_ticks
weapon_events[].type
weapon_events[].tick
weapon_events[].player_id
weapon_events[].weapon_id
```

### PR-10B additional snapshot/event fields

```text
weapon_events[].trace_result
weapon_events[].origin
weapon_events[].direction
weapon_events[].hit
weapon_events[].hit_position
weapon_events[].hit_normal
```

### PR-10C additional snapshot/event fields

```text
weapon_events[].target_result
target_id
target_health_before
target_health_after
target_destroyed / target_dead
```

Do not add in Phase 4:

```text
viewmodel transforms
animation state
camera recoil
spray/recoil pattern state
HUD-specific fields
buy/economy fields
```

## 11. TraceBackend / hitscan boundary

PR-10A does not perform hitscan. It only proves weapon state/events/snapshot.

PR-10B adds hitscan through `OpenStrikeTraceBackend`.

Important boundary:

```text
Weapon runtime asks a trace service/backend for a ray result.
Weapon runtime does not know whether the map is a dev lab, a synthetic fixture,
or a real BSP resource.
```

Potential PR-10B issue to resolve:

```text
Movement collision currently depends on hull traces. Hitscan needs ray traces.
If the real-map Contract B backend does not yet support trace_ray, PR-10B must
add or require a narrow ray trace capability without changing movement semantics.
```

Trace result in Phase 4 is still a runtime/debug fact, not CS hit registration
parity. Lag compensation, prediction and network reconciliation are out of scope.

## 12. Dummy target / damage boundary

PR-10C introduces only a minimal runtime target fixture.

Allowed:

```text
simple dummy target
health = 100
USP hit damage = 10
death/destroyed semantic event
headless smoke proving ten hits can kill the dummy
optional dev-lab debug view showing target health/death
```

Not allowed in Phase 4:

```text
hitgroups
armor
helmet
friendly fire
team damage rules
CS weapon damage parity
penetration
surface materials
blood/decals
scoreboard/killfeed
```

The dummy target is a runtime test/proof object, not a commitment to final CS
player damage architecture.

## 13. Data/config contract

Phase 4 should be data-driven enough to avoid hardcoding weapon constants in
runtime code, while avoiding premature full-arsenal design.

Recommended minimal config shape:

```json
{
  "weapons": {
    "usp": {
      "display_name": "USP",
      "kind": "hitscan_firearm",
      "magazine_size": 12,
      "initial_reserve_ammo": 24,
      "cooldown_ticks": 10,
      "reload_ticks": 100,
      "semantic_asset_refs": {
        "view_model": "weapon.usp.view_model",
        "fire_audio": "weapon.usp.fire"
      }
    }
  }
}
```

Notes:

```text
- These numbers are Phase 4 smoke defaults unless separately verified.
- Semantic asset refs may exist, but PR-10A must not require real USP assets.
- Missing asset refs must not block weapon runtime smoke tests.
```

## 14. Presentation boundary

Presentation is not part of authoritative Phase 4 foundation.

Allowed presentation/dev behavior:

```text
log "weapon.fire.accepted usp" in debug overlay
show a debug trace line in PR-10B
show dummy target health/death in PR-10C
```

Forbidden presentation coupling:

```text
fire accepted because animation event happened
ammo committed because reload animation marker fired
viewmodel transform stored in game snapshot
runtime loading v_usp.mdl / sound/weapons/*.wav directly
presentation deciding whether cooldown/ammo allows fire
```

Later viewmodel/audio/effects orchestration should consume semantic events:

```text
weapon.fire.accepted -> animation/audio/muzzle flash consumers
weapon.reload.started -> animation/audio consumers
```

But those consumers are outside the PR-10A foundation.

## 15. Dev-lab/debug boundary

Dev labs may be used to prove that snapshots/events are visible and useful.

Rules:

```text
- dev labs consume runtime snapshots;
- dev labs may visualize events/traces/targets;
- dev labs must not own weapon authority;
- dev labs must not import Valve assets into the repository;
- dev labs must not create fake gameplay rules that bypass src/game runtime.
```

The useful Phase 4 demo after the runtime gate is:

```text
On real de_dust2, through LocalGameSession, the player can fire USP runtime
commands; snapshot emits semantic weapon events; later hitscan debug traces are
visible; later a dummy target can take damage and die.
```

## 16. Smoke tests and acceptance gates

Minimum smoke coverage for PR-10A:

```text
weapon_runtime_state_smoke.gd
  - initializes USP state;
  - accepts first fire command;
  - decrements ammo;
  - starts cooldown;
  - emits weapon.fire.accepted;
  - rejects fire during cooldown;
  - does not emit accepted fire on rejection;
  - cooldown advances deterministically by fixed ticks.

local_game_session_weapon_smoke.gd
  - creates LocalGameSession with one player;
  - queues a user command with primary attack;
  - steps fixed tick;
  - snapshot contains active_weapon_id, weapon_state and weapon_events;
  - no src/dev or src/presentation dependency in src/game.
```

Minimum smoke coverage for PR-10B:

```text
weapon_hitscan_trace_smoke.gd
  - uses a synthetic or validated TraceBackend ray fixture;
  - accepted fire event includes trace_result;
  - rejected fire does not trace;
  - missing/unsupported trace capability reports diagnostics honestly.
```

Minimum smoke coverage for PR-10C:

```text
weapon_dummy_target_smoke.gd
  - target starts with health=100;
  - accepted hitscan damage applies 10 damage;
  - health reaches 0 after expected number of hits;
  - death event emitted exactly once;
  - no CS parity claims for damage/hitgroups/armor.
```

Repository-level checks remain required:

```text
scripts/run_smoke_checks.sh
scripts/check_no_forbidden_assets.sh
git diff --check
```

If a docs-only PR cannot run runtime smoke locally, the PR description must state
which checks were not run and why.

## 17. Draft PR packet: PR-10A — USP runtime state/events/snapshot

### Goal

Add the first authoritative weapon runtime state for USP and publish semantic
weapon events in `OpenStrikeLocalGameSession` snapshots.

### Includes

```text
- weapon runtime DTO/state classes under src/game/weapons;
- normalized weapon command for primary fire/reload intent;
- USP-only runtime config/defaults;
- LocalGameSession fixed-tick weapon processing;
- ammo/cooldown handling;
- fire accepted/rejected events;
- snapshot fields for active_weapon_id, weapon_state, weapon_events;
- headless smoke coverage.
```

### Excludes

```text
- hitscan;
- damage;
- dummy target;
- viewmodel;
- audio;
- HUD;
- real CS asset requirement;
- recoil/spread parity;
- full arsenal;
- buy/economy.
```

### Acceptance

```text
- first fire command is accepted when ammo > 0 and cooldown == 0;
- ammo_in_magazine decrements by 1;
- cooldown starts and ticks down deterministically;
- fire during cooldown is rejected with reason;
- snapshot contains authoritative weapon state and events;
- src/game does not import src/dev or src/presentation;
- no Valve assets or local paths are added.
```

## 18. Draft PR packet: PR-10B — Hitscan through TraceBackend

### Goal

Connect accepted weapon fire to a trace-ray capability through the existing
TraceBackend boundary and expose trace results as debug/runtime event data.

### Includes

```text
- weapon fire can request a ray trace through TraceBackend;
- trace result is attached to weapon.fire.accepted event;
- unsupported trace capability is reported honestly;
- dev lab may visualize debug trace as a consumer;
- smoke coverage for hit/miss/unsupported trace.
```

### Excludes

```text
- damage;
- dummy target health;
- lag compensation;
- prediction;
- penetration;
- surface materials;
- decals/blood;
- viewmodel/audio effects.
```

### Acceptance

```text
- accepted fire event includes trace_result when backend supports ray trace;
- rejected fire does not perform trace;
- trace capability metadata is visible in event/debug report;
- runtime does not depend on dev/presentation;
- no CS hit registration parity is claimed.
```

## 19. Draft PR packet: PR-10C — Dummy target health/death proof

### Goal

Add a minimal runtime dummy target to prove that weapon trace results can affect a
runtime entity without implementing CS damage parity.

### Includes

```text
- simple dummy target runtime fixture;
- health=100;
- USP/hitscan damage=10;
- target health update event;
- target death event;
- smoke coverage for damage and single death emission;
- optional dev-lab visualization as consumer.
```

### Excludes

```text
- player-vs-player damage;
- hitgroups;
- armor/helmet;
- team rules;
- money/rewards;
- killfeed/scoreboard;
- CS damage parity;
- bot reactions.
```

### Acceptance

```text
- target health decreases by 10 on accepted hit;
- target reaches 0 after expected hits;
- death event emitted once;
- misses do not damage target;
- rejected fire does not damage target;
- no presentation dependency in runtime.
```

## 20. Deferred decisions / Phase 5+

Deferred beyond Phase 4:

```text
- AK-47 and automatic fire cadence;
- recoil and spread parity;
- full CS weapon catalog;
- reload timing parity;
- weapon switching / inventory slots;
- dropped weapons and pickups;
- player health/armor/hitgroups;
- buy menu and economy;
- HUD and killfeed;
- viewmodel/audio/effects parity;
- bots;
- networking / listen-server;
- lag compensation;
- bullet penetration and material behavior.
```

## 21. Anti-regression rules

Phase 4 must not regress the runtime-spine direction established before it.

Rules:

```text
- do not put gameplay authority in dev labs;
- do not make presentation decide fire/reload acceptance;
- do not make weapon runtime depend on real assets;
- do not claim CS parity for unverified constants;
- do not bypass TraceBackend for hitscan;
- do not add weapon work before the runtime gate is closed;
- do not combine Phase 4 foundation with HUD/economy/buy/full arsenal work.
```

## 22. Definition of done for this spec

This specification is complete when:

```text
- it records the blocked status and implementation gate;
- it accepts #38 tech-lead decisions as baseline;
- it defines Phase 4 as USP-first weapon runtime foundation;
- it documents authority boundaries;
- it defines command/state/event/snapshot contracts;
- it separates PR-10A, PR-10B and PR-10C responsibilities;
- it lists out-of-scope systems and deferred decisions;
- it can be used by the tech lead to prepare Codex implementation tasks after the runtime gate closes.
```
