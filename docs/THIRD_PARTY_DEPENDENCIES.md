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
* Project direction from the maintainer is to proceed with the dependency until
  an upstream license file appears; if license terms are added later, reread
  them and update this decision before further redistribution-sensitive work.

Operational notes:

* `scripts/bootstrap_gdextensions.sh` owns local `.godot/extension_list.cfg`
  setup. Do not commit `.godot/`.
* The current vendored binary set contains macOS libraries. On platforms
  without a matching native library, bootstrap leaves the extension disabled so
  CI can still validate the honest `extension_missing` adapter path.
* On macOS, bootstrap removes `com.apple.quarantine` from vendored binaries
  when `xattr` is available. This prevents locally copied/downloaded dylibs
  from being blocked before Godot can load the GDExtension.
