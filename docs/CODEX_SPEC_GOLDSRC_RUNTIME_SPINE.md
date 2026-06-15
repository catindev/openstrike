# Codex Spec — GoldSrc runtime spine (BSP30 reader + hull trace + PMove over trace)

**Version 2.2** — merged + byte layouts + hull-extent contract. Base: neutral-source
spine spec. Folded in: deeper clipnode box-trace algorithm, fence-texture and
moving-brush behaviour (from a second draft), with its format-fact errors corrected
and its out-of-scope parts (client prediction, multi-format Q1/BSP2/Source) removed.
v2.1 added verified byte layouts (§12) and a rejected-scope record (§13). v2.2 makes
hull-extent handling an explicit contract choice (§5.2a) and rewrites the clipnode
trace smoke as the reader's acceptance test with verified fractions (§8').

**Audience:** an implementer (Codex) building OpenStrike modules.
**Provenance:** written **from neutral, public sources** (file-format docs + an
independent physics reference), attributed per-fact in §0. It does **not**
transcribe or describe the internal source of any engine. Xash3D
(`mod_bmodel.c`, `world.c`, `sv_main.c`, `mod_studio.c`) and HLSDK
(`pm_shared.c`) are on a **denylist** (§9): do not open them while implementing
the matching module. The spec describes *what the data contains* and *how the
system behaves* — both facts, documented independently of any engine's code.

**Scope: GoldSrc BSP version 30 only.** No Quake1/BSP2/Source variants, no
32-bit-index formats. If a future need arises, that is a separate spec.

---

## 0. Sources & per-fact trail

Every non-trivial fact below traces to one of these neutral sources. "Confirmed"
= I read the full page; "snippet" = confirmed only via search excerpt (the full
page was bot-blocked at fetch time) — flagged honestly so the trail is not
overstated.

| # | Source | URL | How confirmed |
|---|---|---|---|
| S1 | TWHL Wiki — "BSP" | `https://twhl.info/wiki/page/BSP` | Confirmed (full fetch) |
| S2 | Valve Developer Community — "BSP (GoldSrc)" | `https://developer.valvesoftware.com/wiki/BSP_(GoldSrc)` | Snippet only (page bot-blocked) |
| S3 | Half-Life Physics Reference (jwchong), ch.4 | `https://www.jwchong.com/hl/movement.html` | Confirmed (full fetch) |
| S4 | In-repo `VIEWMODEL_WORLD_PROFILE.md` | — | Repo artifact (unit scale, eye offsets) |

Fact → source map (the trail):

- 15 lumps; entity lump is text; clipnodes are a **separate** collision BSP tree
  for hulls 1–3; models reference nodes (hull 0) and clipnodes (hulls 1–3) → **S1**.
- Header version is 30; `HEADER_LUMPS == 15`; clipnodes = "second BSP tree used
  only for collision"; `MAX_MAP_HULLS == 4` → **S2 (snippet)**.
- Gravity half-split (leapfrog); friction regimes; FME with air cap `L=min(30,M)`;
  edgefriction `ef=2`; hull half-heights `Hz` = 36 standing / 18 ducked; 4-iteration
  position update → **S3**.
- Unit scale 0.025, GoldSrc→Godot mapping, eye offsets 28/12 → **S4**.

jwchong (S3) is CC BY-NC-ND: behaviour is described here **in our own words**, not
copied. File-format facts and movement behaviour are not copyrightable; only an
engine's specific source expression is — hence the §9 denylist.

---

## 1. Architectural thesis (the discriminator)

> **If Godot owns any gameplay-authoritative truth, it is a prototype. If Godot is
> render + I/O only, and OpenStrike owns simulation, collision, and state, it is an
> engine.**

Movement and collision are authoritative in OpenStrike, traced against GoldSrc
hulls. Godot renders. `CharacterBody3D.move_and_slide()` must **not** drive
authoritative player motion.

```
input → ClientCommand
      → LocalGameServer.fixed_tick (fixed timestep)
        → PlayerMoveService (PMove) over TraceBackend
        → entities / rules
        → Snapshot
      → Presentation (Godot: camera, meshes, audio) reads Snapshot, owns nothing
```

---

## 2. Build order (closes the current regression first)

The walkable lab currently holds a **duplicated movement copy** that re-introduced
the air-acceleration parity bug. Consolidating movement behind a trace interface is
therefore steps 1–2, **before** the larger BSP reader.

