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
* Before starting any non-trivial task, follow
  `docs/agent_context_hygiene.md`. Every project task must begin with a compact
  Task Packet and explicit Assumptions. When asked for a handoff/new chat
  summary, produce a Current Context Contract.
* Before relying on conversation history, read
  `docs/current_context_contract.md` and verify it against current repository
  and GitHub state.
* Read the documentation in `docs/` before coding.  Understand the architecture, roadmap and legal constraints.
* Before changing Godot code, GDScript, scenes, resources, dev smoke checks,
  HUD, viewmodels, effects, asset-provider code or Godot project structure,
  read `docs/AGENT_SKILLS/GODOT_OPENSTRIKE_SKILL.md`.
* Before changing movement, weapons, hit feedback, prediction, BSP collision, HUD, viewmodels or any other feel-sensitive system, read `docs/CS_1_6_FEEL.md` and keep its movement/feedback acceptance criteria in scope.
* Before changing world/viewmodel scale, GoldSrc-to-Godot coordinate mapping,
  player eye height, world camera FOV, viewmodel camera FOV or first-person
  model placement, read `docs/VIEWMODEL_WORLD_PROFILE.md`. Update that profile
  and its smoke expectations when a profile fact changes.
* Before asking a human to visually test real CS 1.6 viewmodels, read
  `docs/VIEWMODEL_MANUAL_PREFLIGHT.md` and use that path instead of per-weapon
  transform tuning.
* Before changing weapon assets, viewmodel orchestration, weapon animation
  aliases, weapon audio, muzzle flashes, shell ejection, impact effects,
  grenade presentation or HUD weapon sprites, read
  `docs/CS16_ASSET_ORCHESTRATION_ATLAS.md`. If you discover a new verified
  asset mapping, sequence fact, event timing, fallback rule or gap, update that
  atlas in the same PR.
* Before changing asset scanner output, generated asset atlas files, coverage
  reports or coverage status fields, read `docs/COVERAGE_STATUS_CONTRACT.md`.
  Edit only `gen/coverage_status_matrix.json` by hand for status vocabulary
  changes, then regenerate the schema/document artifacts with `gen/generate.py`.
* Before accepting a subjective feel claim, read `docs/DEV_LABS_METHODOLOGY.md` and map the claim to telemetry, a smoke test, a debug overlay or a planned dev lab.
* Before adding dirty experiments, unreviewed third-party code or dev-only
  comparison code, read `docs/TAINTED_LABS_POLICY.md`,
  `docs/TAINT_LEDGER.md` and `docs/PUBLIC_OPEN_SOURCE_EXIT_PLAN.md`. Tainted
  code may not be imported by `src/core`, `src/game` or `src/presentation`.
* After every user-assisted run in a test scene, inspect the trace/log
  artifacts and write a short test report with observations, telemetry facts,
  conclusions and next actions before moving on.
* Before changing BSP map loading, player spawn selection or map collision,
  read decisions 0017 and 0018 in `docs/DECISIONS.md` and the PR-07/PR-07.2
  checklists in `docs/TESTING.md`. Keep imported Godot scene collision
  distinct from GoldSrc clipnode/hull trace parity in code, docs and
  telemetry, and route spawn/entity policy through `OpenStrikeMapEntityIndex`.
* Before changing GoldSrc runtime spine, BSP30 reading, clipnode tracing,
  `PlayerMoveService` or runtime movement authority, read
  `docs/CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md` and follow only the current PR
  packet in `docs/COMPACT_PR_TASK_PACKETS.md`. Do not implement neighboring
  packets early.
* When adding or using external research, update `docs/SOURCE_CATALOG.md` with source weight and use/do-not-use rules.
* When adding, updating or relying on committed third-party code or binary
  dependencies, read and update `docs/THIRD_PARTY_DEPENDENCIES.md`. Do not
  confuse dependency code with proprietary game assets, and do not treat a
  missing license file as permission to redistribute.
* Before editing GDScript, read `docs/GDSCRIPT_AGENT_NOTES.md`.  When a Godot/GDScript parser, type-system, runtime or tooling issue slows work down, append a dated finding with the pitfall and fix there in the same PR; preserve previous agents' notes.
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
