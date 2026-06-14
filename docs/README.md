# Openstrike documentation

This directory is the operational memory of the project. Every agent must read the relevant files before changing code.

## Reading order

1. `../AGENTS.md` — agent rules.
2. `LEGAL_ORIGINALITY.md` — repository content boundaries.
3. `ARCHITECTURE.md` — target Godot architecture.
4. `ROADMAP.md` — release path from `0.1.0` to `1.0.0`.
5. `kb/README.md` — knowledge base for compatibility behavior and resource formats.
6. `kb/SOURCES.md` — sources used by the knowledge base.
7. `tasks/README.md` — implementation task index.

## Documentation rule

When code changes behavior, docs must change in the same PR. When a parity fact is uncertain, write `TO VERIFY` instead of guessing.