1. **`TraceBackend` interface + `GodotSceneTraceBackend`** (wraps existing imported
   Godot collision). No new parsing.
2. **`PlayerMoveService` (PMove)** depending only on `TraceBackend`. Delete the lab's
   duplicated `_accelerate/_apply_friction/_wish_direction`; the lab calls this
   service. Removes the duplication and the regressed air-accel in one step.
3. **`BspMapResource` typed reader** (§4).
4. **`BspClipnodeTraceBackend`** (authoritative hull trace, §5).
5. **`LocalGameServer.fixed_tick`** (§7).
6. Entity adapters, then weapons/rules (later).

---

## 3. Modules

```
src/core/bsp/
  bsp_binary_reader.gd       # little-endian struct reads from a byte buffer
  bsp_lump_table.gd          # header (version==30) + 15 lump dir entries
  bsp_map_resource.gd        # typed lumps as data (NOT a PackedScene)
  bsp_entity_lump.gd         # parse entity text block → array of dictionaries
  bsp_collision.gd           # planes + clipnodes → hull trees (hulls 1..3)

src/core/collision/
  trace_backend.gd           # interface (§6)
  collision_trace.gd         # result: fraction, endpos, normal, contents, hit, start_solid
  collision_hull.gd          # hull mins/maxs (point / standing / duck)
  godot_scene_trace_backend.gd   # backend A (interim, non-parity)
  bsp_clipnode_trace_backend.gd  # backend B (authoritative)

src/core/console/
  movevars_snapshot.gd       # immutable snapshot of movement cvars per tick

src/game/player/
  player_state.gd            # origin, velocity, ducking, flags (GoldSrc units)
  player_move_command.gd     # F, S, U, buttons, view angles, frametime
  player_move_service.gd     # PMove (§8) over TraceBackend

src/game/server/
  local_game_server.gd       # fixed_tick (§7)
  game_snapshot.gd

src/presentation/maps/
  godot_bsp_scene_adapter.gd # optional: show the goldsrc-godot render scene
```

The `.scn` produced by `goldsrc-godot` is **presentation only**. The authoritative
map is `BspMapResource` + `bsp_collision`.

---

## 4. BSP30 typed reader (format facts — low legal risk)

A `.bsp` v30 begins with a 32-bit version (**must be 30**) followed by a directory
of **exactly 15 lumps** (`HEADER_LUMPS == 15`), each an `(fileofs, filelen)` pair
[S1, S2]. Read each lump as a typed array.

| Lump | Holds | Needed for |
|---|---|---|
| Entities | ASCII text block of all entities | gameplay (spawns, buyzone, bomb target, doors) |
| Planes | plane: normal (3×float) + distance (float) + type | nodes, clipnodes, faces |
| Vertices | points (3×float) | faces (render) |
| Nodes | rendering BSP tree (hull 0) | render + point/hull-0 trace |
| Clipnodes | **collision BSP tree (hulls 1–3)** | **player collision** |
| Models | submodels: bbox + `headnode[4]` + face range | world + brush entities |
| Faces, TexInfo, Textures, Lighting, Visibility, Leaves, MarkSurfaces, Edges, SurfEdges | rendering data | render (see §4.3) |

### 4.1 The collision/visual separation (the key fact)

Rendering geometry (Nodes, Faces) and **collision geometry (Clipnodes)** are
**separate** in the file [S1, S2]. `goldsrc-godot` provides rendering geometry only.
Authoritative movement needs the **clipnode** hulls, which this reader extracts.

Each **Model** exposes `headnode[0..3]` [S1]:

| headnode | Hull | Tree | Purpose |
|---|---|---|---|
| headnode[0] | hull 0 (point) | Nodes | **point traces: hitscan, line-of-sight, point_contents** — always present, never null |
| headnode[1] | hull 1 (standing) | Clipnodes | standing player box trace |
| headnode[2] | hull 2 (large) | Clipnodes | large entity (unused by CS players) |
| headnode[3] | hull 3 (duck) | Clipnodes | crouched player box trace |

> **Corrected fact:** hull 0 is the **point hull** and IS used — for hitscan, sight,
> and `point_contents`. It is not "unused for physics"; it is simply not the *box*
> hull used for player walking (those are hull 1/3). A prior draft wrongly called
> headnode[0] unused/nullable.

Model 0 is the world; each brush entity (`func_*`) is its own model (`*1`, `*2`, …).

