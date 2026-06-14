# CS 1.6 Asset Orchestration Atlas

Status: working contract.

Purpose: keep OpenStrike moving toward a near-complete Counter-Strike 1.6
reimplementation instead of a small weapon demo. This document maps the asset
domains the engine must understand, how gameplay should address them
semantically and which facts are verified versus still needing local inspection.

This atlas is not an asset dump. It must never contain proprietary asset bytes,
local absolute paths, extracted textures, converted scenes or copied SDK code.

## Source Confidence

Use these confidence labels in catalog docs, config metadata and diagnostics:

| Label | Meaning |
|---|---|
| `verified_local_path` | Relative path resolved against a licensed local CS 1.6/Half-Life installation through OpenStrike VFS. |
| `inspected_mdl` | Sequence names, durations, attachments or events were read from the local MDL through the GoldSrc GDExtension inspection path. |
| `public_reference` | Value or behavior is backed by a documented public GoldSrc/CS reference. |
| `readytostrike_lab` | Useful prototype data from Readytostrike; must not be treated as final parity without verification. |
| `todo_verify` | Plausible mapping or timing that must not become gameplay contract yet. |

## Non-Negotiable Rule

Gameplay never addresses provider-specific files directly.

Correct flow:

```text
Gameplay state
  -> semantic weapon/action/effect/audio event
  -> orchestration contract
  -> AssetManager
  -> active provider
  -> local GoldSrc path or future original asset pack
```

Incorrect flow:

```text
WeaponController -> models/v_ak47.mdl
WeaponController -> sound/weapons/ak47-1.wav
WeaponController -> sprites/muzzleflash1.spr
```

## Required Asset Domains

OpenStrike must eventually maintain catalogs and diagnostics for all of these
domains:

| Domain | GoldSrc examples | OpenStrike responsibility |
|---|---|---|
| Weapon viewmodels | `models/v_ak47.mdl` | First-person weapon, hands, animation sequences, attachments. |
| Weapon player models | `models/p_ak47.mdl` | Third-person held weapon attached to remote player skeletons. |
| Weapon world models | `models/w_ak47.mdl` | Dropped weapons, pickups, grenade projectiles, C4 world object. |
| Player models | `models/player/gign/gign.mdl` | Team/player visuals, hitbox and animation reference later. |
| Objective and misc models | C4, hostages, map props | Entity adapters and gameplay objects later. |
| Weapon sounds | `sound/weapons/*.wav` | First-person and world audio event mapping. |
| Player/world sounds | footsteps, radio, hostages, ambience | Movement feedback, radio, objectives, map ambience. |
| Sprites | muzzle flash, impact, smoke, HUD | Effects, HUD, scope, radar and map entities. |
| BSP maps | `maps/*.bsp` | Geometry, collision, entity metadata, spawn points. |
| WAD textures | `*.wad` | BSP texture resolution and surface material metadata. |
| Overviews | `overviews/*.txt/.bmp/.tga` | Map browser previews and radar/reference data later. |
| HUD text layouts | `sprites/hud.txt`, weapon txt files | Sprite HUD regions and weapon selection UI. |
| Decals/effects | blood, bullet holes, ricochet, explosions | Impact feedback and surface-specific presentation. |

PR-06 only starts with weapon viewmodel/audio/effect orchestration, but the
contracts must leave room for every domain above.

## Weapon Model Roles

Every CS-style weapon should be represented by three model roles when available:

| Role | Prefix | Use |
|---|---|---|
| `view_model` | `v_` | Local first-person weapon and hands. |
| `player_model` | `p_` | Weapon held by third-person players/bots. |
| `world_model` | `w_` | Dropped/pickup/projectile/object representation. |

The first-person viewmodel usually contains both the weapon and hands. Do not
look for a universal `arms.mdl` as the base CS 1.6 contract.

## Core Weapon Coverage Target

The full CS 1.6 weapon catalog must cover at least these logical IDs:

| Category | Weapon IDs |
|---|---|
| Pistols | `glock18`, `usp`, `p228`, `deagle`, `elite`, `fiveseven` |
| Shotguns | `m3`, `xm1014` |
| SMGs | `mp5`, `tmp`, `p90`, `mac10`, `ump45` |
| Rifles | `ak47`, `m4a1`, `aug`, `sg552`, `galil`, `famas` |
| Snipers | `scout`, `awp`, `g3sg1`, `sg550` |
| Machine gun | `m249` |
| Melee | `knife` |
| Grenades | `hegrenade`, `flashbang`, `smokegrenade` |
| Objective | `c4` |

For each weapon, the catalog must eventually provide:

