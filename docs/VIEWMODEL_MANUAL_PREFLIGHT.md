# Viewmodel Manual Preflight

This document is the first PR-06 manual test point. It verifies real CS 1.6
`v_*.mdl` viewmodels through the locked OpenStrike profile before gameplay or
gunplay work is layered on top.

## Scope

This preflight checks:

* local GoldSrc VFS resolution through `user://local_goldsrc.json`;
* pilot semantic IDs from `data/assets/cs16_pilot_weapon_assets.json`;
* vendored `alanfischer/goldsrc-godot` runtime availability;
* `GoldSrcMDL.scale_factor = 0.025`;
* model load/build through `GoldSrcMDL.load_mdl()` and `build_model()`;
* extracted sequence names, fps, frame counts, bodypart count, bone count and
  skin count when the loader API exposes them;
* visual placement with identity camera-local transform and the shared
  `data/config/viewmodel_world_profile.json` FOV/scale.

It does **not** check weapon gameplay, damage, recoil, ammo, reload authority,
muzzle sockets, shell sockets or MDL animation events. The current
`goldsrc-godot` API exposes model build, sequence timing, bones, bodyparts and
skins; it does not expose attachments/sockets or animation events through
GDScript, so those fields stay `requires_openstrike_mdl_reader` until an API
spike proves otherwise.

## Prerequisites

1. Own a licensed local Half-Life / Counter-Strike 1.6 installation.
2. Configure `user://local_goldsrc.json` locally. Do not commit it.

Example:

```json
{
  "half_life_dir": "/absolute/path/to/Half-Life"
}
```

or:

```json
{
  "cstrike_dir": "/absolute/path/to/Half-Life/cstrike",
  "valve_dir": "/absolute/path/to/Half-Life/valve"
}
```

3. Run the project GDExtension bootstrap after a fresh clone, `git clean -fdx`
   or addon update:

```bash
scripts/bootstrap_gdextensions.sh
```

The adapter expects the GDExtension classes documented by that repository:
`GoldSrcMDL`, `GoldSrcSPR`, `scale_factor`, `load_mdl()`, `build_model()`,
sequence timing and bone/bodypart/skin inspection methods.

The addon is vendored under `addons/goldsrc/`, but the current committed native
binary set is macOS-only. If the platform has no matching native library,
bootstrap leaves the extension disabled and the tool reports
`goldsrc_godot_extension_missing` instead of using a placeholder or fake mesh.

## CI-safe Capability Check

This runs without real assets and is already part of `scripts/run_smoke_checks.sh`:

```bash
Godot --headless --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --capability-smoke
```

Expected on a platform without a matching native `goldsrc-godot` binary:

```text
extension_available: false
viewmodel_scene: extension_missing
attachments: requires_openstrike_mdl_reader
animation_events: requires_openstrike_mdl_reader
```

That is a valid CI result. It proves the adapter is honest about missing runtime
dependencies and does not fake sockets/events.

## Local Inspection

After configuring `user://local_goldsrc.json` and running bootstrap, run:

```bash
scripts/bootstrap_gdextensions.sh
Godot --headless --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --asset-id=weapon.ak47.viewmodel
```

Other pilot IDs:

```bash
--asset-id=weapon.usp.viewmodel
--asset-id=weapon.knife.viewmodel
--asset-id=weapon.hegrenade.viewmodel
```

The JSON output must not print local absolute paths. It should report:

* `complete: true`;
* `renderable.ok: true`;
* `renderable.metadata.scale_factor: 0.025`;
* sequence names/fps/frame counts from the real local MDL;
* `bone_count`, `bodypart_count`, `skin_count`;
* capability values for missing sockets/events as
  `requires_openstrike_mdl_reader`.

## Visual Preflight

Run without `--headless`:

```bash
scripts/bootstrap_gdextensions.sh
Godot --path . --script res://src/dev/tools/viewmodel_manual_preflight.gd -- --asset-id=weapon.ak47.viewmodel --visual
```

This opens a simple Godot window with:

* the shared profile FOV;
* `KEEP_HEIGHT`;
* the real MDL loaded through `GoldSrcMDL`;
* the MDL as a camera child at `Transform3D.IDENTITY`;
* no per-weapon scale, offset, FOV or camera transform.

If the model is mirrored, invisible, too far, too close or rotated incorrectly,
do **not** add a weapon-specific transform. Record the symptom and fix the
shared profile, loader adapter or one global post-import correction after the
calibration decision is documented in `docs/DECISIONS.md`.

## Ready for Gameplay Work

PR-06 is ready for the next gameplay-facing step only after:

* `scripts/run_smoke_checks.sh` passes;
* `scripts/check_no_forbidden_assets.sh` passes;
* local inspection succeeds for `ak47`, `usp`, `knife`, `hegrenade`;
* at least one visual preflight run confirms the shared profile path is usable
  without per-weapon transform keys;
* any orientation correction is documented as a single shared decision, not a
  per-weapon fix.
