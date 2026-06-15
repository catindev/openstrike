# Project Decisions

This file records decisions that affect implementation order and review
standards. New decisions should be added here when they change project
direction, legal boundaries or subsystem ownership.

## 0001. Read local licensed assets, never bundle proprietary content

OpenStrike reads Counter-Strike 1.6 and Half-Life assets from a user's local,
licensed GoldSrc installation. The repository must not contain Valve assets,
local user paths, extracted caches or committed `local_goldsrc.json` files.

## 0002. Reference external engines, do not copy their code

Xash3D, HLSDK, hlsdk-portable, Valve Developer Community and similar sources
may be used to understand behavior, file formats, public constants and test
ideas. Source code from Valve SDK, HLSDK, Xash3D or GPL projects must not be
copied, translated line-by-line or imported.

## 0003. Godot owns platform engine services

Godot provides rendering, audio playback, input, windows, threading, packaging
and writable user storage. OpenStrike should not build replacement platform
subsystems unless a concrete Godot limitation is proven.

## 0004. Keep core, game and presentation separate

`src/core` owns reusable engine facilities such as config, diagnostics, VFS and
asset providers. `src/game` owns authoritative simulation and CS rules.
`src/presentation` owns HUD, menus, viewmodels, audio/effect presentation and
client-side diagnostics. Gameplay code must not directly load GoldSrc files.

## 0005. VFS and cvars precede gameplay and presentation

The next implementation steps must establish local asset resolution and cvar
authority before movement, weapons, HUD or map gameplay. This prevents hardcoded
paths and guessed constants from leaking into gameplay code.

## 0006. Readytostrike is a lab, not a codebase to merge wholesale

Readytostrike remains useful as a prototype and validation lab for movement,
viewmodels, weapon lifecycle, effects and asset experiments. Code may be ported
only when it fits OpenStrike's `core/game/presentation` boundaries and passes
the legal rules above.

## 0007. No fake fallback content for GoldSrc assets

If a requested asset is missing, OpenStrike must show diagnostics and disable
that feature or content path. It must not generate placeholder weapons, sounds,
muzzle flashes, maps or other fake replacements that hide asset pipeline
failures.

## 0008. Changelog entries are required

Every implementation PR must update `CHANGELOG.md` in English. Documentation
and process changes are recorded there when they affect project behavior,
workflow or implementation order.

## 0009. Commit Godot UID sidecar files

Godot 4 may generate `.gd.uid` sidecar files for scripts and resources. Commit
these sidecars when they correspond to committed project files so resource UIDs
remain stable across machines, editor sessions and CI.

## 0010. Smoke checks are a merge gate

Before movement, gameplay and presentation PRs, CI must run the Godot headless
project smoke test, asset VFS smoke test, cvar/config smoke test, whitespace
check and forbidden asset scan. New subsystem PRs should extend this gate
instead of relying only on manual editor runs.

## 0011. Subjective feel claims require evidence

External research must be classified in `docs/SOURCE_CATALOG.md` before it is
used to guide implementation. Community-engineering sources such as
3kliksphilip are useful for experiment design and symptom catalogs, but they do
not replace primary GoldSrc/CS 1.6 references for exact constants.

Movement, weapon, hitbox, prediction, HUD and viewmodel feel claims must map to
telemetry, smoke tests, debug overlays or a planned dev lab described in
`docs/DEV_LABS_METHODOLOGY.md`.

## 0012. Prefix generic public GDScript class names

Generic reusable global `class_name` declarations in `src/core` use the
`OpenStrike*` prefix to avoid collisions with Godot addons, editor plugins or
future imported tooling. Domain-specific game classes keep their domain prefix,
such as `CSMovement*`, because those names describe project-owned CS-like game
simulation objects rather than generic utilities.

## 0013. Keep cvar defaults and golden tests synchronized

When a cvar is present in default config and movement smoke tests encode the
related behavior, the simulator and the independent golden expectation must be
updated together. `sv_maxvelocity=2000` is therefore implemented before asset
providers as a narrow movement-contract exception: velocity is checked
component-wise at frame start and after velocity-changing phases, the short
air-strafe golden test keeps its closed-form oracle before the cap is reached,
and the long-run air-strafe golden test uses the same documented maxvelocity
contract independently from production code. Edgefriction remains deferred
because it requires edge traces and hull collision data that PR-04E does not
introduce.

