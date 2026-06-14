# Openstrike

Openstrike is a free, cross-platform Godot reimplementation project inspired by preservation-oriented runtimes such as OpenMW and OpenRA. The runtime is open, but the user must provide a legally acquired Counter-Strike 1.6 installation for game assets.

Openstrike does not ship Valve, Counter-Strike, Half-Life, Steam, or Valve SDK assets/source. It loads local resources selected by the user and recreates compatible gameplay behavior through clean Godot systems, documentation, tests, and black-box parity checks.

## Goals

- Run a CS 1.6-like experience on modern platforms, with macOS as the first practical target.
- Preserve the original feel of movement, weapon handling, maps, HUD/audio timing, and round flow for players who already own the game.
- Provide a provider-based asset layer so development can begin with locally installed CS 1.6 assets and later support replacement packs.
- Add modern platform features: controller-first UX, cross-platform packaging, debug tooling, and improved bots/PVE.
- Release through GitHub Flow and versioned GitHub releases starting at `0.1.0`, with `1.0.0` reserved for full playable parity.

## Non-goals

- No bundled assets from Counter-Strike, Half-Life, Steam, or Valve SDK packages.
- No attempt to impersonate Valve, Steam, Counter-Strike, or official matchmaking services.
- No copied Valve SDK/HLSDK/ReHLDS/ReGameDLL/Xash3D source in this repository.
- No unlicensed asset flow. A valid local installation is required.

## Repository map

- `AGENTS.md` — mandatory instructions for AI coding agents.
- `docs/README.md` — documentation reading order.
- `docs/ROADMAP.md` — release roadmap from `0.1.0` to `1.0.0`.
- `docs/tasks/` — implementation tasks for agents.
- `docs/kb/` — project knowledge base about CS 1.6, GoldSrc assets, Godot architecture, movement, weapons, bots, controller support, and sources.
- `docs/LEGAL_ORIGINALITY.md` — legal/originality guardrails.

## Development model

Openstrike uses GitHub Flow: every meaningful change goes through a branch and pull request; `main` must stay releasable. Releases follow Semantic Versioning where practical: `0.x.y` is unstable development, and `1.0.0` defines the first public compatibility target.

## First local milestone

`0.1.0` is not a game release. It is the clean Godot foundation: project skeleton, local asset-provider contract, no-asset policy, fixed simulation sandbox, movement debug scene, and documentation sufficient for agents to continue without rediscovering the project from scratch.