### 4.2 Clipnode structure (exact bytes)

A BSP30 clipnode is **8 bytes**: `planenum` (**int32**, index into Planes) +
`children[2]` (**2× int16**) [S2]. A child `≥ 0` is the index of another clipnode;
a **negative** child is a leaf **contents** code:

| Contents | Typical value | Trace effect |
|---|---|---|
| CONTENTS_EMPTY | -1 | passable |
| CONTENTS_SOLID | -2 | stops the hull |
| CONTENTS_WATER | -3 | passable, changes movement (water physics) |
| CONTENTS_SLIME | -4 | passable, damage |
| CONTENTS_LAVA | -5 | passable, damage |
| CONTENTS_SKY | -6 | passable for movement |
| CONTENTS_CLIP | -8 | **solid to the player hull, passable to bullets** (player-clip brush) |

Full GoldSrc contents enum (VDC-confirmed): EMPTY -1, SOLID -2, WATER -3, SLIME -4,
LAVA -5, SKY -6, ORIGIN -7, CLIP -8, CURRENT_0..CURRENT_DOWN -9..-14, TRANSLUCENT
-15. For player movement, treat SOLID and CLIP as blocking; WATER/SLIME/LAVA/SKY/
EMPTY as passable (with their own effects). Hitscan ignores CLIP.

> **Corrected fact:** the clipnode is `int32 + 2×int16` = 8 bytes, not the
> "2×int16 + int16?" a prior draft listed with a question mark. BSP30 indices are
> 16-bit, capped at `MAX_MAP_CLIPNODES` (32767). No 32-bit variant in scope.

### 4.3 Visual lumps — do not parse for physics