## 0014. Use goldsrc-godot through an adapter before writing decoders

PR-06 viewmodel runtime uses a thin OpenStrike adapter around
`alanfischer/goldsrc-godot` instead of adding project-owned MDL/SPR decoders.
The adapter may depend on runtime classes such as `GoldSrcMDL` and `GoldSrcSPR`
when the vendored addon is bootstrapped on a platform with a matching native
library, but CI must also pass when the extension is absent by reporting
`extension_missing`.

Capabilities are reported field by field. Loader-exposed data such as model
build, sequence names, sequence fps/frame count, bones, bodyparts and skins may
be marked `supported_by_loader_api`. Attachments/sockets and MDL animation
events remain `requires_openstrike_mdl_reader` until either the upstream API
exposes them or OpenStrike explicitly adds a reader under a separate reviewed
decision.

## 0015. Vendor goldsrc-godot as a project dependency

OpenStrike vendors `alanfischer/goldsrc-godot` under `addons/goldsrc/` so the
core asset pipeline has one reviewed dependency path instead of per-developer
symlinks, ad hoc local addon installs or project-owned duplicate decoders.
This dependency is code and native loader binaries only; Valve asset bytes,
local generated imports and user configuration remain forbidden.

`scripts/bootstrap_gdextensions.sh` owns `.godot/extension_list.cfg` setup.
The file stays git-ignored because it is Godot-local state, but the bootstrap
step is part of `scripts/run_smoke_checks.sh`. When a matching native library
exists, Godot sees `GoldSrcMDL` and `GoldSrcSPR`; when it does not, the adapter
must keep reporting `extension_missing` rather than faking renderable content.

The current vendored binary set is macOS-only. Linux CI therefore validates the
disabled-extension path until Linux binaries are added or the dependency build
becomes part of CI.

## 0016. Apply one shared viewmodel MDL basis correction

Manual PR-06 visual preflight showed that `goldsrc-godot` runtime MDL geometry
loads successfully at `scale_factor=0.025`, but the camera-local bounds for
AK-47, USP and knife sit on positive Z. Godot `Camera3D` looks along negative Z,
so identity placement puts the model behind the camera and opens a non-empty
tool window with no visible weapon.

OpenStrike therefore sets `viewmodel_basis_correction=rotate_y_180` in the
shared viewmodel/world profile and applies it once to the viewmodel root in the
manual preflight path. The correction is orientation-only: it preserves up,
handedness and scale, and introduces no position offset. Per-weapon transforms,
scale tweaks and FOV changes remain forbidden.

## 0017. Validate movement on real BSP maps before more greybox tuning

Review feedback and local ReadyToStrike experience showed that greybox-only
weapon and movement testing can push OpenStrike toward tuning symptoms in a
surrogate scene instead of reproducing CS 1.6 constraints. PR-07 therefore
starts with a walkable BSP lab on a real local map such as `maps/de_dust2.bsp`
before further subjective gunplay testing.

The first lab may use the scene collision that `alanfischer/goldsrc-godot`
generates from imported BSP geometry. That collision source must be reported as
`godot_scene_collision`, not as GoldSrc parity. GoldSrc-style clipnodes,
player hulls and trace semantics remain `requires_openstrike_bsp_reader` until
OpenStrike either owns that reader/trace path or the dependency exposes a
verified API.

Manual map tests must write telemetry under `user://telemetry/` with map path,
spawn metadata, collision source, cvar-scaled movement state, floor/wall slide
contacts and session summary. The logs are local evidence for review and must
not include committed Valve assets or local absolute paths.

The walkable lab filters known non-blocking/trigger-like entities such as
`func_buyzone`, `func_bomb_target` and `func_illusionary` out of player
collision. This is still not a final GoldSrc contents/solid implementation; it
only prevents the first manual lab from treating trigger brushes as walls.

## 0018. Add TraceBackend and MapEntityIndex before gameplay consumes BSP maps

