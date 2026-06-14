# Knowledge Base (WIP)

This document serves as a starting point for technical references used by agents and developers working on OpenStrike.  It collects facts, constants and references relevant to reimplementing *Counter‑Strike 1.6* within the Godot engine.  Entries marked with `TODO: verify` require further research or testing.

## Project goal

OpenStrike aims to deliver a faithful reimplementation of *Counter‑Strike 1.6* for owners of a licensed copy.  The game should run on modern platforms, support controllers and enable modding, while preserving the core mechanics and feel of the original.

## GoldSrc asset formats

* **BSP** – level geometry and entity data.  Contains faces, leaf nodes, lightmaps and entity lumps.
* **MDL** – studio model format for animated characters and weapons.  Stores meshes, bones, sequences and hitboxes.
* **WAD** – texture archive containing indexed BMP textures used by BSP.
* **SPR** – sprite animations used for muzzle flashes, HUD icons and other effects.
* **WAV** – uncompressed 8‑bit/16‑bit PCM audio.  GoldSrc uses WAV for all sounds.
* **HUD text files** – layout definitions for HUD elements (e.g. `sprites/hud.txt`).

## Movement parity facts

The following constants are known from public sources and prototypes.  They define player movement in *Counter‑Strike 1.6* (GoldSrc).  Values are subject to verification.

| Constant | Value | Notes |
|---------|------|------|
| Simulation tick | `100 Hz` | CS 1.6 parity movement tests use an explicit 0.01 s timestep. |
| Gravity | `800` | Vertical acceleration in units/s². |
| Ground accelerate | `5` | CS 1.6 ground acceleration coefficient. |
| Friction | `4` | Ground friction coefficient. |
| Stop speed | `75` | CS 1.6 stop speed before friction stops the player. |
| Step size | `18` | Maximum vertical step height. |
| Air accelerate | `10` | Air acceleration constant; wishspeed cap is enforced. |
| Air wishspeed cap | `30` | Maximum wish velocity while airborne; exposed as OpenStrike-specific `sv_air_max_wishspeed`. |
| Jump velocity | `270` | Initial jump impulse exposed as OpenStrike-specific `sv_jumpvelocity`; TODO: verify exact tournament build value. |
| Base maxspeed | `320` | Maximum walking speed (affected by weapon weight). |
| Max velocity | `2000` | Velocity guard for future `PM_CheckVelocity`-style behavior. |
| Edgefriction | `2` | Future edge trace friction multiplier. |
| Standing hull height | `72` | Player hull height when standing. |
| Ducking hull height | `36` | Player hull height when ducked. |
| Weapon speed modifiers | *varies* | Each weapon reduces max speed; see weapon definitions. |
| W+A fastrun first frame | `~251.24 ups` | Smoke coverage uses 250 ups weapon speed, 100 Hz and a just-pressed side button half-state. |
| W+A fastrun transient peak | `~262 ups` | Held diagonal movement should produce a short ground-speed transient, not modern no-gain normalization. |
| Bhop cap target | *TODO: verify* | Bunny hop speed cap for GoldSrc; subject to research. |

## Systems to reproduce

Reimplementing *Counter‑Strike 1.6* involves many subsystems.  Below is a non‑exhaustive list of areas to research and implement:

* **Movement** – walking, jumping, ladder movement, swimming, ducking and air control.
* **Weapons** – handling, recoil, spread, fire modes and reload timings.
* **Economy** – money, buy zones, equipment prices and round bonuses.
* **Rounds** – win conditions, match timers and team switching.
* **Bomb defusal** – planting, defusing and bomb timers.
* **Buy menu** – UI for purchasing weapons and equipment.
* **HUD** – health, armor, ammo, radar, scoreboard and crosshair.
* **Menus** – game UI screens, options and server browser.
* **Bots** – AI opponents and teammates with configurable behaviour.

## Reference sources (for verification only)

* **Valve Developer Community** – official documentation for GoldSrc mapping and modding.
* **Godot documentation** – API references for Godot 4 and GDExtension.
* **OpenMW/OpenRA** – open‑source reimplementations that inspire architecture and asset handling.
* **Xash3D FWGS** – open‑source GoldSrc engine used as a behavioural reference; code must not be copied due to GPL.
* **HLSDK** – Valve’s official SDK, used only for behaviour and format reference.
* **Readytostrike** – internal prototype; treat as reference/lab, not as a direct source.

Whenever citing numbers or behaviours from these sources, mark them as **reference only**.  Further testing should confirm their correctness within the Godot implementation.