Faces, TexInfo, Textures, Lighting, Visibility, Leaves, MarkSurfaces, Edges,
SurfEdges are **rendering** data and are not needed for collision or gameplay. They
are handled by `goldsrc-godot` for presentation; the OpenStrike reader may ignore
them. (Exception: §5.4 reads a texture's name/pixel for fence-texture pass-through.)

### 4.4 Entity lump (text → data)

A null-terminated text block of brace-delimited key/value sets; every entity has a
`classname` [S1]. Parse into an array of dictionaries; preserve unknown entities as
metadata (no crash, no discard). Of interest: `worldspawn` (map metadata, `wad`
list, `message`, `skyname`), `info_player_terrorist`/`..._counterterrorist`/
`info_player_start`/`info_player_deathmatch` (spawns), `func_buyzone`,
`func_bomb_target`/`info_bomb_target`, `hostage_entity`, `func_door`, `func_button`,
`trigger_*`.

### 4.5 Reader stages (no Godot collision involved)

1. Validate header: version 30, 15 lump entries, offsets/lengths in-bounds.
2. Build typed arrays per lump.
3. Parse entity text into key/value dictionaries.
4. Expose model `headnode[0..3]`.
5. Structured diagnostics on any malformed lump (no placeholder, no silent skip).
   Each diagnostic names the lump, the field, and expected-vs-actual (e.g. "lump 9
   CLIPNODES: filelen 1234 not divisible by 8"). Specific rules:
   - `fileofs + filelen` beyond end-of-file → that lump is treated as absent, warning emitted.
   - element count exceeds the BSP30 max → error, refuse the lump.
   - version != 30 → refuse the file (BSP30 only; no fallback to other versions).
   - **missing/empty CLIPNODES for a model → that model is non-solid** (cannot collide);
     never substitute `headnode[0]` (the point/visual tree) as a collision fallback.

---

## 5. Hulls and the clipnode trace (authoritative collision)

### 5.1 Hull sizes

Axis-aligned box hulls (GoldSrc units; z half-heights from S3, xy is the standard
human-hull width):

| Hull | Use | mins | maxs | W×D×H |
|---|---|---|---|---|
| 0 point | hitscan / sight / point_contents | (0,0,0) | (0,0,0) | 0 |
| 1 standing | standing player | (−16,−16,−36) | (16,16,36) | 32×32×72 |
| 3 duck | crouched player | (−16,−16,−18) | (16,16,18) | 32×32×36 |

`Hz` (half-height) = 36 standing / 18 ducked [S3], consistent with the profile's
eye offsets (S4).

### 5.2 Box-trace descent through the clipnode tree (behaviour)

Trace a hull from `start` to `end` through a model's clipnode tree rooted at
`headnode[hull]`, returning the first solid contact. Described behaviourally
(reimplement; do not copy any engine's trace source):

1. If the model has a non-zero `origin`/`angles` (moving brush, §5.5), transform
   `start`/`end` into the model's local space first.
2. Recursively descend from the root node with the segment `[p1=start, p2=end]` and
   a running fraction span `[t1, t2]` (initially `[0,1]`):
   - At a node, take its plane; compute signed distances `d1 = dist(p1)`,
     `d2 = dist(p2)`.
   - If both `≥ 0`: the whole segment is in front — recurse only `children[0]`.
   - If both `< 0`: recurse only `children[1]`.
   - Otherwise the plane splits the segment. Compute the crossing fraction
     `frac = d1 / (d1 − d2)`, clamped to `[0,1]`, and the split point
     `mid = p1 + frac·(p2 − p1)`. Recurse the **near** side first (the side `p1`
     is on), then the **far** side, splitting the fraction span at `frac`.
3. Contact is recorded at the transition from a non-solid side into a
   `CONTENTS_SOLID` leaf: set `fraction` to the entry fraction (with a small
   distance epsilon back-off so the hull rests just outside the plane), `end_position`
   to that point, `plane_normal` to the crossing node's plane normal (oriented to
   the side the hull came from), `hit = true`, and stop descending that branch.
4. If `start` is already inside solid, set `start_solid = true`, `fraction = 0`.
   If the **entire** segment is inside solid (never exits), also set `all_solid = true`.
5. If no solid is met, `fraction = 1`, `hit = false` (free move).

The result: `fraction ∈ [0,1]`, `end_position`, `plane_normal`, `contents`, `hit`,
`start_solid`, and the model index hit (0 = world, >0 = brush entity).

> The descent + `frac = d1/(d1−d2)` crossing is the standard convex-BSP box sweep;
> it is described here from the tree structure (S1/S2), not from engine source.

### 5.2a Hull extents vs the plane — pick ONE contract, do not mix

A box hull (not a point) contacts a plane when its **nearest face**, not its
centre, reaches the plane. There are two valid ways this is handled, and the
backend MUST choose one explicitly and test under it — mixing them double-counts
the offset:

- **Contract A — runtime plane offset (point-space clipnodes).** The clipnode
  planes are stored for a point, and the trace shifts each plane by the hull's
  projected half-extent before the sign test:
  `offset = |n.x|·ext.x + |n.y|·ext.y + |n.z|·ext.z`, where `ext` is the hull
  half-size (standing: 16,16,36). For a standing hull traced along the path
  `centre x=32 → x=−32` toward a solid plane at `x=0`, the **centre** contacts at
  `x=16` (`fraction = (32−16)/(32−(−32)) = 0.25`).
- **Contract B — pre-expanded clipnodes (hull-space planes).** GoldSrc compiles a
  **separate clipnode tree per hull** (hulls 1–3), so the compiler may already
  have written planes in hull space. If so, the trace applies the centre directly
  with **no** runtime offset; for the same path `centre x=32 → x=−32` the centre
  still contacts at `x=16` (`fraction = 0.25`) because the stored plane already
  sits at `x=16` rather than `x=0`.

> Note: keep the **trace path** (`x=32 → x=−32`) distinct from the **contact
> point** (`x=16`). Both contracts produce the identical observable result
> (`fraction = 0.25`) on that path; they differ only in *where the offset lives*
> (runtime vs compiled-in). A test fixture must use the full path `x=32 → x=−32`,
> not `x=32 → x=0`, or the fraction denominator changes.

> **Not an asserted fact, a choice to verify.** This spec does not claim which is
> true for BSP30 without verification — whether hull expansion lives at compile
> time (Contract B) or must be applied at runtime (Contract A) is a property of the
> clipnode data that the implementer must confirm against neutral sources or by
> inspecting a real compiled map. **Choose one contract, record it in
> `DECISIONS.md`, and make the synthetic fixtures declare which plane-space they
> use (§8').** Applying a runtime offset (A) on top of already-expanded planes (B)
> is a silent double-offset bug. The §8' standing-hull test guards the chosen
> contract only if the fixture states its plane-space.

### 5.3 PointContents

For an absolute point `p`, walk the same clipnode tree (hull 0 for a true point, or
the relevant hull) following the plane sign at each node until a leaf; return its
contents code. When multiple models overlap (e.g. a water brush volume), the
highest-priority contents wins (SOLID > LAVA > SLIME > WATER > EMPTY). Used to test
water level, sky, and whether a candidate position is inside a wall.

### 5.4 Fence / grate textures (two-pass pass-through)

Some faces use a texture whose name begins with `{` (masked/fence textures). A
trace that strikes such a face must test the actual texel at the hit point: map the
hit position to texture coordinates, read the palette index in the miptexture, and
if it is the transparent index (255), **continue** the trace through the face as if
absent; otherwise treat it as solid. This is the only reason the collision path
touches texture data (§4.3). Requires reading the face's texinfo + miptexture for
the struck surface.

### 5.5 Moving brush models (doors, platforms)

Brush entities (`func_door`, `func_platform`, rotating brushes) have their own
clipnode tree and a position/orientation. Trace by transforming the segment into
the model's local space (§5.2 step 1). A moving model may carry the player: after a
contact, the player's position is corrected together with the model's motion. A
model's volume is solid only in the positions where it actually is (a closed door
blocks; an open one does not).

### 5.6 Trace-backend test rule (the lesson this project keeps relearning)

Contact-dependent movement (step, slide, ramp) validated on **backend A (Godot
scene)** is **not** parity; tag it `confidence: godot_collision_unverified`, never a
golden value. Only free-volume movement (open-ground accel/friction/air, no contact)
is backend-independent and may be golden. Golden contact behaviour is established
only on **backend B (clipnodes)**. Do not let backend-A numbers become expected
values, or replacing the backend will fail tests on correct physics.

---

## 6. `TraceBackend` interface

```gdscript
func trace_hull(start: Vector3, end: Vector3, hull: OpenStrikeCollisionHull) -> OpenStrikeCollisionTrace
func point_contents(position: Vector3) -> StringName    # &"solid"/&"empty"/&"water"/&"sky"/&"slime"/&"lava"
```

`OpenStrikeCollisionTrace`: `fraction: float`, `end_position: Vector3`,
`plane_normal: Vector3`, `contents: StringName`, `hit: bool`, `start_solid: bool`,
`all_solid: bool`, `model_index: int`.

Both backends satisfy this identically; `PlayerMoveService` never knows which it
has. This is the seam that makes movement testable now (A) and authentic later (B).

---

## 7. `LocalGameServer.fixed_tick` (server-authoritative, even solo)

```
fixed_tick(dt):
  collect ClientCommands
  movevars = MovevarsSnapshot.from(cvar_registry)   # immutable this tick
  for each player: PlayerState = PlayerMoveService.move(state, command, movevars, trace_backend)
  run entity/trigger tests (buyzone, bomb target, doors) via trace/point_contents
  run weapon/rules systems (later)
  emit GameSnapshot
  clear transient per-tick events
```

Fixed timestep (repo uses 100 Hz / `sim_tick_hz`). Presentation reads the snapshot;
it decides no gameplay.

---

## 8. PMove behaviour (reimplement from S3, in our own words)

Horizontal vectors are 2D on the xy plane. Per-tick order:

**(a) Gravity, first half (leapfrog).** Before acceleration and the position update:
`vz -= 0.5 · g · dt`, `g = sv_gravity · entity_gravity` (entity_gravity normally 1).
Second half applied after the move. Half-split makes jump height/trajectory
frame-rate-independent; full gravity before the move is the wrong (Euler)
integration. [S3 §4.1]

**(b) Friction** (on ground, before acceleration; horizontal). `E = sv_stopspeed`
(CS 1.6: 75), `k = sv_friction · entity_friction · edgefriction` (sv_friction ≈ 4;
edgefriction 1, or **2** near a ledge — (c)). With current speed `‖v‖`:
- `‖v‖ ≥ E`: `v *= (1 − dt·k)` (geometric);
- `max(0.1, dt·E·k) ≤ ‖v‖ < E`: `v −= dt·E·k · v̂` (arithmetic);
- else: `v = 0`. [S3 §4.2]

**(c) Edgefriction.** ~16 units ahead of the player at foot level, trace the hull
~34 units straight down; if it hits nothing (a ledge), `edgefriction = 2` for this
tick, else 1. Foot level uses `Hz` = 36/18. Requires the trace backend. [S3 §4.2.1]

**(d) Acceleration — the FME** (ground and air share this; the air cap is the only
difference). Wish dir from forward/side with pitch zeroed:
`â = (F·f̂ + S·ŝ)/‖F·f̂ + S·ŝ‖`. `M = min(sv_maxspeed, sqrt(F²+S²))`.
`A = sv_accelerate` (ground) or `sv_airaccelerate` (air).
`L = M` (ground) or **`L = min(30, M)`** (air).
- `γ1 = entity_friction · dt · M · A`  ← **uses `M`**
- `γ2 = L − λ(v)·â`                     ← uses `L`
- `μ = min(γ1, γ2)` if `γ2 > 0`, else `0`
- `v' = λ(v) + μ·â`   [S3 §4.3]

> **Parity-critical:** `γ1` uses **`M`**, not `L`. Only `γ2` uses the air cap
> `L=min(30,M)`. Using `L` in `γ1` is the air-accel bug that makes airstrafing ~10×
> too weak — the exact regression already present in the lab's duplicated copy. The
> §8' air-strafe smoke guards it (verified: correct form gains +141 u/s over 1 s of
> optimal strafing; bug gains +2).

**(e) Position update + collision (4-iteration trace-slide-step).** Update position
by tracing the hull from `r` toward `r + dt·v'` in up to **4** iterations: each
traces, moves to the contact fraction, and if blocked removes the into-plane
velocity component (slide) before the next iteration; stop early on a clear trace
(fraction 1). On a blocked walk move, also try a **step**: lift by `sv_stepsize`
(18), move, trace down, keep whichever attempt advanced farther. Requires the trace
backend. [S3 §4.5] This is what `move_and_slide` superficially resembles but does
differently — hence the custom trace.

**(f) Gravity, second half.** `vz -= 0.5 · g · dt`.

**(g) Velocity clamp.** Each component clamped to `±sv_maxvelocity` (2000),
component-wise (preserves the diagonal-speed quirk; do not clamp the magnitude).

Movevars come from the cvar registry as an immutable per-tick snapshot; never read
loose numbers into the movement code.

---

## 8'. Smoke obligations

- **Free-volume parity (golden, backend-independent):** reuse existing movement smoke
  — ground accel to maxspeed, friction stop, **air-strafe gain** (catches the
  `γ1`-uses-`L` regression). Must pass driving `PlayerMoveService`.
- **Clipnode trace proof (synthetic) — the acceptance test for the reader, not a
  later feature.** Build a synthetic BSP30 buffer: one plane `x=0, n=(1,0,0)`, one
  clipnode (front child `EMPTY`, back child `SOLID`), one GoldSrc model
  (`headnode[1]=0`). **The fixture MUST declare which plane-space it uses** (§5.2a:
  point-space → backend applies the runtime offset; hull-space → it must not), so
  the test checks the chosen contract, not a coincidental number. Required cases:
  1. **Point hull**, `x=10 → x=−10`: `hit`, `fraction ≈ 0.5` — proves tree traversal
     (offset-independent because a point has zero extent).
  2. **Standing hull** (ext.x=16), `x=32 → x=−32`: `hit`, centre contact at `x=16`,
     `fraction ≈ 0.25` — proves hull extents are applied (under the declared
     contract). Do **not** use `x=10` start here.
  3. **Standing hull starting at `x=10`**: `start_solid = true` — the hull spans
     `[−6..26]`, already overlapping solid; proves initial-penetration detection
     (this is the corrected version of an earlier bad test that wrongly expected a
     mid-segment hit).
  4. Free-volume trace (no solid crossed): `hit=false`, `fraction=1`.
  5. Invalid `planenum` / invalid child index → structured diagnostic.
  6. Empty CLIPNODES for the model → non-solid, **no** fallback to `headnode[0]`.
  7. Source-style 48-byte `dmodel_t` → rejected/diagnosed; GoldSrc layout is 64
     bytes with `headnode[4]`.
- **Fence pass-through (synthetic):** a `{`-named texture with a transparent texel
  lets a trace through at that texel and blocks elsewhere. (Deferred past the first
  collision slice.)
- **No-Godot-physics lint:** `PlayerMoveService` has no `CharacterBody3D`/
  `move_and_slide` dependency for authoritative motion.
- **BSP typed load (local, real map):** loads to `BspMapResource`, clipnode head
  nodes present for hulls 1–3, spawns parsed — local gate (real `.bsp` not in CI,
  not committed).
- **Backend-A contact not golden:** step/slide assertions on `GodotSceneTraceBackend`
  tagged `godot_collision_unverified`.
- **Corrupt/absent lump (synthetic):** a model with empty CLIPNODES loads as non-solid
  (no crash, no point-tree fallback); a lump whose length is indivisible by its record
  size yields a structured diagnostic naming lump/field/expected-vs-actual.

---

## 9. Legal provenance & denylist

- **Implement from §0 neutral sources only.** Format facts from the BSP format docs
  (S1/S2); movement behaviour in your own words from jwchong (S3) — do not copy its
  text/equations.
- **Denylist — do not open while implementing the matching module:** Xash3D
  `engine/common/mod_bmodel.c`, `engine/common/world.c`, `engine/server/sv_main.c`,
  `engine/common/mod_studio.c`; HLSDK `pm_shared/pm_shared.c`. GPL / Valve-restricted;
  reading them while writing the matching OpenStrike file destroys the clean-room
  separation.
- **Commit nothing derived from Valve assets or those sources.** No `.bsp/.mdl/.wav`
  bytes. Record the neutral sources used in `DECISIONS.md` (stub in §11).
- Attribution wording: "architecture informed by public GoldSrc format/behaviour
  documentation" — **not** "ported from Xash/pm_shared."

This spec was written without opening the denylisted files; it derives from the
public format/behaviour docs in §0.

---

## 10. Acceptance (this milestone = redefined M5 "GoldSrc runtime spine")

- `BspMapResource` loads a real BSP30 map as typed data (not only a `.scn`); clipnode
  hulls and entity lump exposed; diagnostics on malformed input.
- `TraceBackend` with two backends; `PlayerMoveService` depends only on the interface;
  no authoritative `move_and_slide`.
- Movement free-volume smoke (incl. air-strafe gain) passes through
  `PlayerMoveService`; the lab's duplicated movement is deleted.
- Clipnode box-trace descends correctly (synthetic wall/floor/fence tests pass).
- `LocalGameServer.fixed_tick` runs solo with the synthetic backend and the clipnode
  backend.
- Contact behaviour golden only on the clipnode backend; backend-A contact tagged
  unverified.
- No Valve assets/bytes, no denylisted source, committed; neutral sources recorded in
  `DECISIONS.md`.

---

## 12. Byte layouts — collision-relevant lumps (GoldSrc BSP30)

All little-endian. Sizes verified by arithmetic; field order is the GoldSrc BSP30
format. **Confirmation status:** the contents enum and `BSPLEAF` are VDC-confirmed
(snippet); `dplane_t`/`dmodel_t`/`texinfo_t` sizes are stated from the standard
BSP30 spec but the full neutral spec page (hlbsp `bspdef`) could not be fetched in
full — **the implementer should cross-check these three against the full hlbsp /
VDC GoldSrc page before relying on them.** Do not over-trust unverified field offsets.

> **Critical trap — `dmodel_t` is NOT the Source one.** GoldSrc `dmodel_t` is **64
> bytes** with **`headnode[4]`** (one head node per hull). The Source-engine
> `dmodel_t` is **48 bytes** with a **single** `headnode` and shows up first in web
> searches. Using the 48-byte Source layout here silently breaks hull selection
> (you would lose hulls 1–3). Confirm `headnode[MAX_MAP_HULLS=4]`.

```
dplane_t        (LUMP_PLANES, 20 bytes)
  float  normal[3]      // 12
  float  dist           //  4
  int32  type           //  4   (axis hint; may be ignored, recompute from normal)

dclipnode_t     (LUMP_CLIPNODES, 8 bytes)   ← collision tree, hulls 1–3
  int32  planenum       //  4   index into LUMP_PLANES
  int16  children[2]    //  4   >=0 child clipnode index; <0 = CONTENTS_* (leaf)

dmodel_t        (LUMP_MODELS, 64 bytes)     ← GoldSrc, NOT Source's 48
  float  mins[3]        // 12
  float  maxs[3]        // 12
  float  origin[3]      // 12
  int32  headnode[4]    // 16   [0]=node tree (hull0), [1..3]=clipnode trees (hulls 1..3)
  int32  visleafs       //  4
  int32  firstface      //  4
  int32  numfaces       //  4

texinfo_t       (LUMP_TEXINFO, 40 bytes)    ← only needed for fence-texture test (§5.4)
  float  vecs[2][4]     // 32   s/t projection (xyz + offset)
  int32  miptex         //  4   index into LUMP_TEXTURES
  int32  flags          //  4

BSPLEAF         (LUMP_LEAVES, 28 bytes)     ← contents/point classification (hull 0)
  int32  contents       //  4   CONTENTS_*
  int32  vis_offset     //  4   into LUMP_VISIBILITY (-1 = none)
  int16  mins[3]        //  6
  int16  maxs[3]        //  6
  uint16 first_marksurface, num_marksurfaces  // 4
  uint8  ambient_levels[4]                     // 4
```

Note: `dplane_t.normal[3]` + `dist` is all the trace needs from a plane; `type` is
an axis hint and may be recomputed. Vertices/edges/faces/lighting are not parsed for
collision (§4.3).

---

## 13. Changelog & deliberately-rejected scope (do not let this drift back)

**v2.0 → v2.1:** added §12 byte layouts (collision lumps), expanded
the contents enum (incl. `CONTENTS_CLIP`), added `all_solid` to the trace, tightened
reader diagnostics (structured, missing-clipnodes → non-solid, no point-tree
fallback), added a corrupt-lump negative smoke test.

**v2.1 → v2.2 (this revision):** §5.2a hull-extent handling rewritten as an explicit
**contract choice** (runtime offset vs pre-expanded hull-space clipnodes) — NOT an
asserted fact — with a double-offset warning and a `DECISIONS.md` record. §8' clipnode
trace smoke rewritten as the reader's acceptance test with three verified cases (point
`fraction 0.5`, standing-hull `fraction 0.25` with extents, start-in-solid
`start_solid`), the fixture required to declare its plane-space; corrected an earlier
bad standing-hull test that started already inside solid. Entity-lump parsing recorded
as deferred-not-cancelled (DECISIONS).