After PR-07 and PR-07.1, the project has a useful walkable BSP lab but no
OpenStrike-owned BSP reader, clipnode traversal, `trace_hull` or
`point_contents`. OpenStrike therefore introduces a small `TraceBackend`
boundary before gameplay systems consume map collision. The current
`OpenStrikeGodotSceneTraceBackend` reports `godot_scene_collision`,
`godot_collision_unverified` and `goldsrc_parity=false`; it must not fake
GoldSrc hull trace or contents queries through Godot scene physics.

Imported entity semantics are indexed through `OpenStrikeMapEntityIndex`.
Spawn selection, buyzones, bomb targets, illusionary brushes and trigger-like
collision policy belong to that core map index rather than to a dev lab runner.
This keeps the walkable lab useful while making the next replacement point
clear: a future OpenStrike BSP reader/clipnode backend can replace the trace
backend without rewriting manual-test input, camera, audio or telemetry code.

## 0019. Introduce local game runtime skeleton before weapon loop

OpenStrike should not add weapon firing, HUD, economy or round logic directly
to dev labs. After the BSP map and trace/entity boundaries exist, the next
step is a small `src/game/runtime` session skeleton that owns fixed server
ticks, player slots, user commands, spawn assignment, round-state skeleton data
and snapshots.

This is intentionally not a full game server yet. PR-08A does not implement
weapon state, damage, objective rules, networking, bots, buy menu or HUD. It
creates the authoritative owner that later PRs can extend, preserving the
project architecture rule that even offline play flows through game-layer
authority rather than presentation or lab state.

## 0020. Require context hygiene before non-trivial agent work

Long OpenStrike sessions are vulnerable to context rot: old discussions,
superseded experiments and current decisions can blend together. Agents must
therefore normalize non-trivial tasks into a compact Task Packet and explicit
Assumptions before acting.

`docs/agent_context_hygiene.md` is the normative workflow for that process.
`docs/current_context_contract.md` is the live handoff document for new chats
and agents. It must be updated when accepted decisions, architecture state,
active risks or immediate next tasks materially change.

## 0021. Follow the GoldSrc runtime spine task packets

OpenStrike should not connect runtime movement to `LocalGameSession` before the
project owns a verifiable BSP30 collision vertical slice. The accepted runtime
spine order is now recorded in `docs/COMPACT_PR_TASK_PACKETS.md` and backed by
the contracts in `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md`.

The current cleanup package is `PR-08A.1 Runtime spawn descriptors cleanup`.
After that, the next implementation package is `PR-08B BSP30 collision vertical
slice`: a synthetic BSP30 reader/clipnode trace proof, not PMove, player
movement session integration, weapons or HUD. Agents must implement only the
current package and must not pull neighboring package scope forward.

The runtime-spine spec also records the clean-room source trail and denylist
for BSP30/collision/PMove work. Denylisted engine source files must not be
opened while implementing matching OpenStrike modules.

## 0022. PR-08B uses runtime-offset hull extents for synthetic BSP30 clipnodes

PR-08B implements the first OpenStrike-owned BSP30 collision vertical slice
only for synthetic buffers. The synthetic fixture declares its clipnode plane
as point-space (`x=0`) and `OpenStrikeBspClipnodeTraceBackend` applies
runtime hull extents over that point-space plane:

```text
offset = abs(normal.x) * ext.x + abs(normal.y) * ext.y + abs(normal.z) * ext.z
```

This is Contract A from `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md`. The choice
is intentionally scoped to the PR-08B synthetic fixture so the smoke test can
prove standing-hull contact at center `x=16` and `fraction=0.25` for
`x=32 -> x=-32` without claiming that all real BSP30 clipnode trees use
point-space planes.

Contract A is therefore not final real-map truth. It remains subject to
verification on a real BSP30 map before the backend is promoted beyond
synthetic fixtures. Future real-BSP collision work must not apply runtime
offsets on top of already pre-expanded hull-space planes. Denylisted
Xash3D/HLSDK source files were not opened for this implementation; the
implementation follows the in-repo runtime-spine spec and synthetic byte-layout
tests.
