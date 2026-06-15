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
