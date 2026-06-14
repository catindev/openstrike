# Movement

OpenStrike movement lives in `src/game/movement` and is owned by the game
layer. It does not depend on presentation, viewmodels, maps or local GoldSrc
assets.

## Scope

The current implementation is a deterministic kinematic core for PR-04. It
covers:

* cvar-backed movement settings;
* ground acceleration toward `sv_maxspeed`;
* ground friction using `sv_friction` and `sv_stopspeed`;
* air acceleration with GoldSrc-style capped `add_speed` and uncapped
  acceleration amount;
* jump impulse and half-step gravity integration;
* duck hull height selection;
* step-height helper acceptance based on `sv_stepsize`;
* telemetry frames for smoke tests and future golden comparisons.

It intentionally does not implement collision planes, edgefriction, water,
ladders, surfing, basevelocity, weapon speed modifiers or Godot controller
integration yet. Those belong in later, smaller PRs once the test surface is
stable.

`CSMovementSimulator.try_step_up()` is a collision-free helper for validating
`sv_stepsize` behavior. It is not a map/collision-integrated stair solver yet.

## Runtime classes

* `CSMovementSettings` reads movement cvars from `CvarRegistry`.
* `CSMovementInput` stores normalized forward/side movement plus jump and duck.
* `CSMovementState` stores position, velocity, ground state, hull height and
  ground height.
* `CSMovementSimulator` advances movement state for one frame.
* `CSMovementTelemetry` records per-frame state/input/settings snapshots.

## Reference constants

These values are reference data for CS 1.6-like behavior. They are documented
as constants, not copied source code.

| Cvar | Default | Meaning |
|---|---:|---|
| `sv_gravity` | `800` | Downward acceleration in units/s^2. |
| `sv_accelerate` | `10` | Ground acceleration coefficient. |
| `sv_friction` | `4` | Ground friction coefficient. |
| `sv_stopspeed` | `100` | Minimum speed used by low-speed friction. |
| `sv_stepsize` | `18` | Maximum accepted step height. |
| `sv_airaccelerate` | `10` | Air acceleration coefficient. |
| `sv_air_max_wishspeed` | `30` | OpenStrike-specific parity knob for GoldSrc's air wishspeed cap. |
| `sv_jumpvelocity` | `270` | OpenStrike-specific parity knob for the jump impulse. |
| `sv_maxspeed` | `320` | Base movement speed before weapon modifiers. |
| `sv_player_stand_height` | `72` | Standing player hull height. |
| `sv_player_duck_height` | `36` | Ducking player hull height. |

Air acceleration intentionally keeps two speeds separate:

```text
full_wishspeed = sv_maxspeed * input_fraction
capped_wishspeed = min(full_wishspeed, sv_air_max_wishspeed)
add_speed = capped_wishspeed - current_speed_along_wishdir
accel_speed = sv_airaccelerate * full_wishspeed * delta
final_accel = min(accel_speed, add_speed)
```

`sv_air_max_wishspeed` does not replace `full_wishspeed` when calculating the
acceleration amount.

## Timestep

Movement telemetry and smoke tests use explicit fixed timesteps. Current
parity smoke checks use `0.01` seconds to model 100 fps reference cases. Future
server-authoritative runtime work must preserve an explicit simulation tick
instead of silently coupling movement outcomes to render framerate.

Reference-only materials used for behavior verification include Valve
Developer Community GoldSrc command documentation and the Half-Life Physics
Reference. They are used to verify constants and equations; OpenStrike keeps an
original implementation.

Reference-only links:

* Valve Developer Community GoldSrc commands:
  `https://developer.valvesoftware.com/wiki/Category:GoldSrc_base_console_commands`
* Valve Developer Community Half-Life cvars:
  `https://developer.valvesoftware.com/wiki/List_of_Half-Life_console_commands_and_variables`
* Half-Life Physics Reference:
  `https://www.jwchong.com/hl/movement.html`

## Smoke coverage

`src/dev/smoke/movement_smoke.gd` verifies:

* cvar loading into movement settings;
* ground acceleration reaches `sv_maxspeed`;
* telemetry never exceeds `sv_maxspeed` during straight ground acceleration;
* ground friction stops a released player;
* air acceleration respects `sv_air_max_wishspeed`;
* optimal air-strafe gains match an independently calculated 100 fps reference
  range;
* jump-frame ground acceleration runs before takeoff;
* jumping leaves the ground and gravity lands the player;
* ducking switches hull height;
* the step-height helper accepts/rejects `sv_stepsize` bounds.
