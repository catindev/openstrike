# Asset Pipeline

This document describes the planned asset pipeline for OpenStrike. The current
implementation covers local config validation, raw VFS lookup and raw byte
reads. Real pilot viewmodel rendering uses the vendored
`alanfischer/goldsrc-godot` GDExtension through an OpenStrike adapter; broader
format parsing and OpenStrike-owned MDL/socket/event readers remain later
milestones.

## User configuration: `local_goldsrc.json`

OpenStrike will read assets from the user's local installation of *Counter-Strike 1.6* / *Half-Life*.

The local path configuration will be stored in a user-specific `local_goldsrc.json` file. This file is not part of the repository and must never be committed.

The config points to the user's local installation directories. It can derive
roots from `half_life_dir`:

```json
{
  "half_life_dir": "/path/to/Half-Life"
}
```

or use explicit roots without `half_life_dir`:

```json
{
  "cstrike_dir": "/path/to/Half-Life/cstrike",
  "valve_dir": "/path/to/Half-Life/valve"
}
```

The initial schema is documented in `LOCAL_GOLDSRC_CONFIG.md`. The file is
ignored by `.gitignore`; users create it locally.

## OpenStrikeAssetManager

`OpenStrikeAssetManager` provides the first unified interface for local asset
resolution.  It will:

* Parse `local_goldsrc.json` and validate the paths.
* Resolve files through a GoldSrc-like VFS before any parser runs.
* Offer a single API for requesting assets by semantic ID or type (e.g. textures, models, sounds).
* Delegate to specific providers (BSP, MDL, WAD, SPR, WAV) based on file extension.
* Cache loaded resources where appropriate.

The first asset-manager milestone only locates and reads raw files. Format
parsing comes later, after path resolution, overlay order and diagnostics are
stable.

The current PR-05 provider-contract step adds semantic manifest loading on top
of that raw VFS layer:

* `OpenStrikeAssetManifest` validates a JSON-compatible dictionary of semantic
  asset IDs.
* `OpenStrikeAssetReference` records one semantic ID, asset type, provider and
  GoldSrc-relative path.
* `OpenStrikeGoldSrcAssetProvider` resolves references through the configured
  VFS and returns `OpenStrikeAssetProviderResult` objects.
* `OpenStrikeAssetProviderResult` carries provider diagnostics, VFS resolution
  details and raw bytes for later MDL/SPR/WAV parsers.
* `OpenStrikeAssetInspectionReport` summarizes manifest preflight checks so
  future catalogs can be validated before presentation code depends on them.

This provider step intentionally does **not** decode MDL, SPR or WAV formats
yet. It proves that presentation code can ask for semantic IDs such as a
viewmodel, sprite or sound without knowing physical paths. Format-specific
decoding and a real CS 1.6 asset catalog must be added in later, separately
reviewable PRs after path and animation facts are verified.

Manifest inspection is a cheap preflight path. `inspect_asset()` and
`inspect_manifest()` resolve semantic entries through the VFS but do not read
asset bytes. A missing physical file is reported as a missing asset, while
manifest/provider errors are counted as invalid entries. This distinction keeps
local installation diagnostics useful without treating every absent optional
asset as a broken manifest.

Semantic asset manifests are intentionally strict before presentation consumes
them. The current contract accepts only:

| Type | Provider | Required extension |
|---|---|---|
| `view_model` | `goldsrc` | `.mdl` |
| `sprite` | `goldsrc` | `.spr` |
| `sound` | `goldsrc` | `.wav` |

Manifest paths must be non-empty relative GoldSrc paths with forward slashes.
Absolute paths, URI-style paths, Windows absolute paths, `..` traversal and
backslash paths are rejected during manifest validation rather than deferred to
runtime presentation code.

Top-level manifest metadata is preserved in `OpenStrikeAssetManifest` and
`OpenStrikeAssetInspectionReport` so dev tools can identify which catalog was
checked and why.

Example manifest shape:

```json
{
  "assets": {
    "weapon.ak47.viewmodel": {
      "type": "view_model",
      "provider": "goldsrc",
      "path": "models/v_ak47.mdl",
      "metadata": {
        "format": "mdl"
      }
    }
  }
}
```

The first project-owned catalog is
`data/assets/cs16_pilot_weapon_assets.json`. It contains only semantic IDs,
asset types, GoldSrc-relative paths and metadata for the pilot weapon
presentation set: AK-47, USP, knife, HE grenade and muzzleflash sprites. These
relative file names were checked against a local licensed Steam Counter-Strike
1.6/Half-Life installation on 2026-06-14. The catalog deliberately excludes
candidates that did not resolve in that installation, such as
`sound/weapons/usp_unsil-2.wav` and `sound/weapons/grenade_throw.wav`.

The catalog is still data, not decoded presentation. Future PRs must add
format parsers, animation alias tables and viewmodel orchestration separately.

## Local catalog inspection tool

