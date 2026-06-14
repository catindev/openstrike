# OpenStrike documentation

This directory is the operational memory of the project. Every AI/coding agent must read the relevant documents before changing code.

## Reading order

1. `../AGENTS.md` — mandatory agent rules.
2. `LEGAL_ORIGINALITY.md` — legal and originality boundaries.
3. `DECISIONS.md` — binding implementation decisions and project boundaries.
4. `ARCHITECTURE.md` — target Godot architecture and layer boundaries.
5. `ROADMAP.md` — milestone path for the GoldSrc reimplementation.
6. `DEVELOPMENT_PLAN.md` — planned PR sequence and acceptance criteria.
7. `ASSET_PIPELINE.md` — planned local asset loading model.
8. `LOCAL_GOLDSRC_CONFIG.md` — local asset configuration and VFS path rules.
9. `CVARS_AND_CONFIG.md` — cvar registry, config and bind rules.
10. `MOVEMENT.md` — cvar-backed movement simulation scope and telemetry.
11. `CS_1_6_FEEL.md` — research baseline for movement, weapons, prediction,
    presentation and map feel.
12. `KNOWLEDGE_BASE.md` — current project knowledge base.
13. `TESTING.md` — testing strategy and smoke checks.

## Documentation rule

When code changes behavior, documentation must change in the same PR.

When a parity fact is uncertain, write `TODO: verify` instead of guessing.

Every implementation PR must update `../CHANGELOG.md` in English.

Before changing movement, weapon feel, prediction, BSP collision, viewmodels,
HUD or feedback timing, read `CS_1_6_FEEL.md` and update it or the linked
feature docs when new facts are accepted.

## Current status

`0.1.0` is a bootstrap milestone. It creates the clean Godot project, repository structure, documentation, agent instructions, legal boundaries and default cvar data. It does not implement gameplay, asset loading, movement, weapons, HUD or networking.
