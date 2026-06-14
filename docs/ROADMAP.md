# OpenStrike Roadmap

OpenStrike is a Godot-based reimplementation of Counter-Strike 1.6 for
players who provide their own licensed GoldSrc installation. The roadmap is
organized around verifiable engine milestones, not calendar dates.

The project does not bundle Valve assets and does not copy Valve, HLSDK or
GPL-licensed source code. External projects are reference material only.

## Milestones

| Milestone | Goal | Acceptance signal |
|---|---|---|
| M0 | Bootstrap, project contract, diagnostics and cvar foundation. | The Godot project opens, the main scene runs, documentation agrees on legal and architectural boundaries, and cvar/config data can be loaded without gameplay dependencies. |
| M1 | Local GoldSrc asset configuration, asset manager and VFS. | A valid local installation can be configured, raw files resolve through GoldSrc-like search paths, and missing content produces diagnostics instead of placeholders. |
| M2 | Movement parity on top of cvars. | Player movement uses cvar-backed GoldSrc constants and telemetry matches expected CS 1.6 ranges. |
| M3 | GoldSrc format providers for MDL, SPR and WAV. | Weapon models, sprites and sounds load through providers without direct file paths in gameplay code. |
| M4 | Viewmodel and weapon presentation orchestration. | A CS 1.6 asset orchestration atlas and local inspection tooling back the viewmodel rig; animation aliases resolve from inspected model facts and semantic events drive sound/effects. |
| M5 | BSP map pipeline and entity metadata. | A local BSP map can be discovered, imported or loaded, entity metadata is available, and player spawn points come from map data. |
| M6 | Server-authoritative local game loop. | Offline play runs through an authoritative game layer with round state, teams and deterministic weapon state. |
| M7 | Bomb defusal MVP, economy and buy flow. | A de_ round can be played locally with money, buy zones, C4 states and win conditions. |
| M8 | Sprite HUD, menus, radar and diagnostics tools. | HUD and menus use GoldSrc data/layouts where applicable, and development tools expose asset, animation, socket and map status. |
| M9 | Bots, LAN/listen-server and additional modes. | Local bot matches and LAN listen-server play are possible; cs_/as_ modes are implemented after de_ stabilizes. |

## Near-term rule

Do not tune first-person weapons by guessing screen offsets before the asset,
socket, animation and diagnostics pipeline exists. The immediate path is:

1. Keep the project bootable.
2. Load local GoldSrc assets legally.
3. Resolve files through a proper VFS.
4. Make cvars/config authoritative for gameplay numbers.
5. Use the source catalog and dev-lab methodology for any subjective feel claim.
6. Build and maintain the CS 1.6 asset orchestration atlas before treating
   weapon models, animation timings, sounds or effects as implementation facts.
7. Add calibrated presentation only after provider, diagnostics and evidence
   boundaries are in place.
