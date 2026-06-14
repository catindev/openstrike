# Testing Strategy

This document outlines the testing strategy for OpenStrike.  As of milestone 0.1.0, the focus is on establishing basic smoke tests and planning for future comprehensive test suites.

## Current (PR‑00) checklist

For the bootstrap milestone, manual verification is sufficient:

* **Godot project smoke test:** Open the project in Godot 4.x and run the main scene.  Verify that the bootstrap screen appears with the project name, version and legal notice.  There should be no errors or warnings in the output.
* **No bundled Valve assets:** Search the repository for any prohibited file types (.bsp, .mdl, .spr, .wad, .wav, .bmp).  Ensure none are present.
* **Configuration files:** Ensure that no `local_goldsrc.json` or other user‑specific configuration files are committed.
* **Documentation coverage:** Confirm that documentation has been updated or created to reflect any new changes.

## Current (PR-01) checklist

For bootstrap integrity and project-contract changes, perform the following
checks:

* **Godot project smoke test:** Run `Godot --headless --path . --quit` or open
  the project manually. The project must have a valid main scene and must not
  report `no main scene defined`.
* **Documentation consistency:** Confirm that `ROADMAP.md`,
  `DEVELOPMENT_PLAN.md`, `ARCHITECTURE.md`, `ASSET_PIPELINE.md` and
  `DECISIONS.md` agree on implementation order: local config/VFS and cvars
  come before movement, viewmodel and weapon presentation work.
* **Changelog coverage:** Confirm that `CHANGELOG.md` contains an English entry
  for the PR.
* **No bundled Valve assets:** Search the repository for prohibited file types
  (`.bsp`, `.mdl`, `.spr`, `.wad`, `.wav`, `.bmp`) and ensure none are present.
* **Configuration hygiene:** Ensure that no `local_goldsrc.json` or user-specific
  path is committed.

## Future plans

As the project matures, automated testing will become essential.  Planned areas include:

* **Config loading tests:** Verify that cvar files and user configuration files load correctly and produce expected values.
* **Asset provider tests:** Unit tests for each asset provider (BSP, MDL, WAD, SPR, WAV) to ensure parsers handle valid and malformed data.
* **Movement telemetry tests:** Automated comparison of movement trajectories against golden data to ensure parity with reference behaviour.
* **Golden‑file fixtures:** For file parsers, create non‑proprietary fixtures and compare parsed output to golden results.
* **Continuous integration (CI):** Set up a CI pipeline that runs tests on each PR, builds GDExtensions with sanitizers (ASan/UBSan) and reports regressions.
* **Network simulation tests:** When networking is introduced, simulate client/server scenarios to detect desynchronisation.

Testing will be expanded incrementally with each milestone to cover new functionality.
