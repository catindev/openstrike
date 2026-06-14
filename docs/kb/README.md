# Knowledge base

This knowledge base stores project facts that agents must reuse instead of rediscovering them.

## Project model

Openstrike is a Godot runtime. The user provides a legal local installation. The repository ships no original game data.

Reference model:

- OpenMW: open runtime, user supplies original game data.
- OpenRA: open engine with original-data import/acquisition flows.

## Resource layout to support

The local provider must discover the common GoldSrc-style layout:

```text
cstrike/maps/
cstrike/models/
cstrike/sound/
cstrike/sprites/
cstrike/gfx/
cstrike/overviews/
cstrike/*.wad
valve/
```

The provider must not copy these files into the repository. It should index them locally and expose logical IDs to runtime code.

## Asset formats

Initial compatibility targets:

- BSP maps.
- MDL models.
- WAD texture packages.
- SPR sprites.
- WAV audio.
- TXT/RES metadata where needed.

The `goldsrc-godot` project is the current reference for Godot import feasibility. It supports Godot 4.3+ GDExtension loading for BSP, MDL, SPR, and WAD resources and documents coordinate conversion from GoldSrc Z-up to Godot Y-up with scale conversion.

## Engine behavior to recreate

The first gameplay goal is feel parity:

- fixed-tick movement;
- walking, crouch, jump, friction, gravity;
- first-person presentation timing;
- local round states;
- map entity interpretation;
- HUD and audio event timing;
- controller-friendly input as a first-class command source.

Use public SDK and engine projects only as references for behavior and names. Do not copy code.

## Movement notes

Movement must be implemented as original Godot code with deterministic tests. Constants from public references are useful but must be verified locally. Until verified, write `TO VERIFY` next to numeric values.

Debug overlay should show speed, velocity, grounded state, crouch state, friction, wish direction, and current material.

## NPC and director notes

Bot development should be native Godot code. YaPB is a useful reference for project shape and licensing, but Openstrike must not copy YaPB code.

Target architecture: lifecycle, perception, memory, navigation abstraction, squad planner, role executor, director event bus, and debug overlay.

## Controller and platforms

Controller support is not a keyboard/mouse remap. Input must produce device-neutral player commands. Menus must work without mouse. Assistance options, if added, must be explicit, configurable, and disableable for strict parity mode.

First practical target is macOS, but Windows and Linux must remain supported by architecture and release packaging.