```text
weapon id
slot/category/team availability
gameplay numbers
view/player/world model references
animation aliases and inspected sequence facts
audio events
effect events
reload/ammo commit rules
switch/deploy/holster rules
diagnostics and source-confidence metadata
```

## Pilot Weapon State

The current committed pilot catalog only covers AK-47, USP, knife and HE grenade
asset paths in `data/assets/cs16_pilot_weapon_assets.json`.

That catalog is enough for VFS and manifest validation. It is not enough for
near-complete CS 1.6 weapon orchestration because it does not yet record:

* actual MDL sequence names;
* sequence durations;
* attachment/socket inventory;
* imported studio events;
* per-weapon reload fragment timings backed by MDL/event inspection;
* third-person/world model readiness;
* complete audio fallback policy;
* surface impact, tracer, decal and HUD sprite rules.

## Animation Contract

Weapon orchestration uses semantic actions, not raw sequence names:

| Semantic action | Typical sequence aliases |
|---|---|
| `idle` | `idle`, `idle1`, `idle2` |
| `draw` | `draw`, `deploy` |
| `holster` | `holster` |
| `fire` | `shoot`, `shoot1`, `shoot2`, `shoot3`, `fire`, `fire1`, `fire2`, `fire3` |
| `reload` | `reload` |
| `empty` | `empty`, `dryfire` |
| `melee_primary_hit` | `slash`, `slash1`, `slash2`, `midslash1`, `midslash2`, `attack` |
| `melee_primary_miss` | `slash`, `slash1`, `slash2`, `midslash1`, `midslash2`, `attack` |
| `melee_secondary_hit` | `stab`, `stab_miss` |
| `melee_secondary_miss` | `stab_miss`, `stab` |
| `grenade_pullpin` | `pullpin`, `draw` |
| `grenade_throw` | `throw`, `shoot` |

These aliases are a resolution strategy, not proof that a specific local MDL
contains a sequence. PR-06 must include or prepare an inspection path that lists
sequence names and durations from the actual imported model.

Missing animation behavior:

```text
state transition may continue if gameplay is valid
diagnostics records missing animation/action/aliases
no procedural placeholder animation is created
```

## Event Timeline Contract

Presentation events can come from three sources, in this order:

1. Imported MDL/studio animation events, when exposed by the GoldSrc adapter.
2. Per-weapon timeline config with confidence metadata.
3. Minimal semantic default timing with diagnostics.

Normalized presentation events:

```text
weapon.anim_started
weapon.anim_finished
weapon.muzzle_flash
weapon.shell_eject
weapon.sound
weapon.reload.clipout
weapon.reload.clipin
weapon.reload.boltpull
weapon.reload.complete
weapon.grenade.pinpull
weapon.grenade.release
weapon.grenade.explode
weapon.melee.hit_window_start
weapon.melee.hit_window_end
weapon.impact
weapon.tracer
```

Gameplay authority remains separate: accepted firearm shots decrement ammo,
trace and apply recoil immediately. Reload ammo commit, grenade release and
melee hit windows may be delayed by explicit timeline rules.

## Audio Contract

Gameplay and weapon code request semantic audio events:

```text
weapon.<id>.draw
weapon.<id>.fire
weapon.<id>.fire_alt
weapon.<id>.fire_silenced
weapon.<id>.reload.clipout
weapon.<id>.reload.clipin
weapon.<id>.reload.boltpull
weapon.<id>.reload.slide
weapon.<id>.empty
weapon.<id>.silencer_on
weapon.<id>.silencer_off
weapon.<id>.zoom

weapon.knife.deploy
weapon.knife.slash
weapon.knife.hit
weapon.knife.hit_wall
weapon.knife.stab

weapon.grenade.pinpull
weapon.grenade.throw
weapon.grenade.bounce
weapon.hegrenade.explode
weapon.flashbang.explode
weapon.smokegrenade.explode

weapon.c4.plant
weapon.c4.beep
weapon.c4.disarm
weapon.c4.disarmed
weapon.c4.explode
```

Audio orchestration must support separate contexts:

| Context | Player node |
|---|---|
| First-person local weapon | Non-spatial or camera-local `AudioStreamPlayer`. |
| World/remote weapon | Spatial `AudioStreamPlayer3D` at muzzle/player/world position. |

If an event maps to multiple files, the provider may choose a verified available
variant or randomize among verified available variants. Fallback files borrowed
from a different weapon must be marked as fallback data, not CS 1.6 truth.

## Effects Contract

Effects are semantic and provider-driven:

