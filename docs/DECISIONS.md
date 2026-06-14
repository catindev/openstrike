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
