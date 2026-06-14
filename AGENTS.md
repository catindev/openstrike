# AGENTS.md — Openstrike agent instructions

This file is mandatory reading for every AI/coding agent before modifying the repository.

## Project identity

Openstrike is a free, cross-platform Godot runtime for users who already own a licensed Counter-Strike 1.6 installation. The repository must contain only Openstrike code, documentation, tests, generated placeholders, and metadata. It must not contain Valve, Half-Life, Steam, or Counter-Strike assets or copied SDK source.

## Read order before work

1. `README.md`
2. `docs/README.md`
3. `docs/LEGAL_ORIGINALITY.md`
4. `docs/ARCHITECTURE.md`
5. `docs/ROADMAP.md`
6. Relevant files in `docs/kb/`
7. Relevant task file in `docs/tasks/`
8. Existing code/tests in the area you touch

## Hard rules

- Do not commit proprietary game assets, local Steam paths, extracted media, screenshots from the original game, or copied SDK/source code.
- Do not present Openstrike as official, endorsed, or a replacement for the original product.
- Use Godot as the engine. Do not build a custom renderer, audio backend, window/input backend, or packaging system unless an ADR explicitly changes this.
- Access all game resources through provider abstractions. Gameplay code must use logical asset IDs, not hardcoded local paths.
- Keep movement, item simulation, game rules, and bot decisions deterministic enough for replay/debug tests.
- Update docs whenever you add or change a system.
- Mark uncertain parity values as `TO VERIFY`.

## GitHub Flow

- Work on a branch named by intent, for example `docs/openstrike-foundation`, `movement/fixed-tick`, `assets/local-provider`.
- Keep `main` releasable.
- Open a PR for every meaningful change.
- PR description must include goal, changed files, acceptance checks, asset-hygiene confirmation, and docs updated.
- Prefer small reviewable PRs.

## Done definition

A PR is not done unless it builds or is explicitly docs-only, adds no forbidden assets/local paths, updates relevant docs, includes acceptance criteria, and states what was not verified.

## Current decisions

- Openstrike starts as a clean Godot 4.6 project.
- The previous prototypes are references only, not code to copy blindly.
- Reusable concepts: fixed simulation, player controller, asset manager, local GoldSrc provider, viewmodel orchestration, and bot/AI Director architecture.
- First practical target is macOS, while Windows and Linux must remain first-class targets.
