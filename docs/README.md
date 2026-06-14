# OpenStrike documentation

This directory is the operational memory of the project. Every AI/coding agent must read the relevant documents before changing code.

## Reading order

1. `../AGENTS.md` — mandatory agent rules.
2. `LEGAL_ORIGINALITY.md` — legal and originality boundaries.
3. `ARCHITECTURE.md` — target Godot architecture and layer boundaries.
4. `ROADMAP.md` — release path from `0.1.0` to `1.0.0`.
5. `DEVELOPMENT_PLAN.md` — planned PR sequence and acceptance criteria.
6. `ASSET_PIPELINE.md` — planned local asset loading model.
7. `KNOWLEDGE_BASE.md` — current project knowledge base.
8. `TESTING.md` — testing strategy and smoke checks.

## Documentation rule

When code changes behavior, documentation must change in the same PR.

When a parity fact is uncertain, write `TODO: verify` instead of guessing.

## Current status

`0.1.0` is a bootstrap milestone. It creates the clean Godot project, repository structure, documentation, agent instructions, legal boundaries and default cvar data. It does not implement gameplay, asset loading, movement, weapons, HUD or networking.
