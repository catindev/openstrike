# Testing Strategy

This document outlines the testing strategy for OpenStrike.  As of milestone 0.1.0, the focus is on establishing basic smoke tests and planning for future comprehensive test suites.

## Current (PR‑00) checklist

For the bootstrap milestone, manual verification is sufficient:

* **Godot project smoke test:** Open the project in Godot 4.x and run the main scene.  Verify that the bootstrap screen appears with the project name, version and legal notice.  There should be no errors or warnings in the output.
* **No bundled Valve assets:** Search the repository for any prohibited file types (.bsp, .mdl, .spr, .wad, .wav, .bmp).  Ensure none are present.
* **Configuration files:** Ensure that no `local_goldsrc.json` or other user‑specific configuration files are committed.
* **Documentation coverage:** Confirm that documentation has been updated or created to reflect any new changes.

## Current (PR‑01) checklist

For the core utilities and diagnostics milestone, perform the following checks:

* **Godot project smoke test:** Open the project in Godot 4.x and run the main scene. Verify that the bootstrap screen appears with the project name, version, legal notice, Godot version and diagnostics status. There should be no errors or warnings in the output.
* **Diagnostics overlay:** Ensure that a diagnostics overlay or label appears on screen (or can be enabled via a debug flag) and that the bootstrap scene uses the `bootstrap_screen.gd` script to retrieve the Godot version and status from the diagnostics utility. The labels should update dynamically to reflect these values.
* **Logging utility:** Import `Logger` from `src/core/logging.gd` in a test script and confirm that `Logger.info()`, `Logger.warn()` and `Logger.error()` output messages appropriately in the Godot console.
* **Configuration loader:** Confirm that `ConfigLoader.load_config()` can be called without errors (functionality is a placeholder for now).
* **No bundled Valve assets:** Search the repository for any prohibited file types (.bsp, .mdl, .spr, .wad, .wav, .bmp). Ensure none are present.
* **Configuration files:** Ensure that no `local_goldsrc.json` or other user‑specific configuration files are committed.
* **Documentation coverage:** Confirm that documentation has been updated or created to reflect any new changes for PR‑01.

## Future plans

As the project matures, automated testing will become essential.  Planned areas include:

* **Config loading tests:** Verify that cvar files and user configuration files load correctly and produce expected values.
* **Asset provider tests:** Unit tests for each asset provider (BSP, MDL, WAD, SPR, WAV) to ensure parsers handle valid and malformed data.
* **Movement telemetry tests:** Automated comparison of movement trajectories against golden data to ensure parity with reference behaviour.
* **Golden‑file fixtures:** For file parsers, create non‑proprietary fixtures and compare parsed output to golden results.
* **Continuous integration (CI):** Set up a CI pipeline that runs tests on each PR, builds GDExtensions with sanitizers (ASan/UBSan) and reports regressions.
* **Network simulation tests:** When networking is introduced, simulate client/server scenarios to detect desynchronisation.

Testing will be expanded incrementally with each milestone to cover new functionality.
