# Third-Party Dependencies

This file tracks third-party code and binary dependencies that are committed to
OpenStrike. It does not list reference-only documents or proprietary local game
assets.

## `alanfischer/goldsrc-godot`

Purpose:

* GoldSrc GDExtension loader for MDL, SPR, WAD and BSP workflows.
* Used by `OpenStrikeGoldSrcRenderableProvider` for real CS 1.6 viewmodel
  preflight instead of project-owned MDL/SPR decoders.

Repository:

* <https://github.com/alanfischer/goldsrc-godot>
* Upstream HEAD checked on 2026-06-15:
  `81ee009eea661da24dbf05ee302a014166afd67d`

Vendored path:

* `addons/goldsrc/`

Committed artifacts:

* GDExtension descriptor, Godot editor plugin scripts and macOS debug/release
  dynamic libraries.

Not committed:

* Valve, Half-Life or Counter-Strike asset bytes.
* Local generated imports or extracted caches.
* User-specific `local_goldsrc.json` files.

License status:

* No `LICENSE`, `COPYING` or `NOTICE` file is present in the vendored snapshot
  inspected for this PR.
* Absence of a license does not grant reuse or redistribution rights.
* The maintainer accepts this as a pre-release development risk so OpenStrike
  can keep validating local GoldSrc asset loading.
* The OpenStrike MIT license does not cover this vendored dependency.
* If license terms are added later, reread them and update this decision before
  further redistribution-sensitive work.
* Public release/package distribution must revisit, replace, exclude or
  explicitly approve this dependency. Track that status in
  `docs/TAINT_LEDGER.md` and `docs/PUBLIC_OPEN_SOURCE_EXIT_PLAN.md`.

Operational notes:

* `scripts/bootstrap_gdextensions.sh` owns local `.godot/extension_list.cfg`
  setup. Do not commit `.godot/`.
* The current vendored binary set contains macOS libraries. On platforms
  without a matching native library, bootstrap leaves the extension disabled so
  CI can still validate the honest `extension_missing` adapter path.
* On macOS, bootstrap removes `com.apple.quarantine` from vendored binaries
  when `xattr` is available. This prevents locally copied/downloaded dylibs
  from being blocked before Godot can load the GDExtension.
