# Cvars and Config

OpenStrike uses cvars as the authoritative source for engine and game tuning
values. Movement, weapons, rounds and menus should consume cvars instead of
hardcoding GoldSrc numbers in gameplay code.

## Default config

Default cvars live in:

```text
data/cvars/default.cfg
```

The file uses simple GoldSrc-style lines:

```text
sv_gravity 800
sv_friction 4
mp_startmoney 800
```

`//` starts a comment. Values are parsed as booleans, integers, floats or
strings. Quoted strings are supported, and `//` inside a quoted string is
preserved as part of the value.

## Units

Keep cvar units aligned with Counter-Strike 1.6 unless a later decision records
a deliberate conversion. Current defaults use:

| Cvar | Unit | Default |
|---|---:|---:|
| `movement_sim_hz` | Hz | `100` |
| `sv_gravity` | units/s^2 | `800` |
| `sv_accelerate` | coefficient | `5` |
| `sv_friction` | coefficient | `4` |
| `sv_stopspeed` | units/s | `75` |
| `sv_stepsize` | units | `18` |
| `sv_airaccelerate` | coefficient | `10` |
| `sv_air_max_wishspeed` | units/s | `30` |
| `sv_jumpvelocity` | units/s | `270` |
| `sv_maxspeed` | units/s | `320` |
| `sv_maxvelocity` | units/s | `2000` |
| `edgefriction` | coefficient | `2` |
| `sv_player_stand_height` | units | `72` |
| `sv_player_duck_height` | units | `36` |
| `mp_freezetime` | seconds | `6` |
| `mp_roundtime` | minutes | `5` |
| `mp_buytime` | minutes | `1.5` |
| `mp_c4timer` | seconds | `45` |
| `mp_startmoney` | dollars | `800` |

`movement_sim_hz`, `sv_air_max_wishspeed` and `sv_jumpvelocity` are
OpenStrike-specific parity knobs used by the movement core. They expose
GoldSrc-like constants through the cvar layer; they are not original GoldSrc
console variables.

## Runtime API

Initial implementation classes:

* `src/core/config/cvar_registry.gd` stores cvar definitions, defaults, runtime
  values and diagnostics.
* `src/core/config/config_loader.gd` exposes `OpenStrikeConfigLoader` and loads
  `data/cvars/default.cfg`.
* `src/core/config/bind_registry.gd` stores key-to-command bindings and parses
  basic `bind`/`unbind` lines.

Use `OpenStrikeConfigLoader.load_default_cvars()` to create a registry for defaults.
Use `CvarRegistry.apply_cfg_text()` for user overrides so default metadata is
preserved.

## Scope

This layer does not implement a developer console, menus, networked commands or
gameplay behavior yet. It provides the data model that those systems will use.

## Serialization

`CvarRegistry.serialize_cfg()` and `BindRegistry.serialize_cfg()` emit stable
cfg text. Future user config saving should write to `user://`, not to the
repository.