**Rejected on review, by design — a future reviewer should not re-add these without a
concrete need in THIS solo/BSP30 milestone:**

- **Multi-format (BSP2 / Quake1 / 32-bit indices):** not the input format (CS 1.6 is
  BSP30). Spec is BSP30-only; adding variants is speculative complexity in the most
  critical subsystem.
- **Client-side prediction / netcode / angle interpolation:** a later networked
  milestone; depends on a finished deterministic PMove + stable trace. Out of scope here.
- **BSPX / deluxemap / shadowmap / external .lit/.ent:** rendering/lighting extensions
  handled by the presentation loader (`goldsrc-godot`), not by the collision reader.
- **Bevel-plane generation:** a compiler/render concern for non-convex faces; the fence
  test needs only the struck face's s/t + texel (§5.4).
- **`headnode[1]`→`headnode[0]` collision fallback:** unsafe (point tree ≠ box hull);
  a missing clipnode tree makes the model non-solid, never falls back.

---

## 11. `DECISIONS.md` stub (paste into the repo to move the trail in-repo)

```markdown
## GoldSrc runtime spine — source provenance
- Authoritative collision = OpenStrike clipnode hull trace; Godot = renderer only.
- BSP30 format facts from: TWHL Wiki BSP (https://twhl.info/wiki/page/BSP),
  VDC BSP (GoldSrc) (https://developer.valvesoftware.com/wiki/BSP_(GoldSrc)).
- Movement behaviour from: jwchong HL Physics Reference
  (https://www.jwchong.com/hl/movement.html), described in our own words.
- Denylist (NOT opened during implementation): Xash3D mod_bmodel.c, world.c,
  sv_main.c, mod_studio.c; HLSDK pm_shared.c.
- Scope: BSP version 30 only.

## Hull-extent contract (§5.2a) — RECORD THE CHOICE
- The clipnode trace uses ONE of: (A) runtime plane offset on point-space planes,
  or (B) pre-expanded hull-space clipnodes with no runtime offset. <CHOOSE ONE>.
- Reason for the choice: <confirmed against neutral source / inspected real map>.
- Synthetic fixtures declare their plane-space so tests check the contract, not a
  coincidental fraction. Mixing A and B is a double-offset bug.

## Entity lump — deferred, NOT cancelled
- The first collision vertical slice does not implement OpenStrike-owned entity-lump
  parsing. MapEntityIndex may consume imported-scene (goldsrc-godot) metadata as a
  temporary bridge. Authoritative map entities should later come from OpenStrike's
  own entity-lump parsing, so runtime does not depend permanently on the
  presentation importer for gameplay truth.
```
