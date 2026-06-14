# Viewmodel & World Profile Contract

**Status:** Contract for PR-06A (profile preflight). Must be merged and
smoke-tested *before* any `.mdl` is rendered in a dev scene.
**Scope:** world unit scale, GoldSrc↔Godot coordinate mapping, player origin &
eye height, world camera FOV, viewmodel camera FOV, the single allowed global
correction, prohibited per-weapon hacks, and the smoke tests that prove the math.
**Non-goal:** manual weapon-by-weapon visual tuning.

## 0. Why this exists

In ReadyToStrike, world and viewmodel came in at mismatched scales and camera FOV
was eyeballed, so every weapon then needed per-weapon scale/position fixes and
hours of dev-scene tuning. OpenStrike restarted from zero to avoid exactly this.
This file is the single source of truth for the parameters above. If a model
"looks wrong," the fix is a change to this shared profile (or a content/`$origin`
issue in that one model), **never** a per-weapon transform.

Governing principle: **the CS 1.6 look is produced by uniform scale + correct
coordinate mapping + correct eye offset + correct projection, applied identically
to every asset.** Get those right once and viewmodels should enter the dev scene
without baseline per-weapon scale/position tuning; any remaining issue is
diagnosed against importer behavior, model-authored origin/pose data, and one
shared correction layer — never a per-weapon fix.

This document was reconciled against primary sources (Valve HLSDK, `goldsrc-godot`
README, Godot `Camera3D` docs). Every load-bearing number below is either quoted
from a source or verified by formula; none is asserted from intuition. Where a
value depends on the importer, the **importer's actual output is the source of
truth**, and the value here is the expectation to be confirmed by calibration.

---

## 1. Binding invariants (read first)

1. **One scale constant for everything** — world, player, eye, viewmodel, effects
   all use the same GoldSrc→Godot scale. No asset, especially no weapon, carries
   its own scale.
2. **One coordinate mapping** — the `goldsrc-godot` loader mapping (§3) is the
   only GoldSrc→Godot conversion. It is applied once; never re-applied or stacked
   with a second mapping.
3. **FOV is derived, never stored as a literal** — store the source value
   (`fov 90` at the 4:3 reference) and compute the Godot vertical FOV. `73.7398`
   and `58.7155` never appear as config values or scene literals; they exist only
   as smoke expectations.
4. **Viewmodel shares the world projection by default** — same vertical FOV as the
   world. A separate `viewmodel_fov` is a non-parity tuning knob whose default
   equals the world FOV.
5. **Placement comes from model data, not from us** — imported MDL authored
   origin/sequence/bone data is the primary source of viewmodel placement (this is
   a *baseline hypothesis to be verified*, §7, not a guarantee).
6. **At most one shared correction** — any axis/orientation fix is a single global
   post-import correction decided once by calibration (§13). Per-weapon axis/scale/
   position fixes are forbidden.

A violation of any invariant is a contract breach, not a tuning choice.

---

## 2. Source-of-truth and the two-layer distinction

Two different coordinate concerns are easy to conflate; keep them separate.

- **Layer A — imported asset geometry.** `goldsrc-godot` already converts BSP/MDL/
  SPR vertices into Godot space on import. A loaded model node is **already in
  Godot coordinates**. OpenStrike must **not** apply any further axis mapping to
  imported geometry.
- **Layer B — OpenStrike's own sim→render bridge.** The movement simulation runs
  in GoldSrc units (Z-up). To place the camera/player in the rendered scene,
  OpenStrike converts sim-space positions into Godot space — and must use the
  **same conversion the loader uses** (§3), so camera and world share one frame.

The rule that prevents double-rotation and "fixed the axes twice":

```
There is exactly one GoldSrc→Godot conversion function. The loader applies it to
imported assets; OpenStrike applies it to sim positions. It is never applied
twice to the same object, and no alternative hand-derived mapping is used as the
canonical import mapping.
```

---

## 3. Unit scale & coordinate mapping (from the loader)

### 3.1 Scale

| Key | Value | Source |
|-----|-------|--------|
| `goldsrc_unit_scale` | `0.025` | `goldsrc-godot` README: default `scale_factor = 0.025`, `1 unit = 0.025 Godot units` |