| Effect | GoldSrc candidates | Runtime rule |
|---|---|---|
| Muzzle flash | `sprites/muzzleflash*.spr`, `sprites/muz*.spr` | Spawn once at muzzle socket or diagnostic fallback offset. |
| Shell casing | `models/pshell.mdl`, `models/rshell.mdl`, `models/shotgunshell.mdl` | Spawn from shell socket/timeline; no box fallback. |
| Impact puff | wall puff sprites | Surface-aware later; default only with diagnostics. |
| Ricochet/spark | spark/ricochet sprites | Material-aware and chance-based later. |
| Tracer | provider effect mapping | Not every shot; configurable cadence. |
| Explosion/smoke | grenade sprites and sounds | Projectile/world effects, not viewmodel children. |

Allowed missing behavior: disable the specific effect and report diagnostics.
Forbidden missing behavior: cube meshes, generated rectangles or old prototype
assets pretending to be CS assets.

## Lifecycle Rules

### Firearm fire

```text
input accepted
  -> validate state/cooldown/ammo
  -> decrement ammo
  -> hitscan/spread/recoil immediately
  -> play semantic fire animation
  -> play semantic fire audio
  -> spawn muzzle flash
  -> schedule shell ejection
  -> spawn impact/tracer feedback from hit result
  -> enter cooldown
  -> return idle or continue auto fire
```

### Reload

```text
input accepted
  -> reject full mag / no reserve / invalid weapon type
  -> enter reloading
  -> play reload animation
  -> schedule reload audio fragments
  -> commit ammo at explicit commit time
  -> finish reload at explicit duration or inspected animation duration
  -> return idle
```

### Weapon switch

```text
request slot
  -> reject if current state cannot interrupt
  -> current weapon switching_out
  -> play holster if available, otherwise fixed diagnostic delay
  -> instantiate target viewmodel
  -> target deploying
  -> play draw animation/audio
  -> idle
```

### Knife

```text
primary attack
  -> slash action variant
  -> swing audio immediately
  -> hit test at configured/inspected hit window
  -> flesh/wall/miss audio
  -> recovery

secondary attack
  -> stab action
  -> delayed stronger hit test
  -> recovery
```

### Grenade

```text
select grenade
  -> only if inventory count > 0
mouse press
  -> pull pin / enter holding
mouse release
  -> throw animation
  -> release world projectile at explicit release time
  -> decrement grenade inventory
  -> switch to previous available weapon, otherwise knife
projectile
  -> bounces with world physics rules
  -> explodes at fuse time
```

The previous Readytostrike issue where an empty grenade could still be selected
is explicitly forbidden.

## Viewmodel and World Profile Dependency

Weapon presentation depends on the world/viewmodel profile contract:

* GoldSrc-to-Godot unit scale must be fixed before model scale tuning.
* World FOV and viewmodel FOV must be explicit and tested.
* `v_*.mdl` should initially use model origin/attachments from the imported
  asset, not per-weapon screen-space scale hacks.
* Per-weapon offsets are allowed only as measured calibration data with source
  confidence, not as the primary way to fix an incorrect scale/FOV/profile.

## Required PR-06 Inspection Tooling

Before claiming that weapon/viewmodel orchestration is correct, PR-06 should
add or prepare a local inspection command that reports, without exposing local
absolute paths:

```text
weapon id
view/player/world model path status
viewmodel sequence names
sequence durations
available attachments / likely muzzle socket
available animation/studio events if exposed
sound event path status
sprite/effect path status
warnings for fallback/todo data
```

The output should be JSON so reviewers can compare facts between machines.

## Immediate Gaps

These are known blockers for near-complete CS 1.6 parity:

* Full CS 1.6 weapon catalog is not committed yet.
* Pilot catalog lacks `p_` and `w_` model entries.
* Actual MDL sequence names and durations are not inspected by OpenStrike yet.
* Studio events are not consumed yet.
* Reload, knife and grenade timings still include Readytostrike lab values that
  need verification.
* Weapon-specific sounds beyond the pilot set are not cataloged.
* Surface impact, decal, tracer, smoke and explosion mappings are not complete.
* HUD sprite layout and weapon selection sprites are not connected to runtime.
* Player models and third-person held weapons are not cataloged.
* Map/entity/model dependencies are deferred to BSP PRs.

## Review Checklist

Before merging weapon/viewmodel/audio/effect work, verify:

* No direct GoldSrc file paths in gameplay code.
* No proprietary asset bytes, converted caches or local paths committed.
* No placeholder model/sound/effect fallback.
* Missing assets produce diagnostics and disabled features.
* Animation aliases are backed by local inspection or clearly marked fallback.
* Event timelines carry source confidence.
* Weapon lifecycle states are explicit.
* Grenade inventory selection rules prevent selecting spent grenades.
* Changelog and this atlas are updated when new asset facts are accepted.
