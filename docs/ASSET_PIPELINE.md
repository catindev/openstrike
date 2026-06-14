# Asset Pipeline

This document describes the planned asset pipeline for OpenStrike.  As of version 0.1.0, no asset loading is implemented; this serves as an outline for future work.

## User configuration: `local_goldsrc.json`

OpenStrike will read assets from the user's local installation of *Counter-Strike 1.6* / *Half-Life*.

The local path configuration will be stored in a user-specific `local_goldsrc.json` file. This file is not part of the repository and must never be committed.

The future config should point to the user's local installation directories, for example:

```json
{
  "half_life_dir": "/path/to/Half-Life",
  "cstrike_dir": "/path/to/Half-Life/cstrike",
  "valve_dir": "/path/to/Half-Life/valve"
}
```

The exact schema will be finalized in the AssetManager PR. For PR-00 this file is only documented and ignored by `.gitignore`; no asset loading is implemented.

## AssetManager

An `AssetManager` module will provide a unified interface for loading assets.  It will:

* Parse `local_goldsrc.json` and validate the paths.
* Resolve files through a GoldSrc-like VFS before any parser runs.
* Offer a single API for requesting assets by semantic ID or type (e.g. textures, models, sounds).
* Delegate to specific providers (BSP, MDL, WAD, SPR, WAV) based on file extension.
* Cache loaded resources where appropriate.

The first AssetManager milestone should only locate and read raw files. Format
parsing comes later, after path resolution, overlay order and diagnostics are
stable.

## GoldSrc VFS

The VFS is responsible for resolving paths from the user's configured
installation. It should support:

* `cstrike/` and `valve/` search roots.
* Mod-over-base overlay semantics.
* Case-insensitive lookup for files from case-sensitive host filesystems.
* Structured diagnostics for missing roots, missing files and ambiguous assets.

PAK and WAD container parsing can be added after filesystem lookup is stable.

## GoldSrc providers

The following GoldSrc asset formats are supported by the original game and will be reimplemented over future milestones:

* **BSP** – binary space partitioning maps that define level geometry, entities and vis data.
* **MDL** – studio model format used for weapons, players and props.
* **WAD** – texture archives referenced by BSP files.
* **SPR** – sprite animations used for muzzle flashes, HUD icons and other effects.
* **WAV** – uncompressed 8‑bit/16‑bit PCM audio.  GoldSrc uses WAV for all sounds.
* **HUD text files** – layout definitions for HUD elements (e.g. `sprites/hud.txt`).

The engine will implement parsers or importers for each of these formats.  It may also leverage Godot’s GDExtension API for performance‑critical tasks such as BSP parsing.

## Excluded from the repository

To respect Valve’s rights, the repository must never include proprietary assets.  The following file types are explicitly excluded via `.gitignore` and must not be committed:

```
.bsp
.mdl
.spr
.wad
.wav
.bmp
```

Any extracted or imported Valve assets (e.g. cached conversions) are also disallowed.  If test fixtures are needed, they should be synthetic or based on open data.

## Future tasks

* Implement local config loading and GoldSrc VFS tests.
* Implement parsers for MDL, BSP, WAD, SPR and WAV files.
* Design HUD layout readers for text‑based HUD definitions.
* Create a tool to validate `local_goldsrc.json` and detect missing assets.
* Support dynamic loading/unloading of assets at runtime.

This plan will evolve as the project progresses and real‑world constraints become clearer.