`0.025` is a **loader-alignment constant**, not a physical-world truth. The
absolute meter value is not parity-relevant (CS has no meters; FOV is an angle).
It is fixed at `0.025` **because that is the loader default**. If the loader's
scale changes, this profile changes with it — never compensate downstream with
model scale or camera offsets.

### 3.2 Coordinate mapping (canonical, from README)

The `goldsrc-godot` README documents the conversion verbatim:

```
GoldSrc uses Z-up; Godot uses Y-up. The plugin converts automatically:
Positions: (x, y, z) → (-x * scale, z * scale, y * scale)
Default scale factor is 0.025.
```

This is the **canonical** OpenStrike mapping for both Layer A and Layer B:

```
goldsrc_to_godot(v) = Vector3(-v.x, v.z, v.y) * goldsrc_unit_scale
```

This mapping is orientation-preserving: its linear part has **determinant = +1**
(verified), i.e. it does **not** mirror. (An earlier review claimed this mapping
has determinant −1 and mirrors the world; that was an arithmetic error — the
determinant is +1. No mirror.)

A previously hand-derived view-space matrix
(`godot=(-y, z, -x)`, also det +1) is **discarded**: it is a different valid
basis, not the loader's, and using it would put OpenStrike's camera in a
different frame than the imported world. Do not use it as the import mapping.

### 3.3 Orientation / `--rotate`

