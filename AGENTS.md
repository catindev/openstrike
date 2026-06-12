# AGENTS.md

Instructions for AI coding agents and human contributors working on OpenStrike.

## Project intent

OpenStrike is a clean-room, open-source FPS engine/client experiment. It targets modern macOS first and can read compatible local resource formats from directories configured by the user.

The repository must remain independent. Do not add proprietary code, proprietary assets, trademarks, logos, original UI, leaked code, decompiled code, or copied gameplay tables.

## Legal and asset rules

Hard rules:

- Do not commit proprietary assets.
- Do not commit extracted local user resources.
- Do not commit original game code, leaked code, decompiled code, or SDK-derived implementation code unless its license has been explicitly reviewed and documented.
- Do not use protected branding, logos, original UI, or original team or item names as project content.
- Do not implement DRM bypass, anti-cheat bypass, official server connectivity, or official network protocol compatibility.
- Treat user resource directories as read-only.
- Do not write caches next to user resource directories.
- Do not upload user resource paths, filenames, or local inventory into issues unless needed for debugging and scrubbed when possible.

Allowed:

- Clean-room loaders for documented or reverse-engineered file formats.
- Read-only inspection tools.
- Synthetic test fixtures created specifically for this repository.
- Original or explicitly open-source assets with license records.

## Current architecture

Read these files before making changes:

- `README.md` - project overview and build commands.
- `CHANGELOG.md` - chronological project history.
- `docs/README.md` - documentation index.
- `docs/project-status.md` - current state and validated milestones.
- `docs/roadmap.md` - issue-backed roadmap.
- `docs/architecture.md` - module layout.
- `docs/legal_policy.md` and `docs/asset_policy.md` - repository guardrails.
- `docs/adr/` - accepted architectural decisions.

## Workflow rules

1. Start from the latest `main` unless the task explicitly says otherwise.
2. Work on a topic branch.
3. Keep PRs small and focused.
4. Every PR must explain:
   - summary;
   - scope;
   - non-goals;
   - test plan;
   - legal/asset safety notes when relevant.
5. Every feature PR should close or reference a GitHub issue.
6. If a task is done, close its issue and link the PR.
7. If the plan changes, update `docs/roadmap.md`, `docs/project-status.md`, or an ADR in the same PR.
8. If a new major decision is made, add an ADR.
9. If behavior changes, update `CHANGELOG.md`.

## Build commands

macOS arm64 debug:

```bash
cmake --preset macos-arm64-debug
cmake --build build/macos-arm64-debug
```

Portable debug:

```bash
cmake --preset ninja-debug
cmake --build build/ninja-debug
```

Run tests:

```bash
ctest --test-dir build/macos-arm64-debug --output-on-failure
```

Repository asset audit:

```bash
python3 tools/asset_audit/asset_audit.py
```

## Current local manual checks

Main app config validation:

```bash
./build/macos-arm64-debug/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike --validate-config
```

BSP dump tool:

```bash
./build/macos-arm64-debug/tools/bspdump/OpenStrikeBspDump /absolute/path/to/local/map.bsp
```

BSP debug viewer:

```bash
./build/macos-arm64-debug/tools/bspview/OpenStrikeBspView.app/Contents/MacOS/OpenStrikeBspView /absolute/path/to/local/map.bsp
```

Do not add the tested local map to git.

## Coding guidelines

- Prefer C++20.
- Use `namespace osk` for engine code.
- Put format-specific loaders under `engine/assets/loaders/`.
- Keep binary parsing bounds-checked.
- Avoid raw pointer parsing or struct overlays for user-provided files.
- Return controlled errors for malformed files.
- Keep tools read-only.
- Keep platform-specific code isolated under `engine/platform/` or tool-specific macOS files.
- Keep debug tools separate from final runtime architecture when useful.

## Documentation requirements

Update docs when adding:

- a new loader;
- a new tool;
- a new platform dependency;
- a new renderer backend;
- a legal or compatibility rule;
- a roadmap change;
- a completed milestone.

Use ADRs for decisions that future agents should not accidentally reverse.

## Issue hygiene

- Open issue means not done.
- Closed issue means done or explicitly not planned.
- Each closed feature issue should mention the PR that completed it.
- Avoid stale roadmap issues. Update or close them when scope changes.

## Prohibited shortcuts

- Do not copy original behavior from leaked or decompiled binaries.
- Do not use proprietary assets as test fixtures.
- Do not auto-discover or scrape user installations.
- Do not make the app depend on a specific commercial game brand.
- Do not ship generated files derived from user-provided assets.
