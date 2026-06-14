# AI Agent Guidelines for OpenStrike

This document defines strict rules for automated agents contributing to OpenStrike.  It ensures legal compliance and consistent development practices across the project.

## Project mission

OpenStrike is a **Godot‑based reimplementation** of *Counter‑Strike 1.6* that reads assets from a user's local, licensed installation.  The project exists to allow owners of the game to play on modern and unsupported platforms without bundling any proprietary data.

## Non‑negotiable legal rules

* **Do not commit Valve assets.** Never add any `.bsp`, `.mdl`, `.spr`, `.wad`, `.wav`, `.bmp` or other proprietary files from *Half‑Life* or *Counter‑Strike* to the repository.
* **Do not commit local paths or user configuration.** Files like `local_goldsrc.json` contain user‑specific paths and must never be checked in.
* **Do not copy code from Valve SDK, HLSDK or Xash3D.** These codebases are either proprietary or GPL‑licensed; referencing them for behaviour, formats, numbers or test cases is allowed, but copying code is forbidden.
* **Do not copy GPL code.** Xash3D is GPL; its source may be studied for behaviour but must not be reused in OpenStrike.
* **Mark reference sources as such.** When using behaviour or numerical values from older engines, clearly mark them as reference only in documentation; do not treat them as source code.

## Development rules

* Follow **GitHub Flow**: every task or feature is developed on a fresh branch and submitted as a pull request.  One PR should accomplish a single conceptual step.
* Read the documentation in `docs/` before coding.  Understand the architecture, roadmap and legal constraints.
* Maintain separation of concerns: `src/core` contains generic engine utilities; `src/game` holds game‑rule logic; `src/presentation` covers UI and visual representation.  Do not mix these layers.
* Do not implement gameplay features in the bootstrap PR.  Focus on establishing the skeleton and documentation.
* Avoid introducing heavy dependencies without clear justification.

## Required checks before submitting a PR

Before opening a pull request, ensure the following:

* The project opens in **Godot 4.x** without errors.
* The main scene (`res://scenes/app/Main.tscn`) runs and displays the bootstrap screen.
* No Valve assets, proprietary files or user configuration (`local_goldsrc.json`) are present in the branch.
* All relevant documentation in `docs/` is updated or extended to reflect your changes.

Failure to follow these guidelines may result in the pull request being rejected.