The `goldsrc-godot` README documents a `--rotate` flag ("rotate 180° around Y to
match alternate coordinate conventions") **in the headless BSP batch-conversion
command**, alongside `--bsp`, `--wad-dir`, `--output-dir`, `--scale`. The README's
GDScript MDL API (`scale_factor`, `load_mdl()`, `build_model()`, sequence/bone
access) does **not** document a rotate option. So the flag exists for BSP
conversion, but **it must not be assumed to exist for the MDL runtime/import
path.**

Whether imported viewmodels face the camera correctly is an **orientation**
question (position is already pinned by §3.2) and is resolved **once** by the
calibration pass (§13), which **first inspects the actual MDL import/runtime
API**. If that path exposes an equivalent global rotate/basis option, OpenStrike
picks it once and records it in `DECISIONS.md`. If it does not, OpenStrike
introduces **one shared post-import viewmodel-root correction node**. No
per-weapon rotation correction is allowed under any branch.

---

## 4. Derived scale values (consequences, not knobs)

```
72 units → 1.800   64 units → 1.600   36 units → 0.900
30 units → 0.750   18 units → 0.450   12 units → 0.300
```

These are consequences of `goldsrc_unit_scale = 0.025`, recomputed by the smoke
test, not independent constants.

---

## 5. Player origin & eye height

GoldSrc reference origin is **hull-centered** (origin at box center, not feet).
View offsets are origin-relative Z (HLSDK `dlls/util.h`: `VEC_VIEW = 28`,
`VEC_DUCK_VIEW = 12`; hull `−36..36`, duck hull `−18..18`).

| State | Hull half (origin→floor) | View offset (origin→eye) | Eye above floor |
|-------|--------------------------|--------------------------|-----------------|
| Standing | `36` | `28` | `64` |
| Ducked | `18` | `12` | `30` |

**Runtime-convention rule (do not force a movement refactor).** OpenStrike may
store runtime player position as foot-origin, hull-center-origin, or another
explicit convention. The contract is the **effective eye heights**, not the
internal origin. The chosen convention must be documented in code and covered by
smoke:

```
If runtime is foot-origin:        camera_y = floor_y  + eye_height_godot   # 64*0.025 / 30*0.025
If runtime is hull-center-origin: camera_y = origin_y + view_offset_godot  # 28*0.025 / 12*0.025
```

Store the offsets (`28`/`12`). `64`/`30` are derived (hull + offset) and
re-derived by smoke, so a future hull change can't silently desync the eye.

---

## 6. World camera FOV

### 6.1 Source value (OpenStrike policy, stated honestly)

HLSDK defines `default_fov = 90`. OpenStrike **interprets** that as the 4:3
horizontal reference for its parity profile — this is an OpenStrike architectural
decision (a Hor+ profile), not a claim that HLSDK encodes "4:3" or that this is
the only authentic widescreen treatment.

| Key | Value |
|-----|-------|
| `world_fov_horizontal_ref` | `90` (horizontal, at 4:3) |
| `reference_aspect` | `4 / 3` |
| `camera_keep_aspect` | `KEEP_HEIGHT` (mandatory) |

### 6.2 Derivation (in code + smoke; never a stored literal)

```
vertical_fov = 2 * atan( tan(deg2rad(world_fov_horizontal_ref)/2) / reference_aspect )
             = 2 * atan( tan(45°) / (4/3) ) = 73.7398°
```

Godot `Camera3D.fov` is the angle on the axis chosen by `keep_aspect`; with
`KEEP_HEIGHT` it is the **vertical** FOV. Set the camera to the derived vertical
FOV (`73.7398°`). At 16:9 the horizontal FOV then widens to `106.26°` — intended
**Hor+** behavior (vertical framing preserved, more visible horizontally).

### 6.3 The `58.7155` trap (forbidden, pinned to the lever)

If the camera instead keeps horizontal 90° fixed at 16:9 — Godot
`KEEP_WIDTH`, or any code pinning horizontal FOV across aspect ratios — the
vertical FOV collapses to `58.7155°` (Vert−): the world looks vertically
zoomed-in and the viewmodel sits wrong. `58.7155` is the **signature of a
keep-width mistake**, not an alternate profile. The smoke test asserts the lever
(`keep_aspect == KEEP_HEIGHT`), not just the arithmetic.

---

## 7. Viewmodel camera contract

1. **Projection:** same vertical FOV as the world (`73.7398°` default), same
   `KEEP_HEIGHT`. A separate `viewmodel_fov` may exist as a profile **source
   value**, defaulting to `world_fov_horizontal_ref = 90`. Any non-default value
   is non-parity unless a later dev-lab explicitly changes the parity contract and
   records the decision in `DECISIONS.md`.
2. **Placement — baseline hypothesis, to be verified (not a guarantee).** Imported
   MDL authored origin / sequence / bone data is the primary placement source.
   PR-06 must **verify** this with a shared-profile dev lab. If a model looks
   wrong, the first response is diagnostics of loader mapping, scale, FOV, eye
   offset, importer origin handling and animation pose — **not** per-weapon
   offsets. Per-weapon transforms remain forbidden either way.
3. **Depth isolation:** drawn so it never clips world geometry (separate pass /
   near depth range / dedicated render layer), matching GoldSrc's separate
   viewmodel draw. Structural requirement, not a per-weapon fix.
4. **Out of scope for the PR-06 baseline (document, don't implement):** GoldSrc
   high-FOV viewmodel position compensation. The baseline reproduces the `fov 90`
   default; record compensation as a later refinement.

---

## 8. Model scale — no duplicate scaling

All models are scaled **once**. Do not apply both importer scaling and a Node3D
scale.

```
Bad:   GoldSrcMDL.scale_factor = 0.025  AND  model_node.scale = Vector3(0.025,…)   # ×0.000625
Good:  GoldSrcMDL.scale_factor = 0.025  AND  model_node.scale = Vector3.ONE
       (or, if the provider returns already-scaled scenes: instance.scale = Vector3.ONE)
```

If using `goldsrc-godot`, the importer's `scale_factor` is the source of truth and
nothing downstream re-scales.

---

## 9. Cameras & layering

- **World camera** renders world geometry, players, props, grenades, world-space
  effects. Uses derived world vertical FOV, `KEEP_HEIGHT`, `goldsrc_unit_scale`,
  profile eye height.
- **Viewmodel camera** renders first-person weapon/hands, viewmodel-local muzzle
  flash, presentation-local shells. Must not affect gameplay authority. Initial
  projection = world projection (§7). May use its own render layer/cull mask but
  shares the base profile until a dev-lab proves otherwise.
- **HUD/crosshair** are outside this profile (except FOV acceptance screenshots).
  HUD must **not** compensate for incorrect world/viewmodel FOV.

---

## 10. Config / cvar schema

Store **source values only**; derived values are computed at runtime and never
stored as config truth (this is what keeps `90` and `73.74` from drifting apart).

| Key | Default | Status |
|-----|---------|--------|
| `goldsrc_unit_scale` | `0.025` | parity-locked (must match loader) |
| `world_fov_horizontal_ref` | `90` | parity-locked (4:3 ref) |
| `viewmodel_fov_horizontal_ref` | `90` | parity default; tuning knob |
| `view_offset_stand` | `28` | parity-locked |
| `view_offset_duck` | `12` | parity-locked |
| `camera_keep_aspect` | `KEEP_HEIGHT` | parity-locked |

**Not stored** (derived only): Godot vertical FOV, per-aspect horizontal FOV,
eye-above-floor heights, scaled unit values. If an `osk_`-style prefix is used,
keep these clearly marked as OpenStrike profile parameters, not original GoldSrc
cvars.

---

## 11. Prohibitions (the ReadyToStrike lessons, encoded)

- No per-weapon scale, position, offset, or FOV (`weapon.ak47.model_scale`,
  `weapon.usp.model_position`, `knife.viewmodel_offset`, …). A pipeline lint
  rejects such keys in the catalog/manifest.
- No derived FOV literals (`73.7398`, `58.7155`, `106.26`) in scene files or
  runtime config; only source values + the derivation function. Smoke may contain
  them solely as independently calculated expected assertions, with comments.
- No `KEEP_WIDTH` on world or viewmodel cameras.
- No second scale constant, and no double scaling (importer + Node3D).
- No second coordinate mapping; the loader mapping is canonical and applied once.
- No silent divergence from the loader: if its scale/mapping/`--rotate` behavior
  differs from this contract, update the contract to match and re-run smoke.

---

## 12. Smoke obligations (`viewmodel_world_profile_smoke.gd`)

Headless, in CI. Expected values are independently derived (formula/hand calc),
never snapshotted from the running camera.

1. **Scale:** `72*0.025==1.8`, `64*0.025==1.6`, `36*0.025==0.9`, `30*0.025==0.75`,
   `18*0.025==0.45`, `12*0.025==0.3`.
2. **Coordinate mapping (loader convention):**
   `GoldSrc(40,0,0)→Godot(-1,0,0)`, `GoldSrc(0,40,0)→Godot(0,0,1)`,
   `GoldSrc(0,0,40)→Godot(0,1,0)`; and assert the mapping's linear part has
   **determinant +1** (no mirror).
3. **Eye:** `36+28==64`, `18+12==30`, recomputed from the movement-layer hull
   constants (not hard-coded); scaled `64*0.025==1.6`, `30*0.025==0.75`.
4. **FOV math:** `derive_vertical_fov(90, 4/3) == 73.739795 ± 1e-3`;
   `horizontal_at_16:9 == 106.260205 ± 1e-2`.
5. **FOV trap guard (positive + negative):**
   `configured_camera.keep_aspect == Camera3D.KEEP_HEIGHT`;
   `configured_camera.fov == derive_vertical_fov(90, 4/3)` (i.e. `73.739795`);
   and `derive_vertical_fov(90, 16/9) == 58.7155 ± 1e-3` is recognized as the
   **wrong** KEEP_WIDTH/16:9 value and is asserted **never** to be fed to
   `Camera3D.fov`.
6. **No per-weapon transform — closed allow-list (primary) + denylist
   (secondary).** Primary: a catalog/manifest per-asset entry may carry **only**
   the approved keys (`type`, `path`, `provider`, `metadata`); any *unknown*
   entry-level key fails the lint with an explicit message. This survives renames,
   which a string denylist does not. Secondary net: grep committed `.gd`, `.tscn`,
   `.tres`, `.json` for `model_scale`, `model_position`, `viewmodel_offset`,
   `manual_fov`, `weapon_camera_offset`, `weapon_specific_transform`; the only
   permitted occurrences are this document and the smoke denylist itself.

---

## 13. Calibration protocol (the only permitted manual step)

One shared manual step, **orientation only** — not size or distance.

1. Load one reference viewmodel (`v_knife`, clear handedness) through
   `goldsrc-godot` at `scale 0.025`, camera at standing eye offset, world FOV
   derived as §6.
2. Confirm: not mirrored, not upside down, not yawed 90°; up is up, forward faces
   the camera. Decide whether the MDL path needs **no correction**, an
   **importer-supported global correction** (if the MDL API exposes one — verify,
   do not assume `--rotate` applies here, §3.3), or **one OpenStrike-owned shared
   post-import basis correction**.
3. If a residual fix is needed, express it as that **single shared post-import
   basis correction** (one global node/transform), never per weapon.
4. Lock the chosen correction (or "none") in `DECISIONS.md`. Every other model
   then uses the same scale, mapping, eye offset and FOV with **zero** further
   manual adjustment.

If step 4 later fails for a specific weapon, diagnose against the contract; do not
add a per-weapon transform.

---

## 14. PR-06A acceptance (profile preflight)

**Real assets are required for PR-06 as a whole** — the point of model
integration is to load actual `v_*.mdl` from a licensed local Half-Life/CS 1.6
installation, scale and orient them through this profile, and render them. What is
forbidden is **committing asset bytes to the repository**, not using the assets.
Two distinct things, kept separate:

- **Repository invariant (legal):** no `.mdl`/`.spr`/`.wav` bytes are committed,
  ever. Enforced by `check_no_forbidden_assets.sh`.
- **Automated CI runner:** the CI machine has no licensed install, so its
  *automated gate* runs the profile-math smoke and the synthetic provider/catalog
  plumbing smoke. This is a statement of what the CI box can check on its own — it
  is **not** permission to skip real-asset integration, and it does not mean the
  feature is "done" when synthetic smoke is green.
- **Real-asset verification:** loading, scaling and orienting real pilot
  viewmodels against the licensed local install is **required** and is the
  substance of the work; it is verified locally and in the calibration dev-lab
  (§13), against the real files, with nothing committed.

PR-06A (this preflight) is accepted when:

- [ ] Profile-math smoke passes: scale, coordinate mapping (incl. det +1), eye
      heights, FOV (incl. `KEEP_HEIGHT` positive + anti-`58.7155` negative).
- [ ] Synthetic provider/catalog plumbing smoke still passes.
- [ ] Profile **source** fields exist in config or a dedicated profile resource —
      `goldsrc_unit_scale`, `world_fov_horizontal_ref`,
      `viewmodel_fov_horizontal_ref`, `view_offset_stand`, `view_offset_duck`,
      `camera_keep_aspect` — not deferred (smoke depends on them).
- [ ] No per-weapon scale/position/FOV keys anywhere (closed allow-list lint, §12).
- [ ] `check_no_forbidden_assets.sh` passes; no asset bytes committed.

PR-06B (runtime/integration) then loads the real pilot `v_*.mdl` (e.g. `v_knife`,
`v_ak47`) from the licensed local install through the locked profile, runs the
orientation calibration (§13), and confirms they render correctly with **zero**
per-weapon tuning — still committing no bytes.

---

## 15. PR-06 non-goals

Weapon gameplay authority, shooting/damage/ammo/reload, HUD, crosshair behavior,
networking, BSP/map collision, per-weapon hand tuning, manual weapon scale
fitting. PR-06 implements only the minimum runtime path to prove:
`semantic asset id → provider → MDL scene → canonical scale/profile → stable
viewmodel rendering`.

---

## 16. Open questions (for dev-lab, not for guessing)

1. Does CS 1.6 viewmodel rendering need a separate projection profile in Godot, or
   is world-projection parity sufficient?
2. Does the MDL importer expose `$origin`/sequence transforms precisely enough for
   placement-by-construction?
3. Is one global root correction (+ `--rotate` choice) sufficient for all
   `v_*.mdl`?
4. Muzzle-flash: world-space, viewmodel-space, or hybrid?
5. Shell ejection: viewmodel-local first or world-space from the start?

These are resolved by measured dev-lab evidence, not ad-hoc placement.

---

## 17. Source references & epistemic notes

- **Eye/view offsets, hull:** Valve HLSDK `dlls/util.h` (`VEC_VIEW = 28`,
  `VEC_DUCK_VIEW = 12`), `pm_shared/pm_shared.c`. (Constants only; no code copied.)
- **`default_fov = 90`:** HLSDK / GoldSrc console default. "Interpreted as 4:3
  horizontal reference" is an OpenStrike policy, not an HLSDK string.
- **Scale `0.025`, mapping `(-x*scale, z*scale, y*scale)`, `--rotate` flag:**
  `goldsrc-godot` README (Coordinate System section). The importer's actual output
  is the source of truth; this contract's values are the expectation calibration
  must confirm.
- **`Camera3D.fov` depends on `keep_aspect`:** Godot `Camera3D` documentation.

No engine code, asset, or value is copied; this contract is original and defines
behavioral contracts only.