Developers can preflight the pilot catalog against their own licensed local
installation with:

```sh
Godot --headless --path . --script res://src/dev/tools/asset_catalog_inspect_local.gd -- --config=user://local_goldsrc.json --catalog=res://data/assets/cs16_pilot_weapon_assets.json
```

`--config` defaults to `user://local_goldsrc.json`; `--catalog` defaults to
`res://data/assets/cs16_pilot_weapon_assets.json`. The tool uses
`OpenStrikeAssetManager`, `OpenStrikeGoldSrcLocalConfig`,
`OpenStrikeGoldSrcVFS` and `OpenStrikeAssetInspectionReport`; it does not
decode MDL, SPR or WAV data. `--summary-only` suppresses per-entry output for
CI-style logs.

The report is JSON intended for developer diagnostics. It includes manifest
metadata, total/resolved/missing/invalid counts, per-type counts and per-entry
status. It intentionally omits local absolute paths, VFS roots,
`resolved_path` and VFS `tried` paths so reports can be shared in reviews
without exposing a developer's machine layout.

CI runs the same command in `--synthetic-smoke --summary-only` mode, which
creates temporary synthetic files under `user://` for every catalog path. This
validates the tool and manifest contract without requiring a local
Counter-Strike installation.

## Viewmodel manual preflight

`alanfischer/goldsrc-godot` is vendored under `addons/goldsrc/`. Developers can
preflight real pilot viewmodels through the locked OpenStrike profile after
bootstrap enables the GDExtension for the current platform:

```sh
scripts/bootstrap_gdextensions.sh
Godot --headless --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --asset-id=weapon.ak47.viewmodel
Godot --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --asset-id=weapon.ak47.viewmodel --visual
```

This tool resolves pilot semantic IDs through the existing
`OpenStrikeAssetManager` and VFS, loads real MDL files only from the local
licensed install, applies `data/config/viewmodel_world_profile.json`, and
redacts local absolute paths from JSON reports. It must not be replaced by
per-weapon transform tuning.

The current vendored dependency includes macOS native libraries. Platforms
without a matching `addons/goldsrc/bin` library keep the adapter in the
`extension_missing` state; this is intentional for CI until additional native
builds are added.

## GoldSrc VFS

The VFS is responsible for resolving paths from the user's configured
installation. It should support:

* `cstrike/` and `valve/` search roots.
* Mod-over-base overlay semantics.
* Case-insensitive lookup for files from case-sensitive host filesystems.
* Structured diagnostics for missing roots, missing files and ambiguous assets.

PAK and WAD container parsing can be added after filesystem lookup is stable.

Initial implementation classes:

* `OpenStrikeGoldSrcLocalConfig` validates local config paths.
* `OpenStrikeGoldSrcVFS` resolves relative GoldSrc paths through the configured roots.
* `OpenStrikeAssetManager` exposes raw resolve/read operations.
* `OpenStrikeAssetDiagnostics` provides structured diagnostic entries.
* `OpenStrikeAssetManifest`, `OpenStrikeAssetReference`,
  `OpenStrikeGoldSrcAssetProvider` and `OpenStrikeAssetProviderResult` expose
  semantic provider requests for future presentation systems.
* `OpenStrikeAssetInspectionReport` exposes manifest preflight summary data for
  dev tools and future catalog validation.
* `OpenStrikeViewmodelWorldProfile` stores PR-06 source profile values for
  scale, mapping, eye offset and FOV derivation.
* `OpenStrikeGoldSrcRenderableProvider` bridges resolved semantic viewmodels to
  the vendored `alanfischer/goldsrc-godot` runtime classes without adding
  project-owned MDL/SPR decoders.
* `data/assets/cs16_pilot_weapon_assets.json` provides the first smoke-validated
  pilot catalog for semantic weapon presentation assets.
* `src/dev/tools/asset_catalog_inspect_local.gd` provides the opt-in local
  inspection command for checking catalogs against a real licensed
  installation while reporting only sanitised diagnostics.
* `src/dev/tools/viewmodel_manual_preflight.gd` provides the first opt-in
  visual preflight command for real local `v_*.mdl` viewmodels.

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

* Add a developer-facing panel for asset manifest inspection after the
  headless local catalog tool is stable.
* Extend the pilot catalog after additional local-installation checks and
  source classification, keeping unverified paths out of production data.
* Add PAK/WAD container lookup after raw filesystem lookup is stable.
* Add OpenStrike-owned readers only where the vendored loader API does not
  expose required facts such as viewmodel sockets or MDL animation events.
* Implement parsers for BSP, WAD, WAV and any MDL/SPR fields that remain
  unavailable through the dependency.
* Design HUD layout readers for text‑based HUD definitions.
* Create a tool to validate `local_goldsrc.json` and detect missing assets.
* Support dynamic loading/unloading of assets at runtime.

This plan will evolve as the project progresses and real‑world constraints become clearer.
