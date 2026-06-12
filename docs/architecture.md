# OpenStrike Architecture

OpenStrike is structured as a modular clean-room engine/client.

## Current bootstrap modules

```text
apps/client/            bootstrap executable and future game client
engine/core/            logging and low-level utilities
engine/config/          config path resolution, config template, minimal parser
engine/assets/          read-only VFS and resource indexing
tools/asset_audit/      repository guardrail against proprietary asset commits
```

## Near-term modules

```text
engine/platform/        SDL3/macOS platform layer
engine/input/           keyboard, mouse, action maps
engine/renderer/        Metal-capable renderer abstraction
engine/assets/loaders/  BSP/WAD/MDL/SPR/WAV loaders
engine/world/           map/world representation and entity adapter
engine/physics/         BSP collision, traces, player movement
engine/game/            local game rules, weapons, damage, rounds
engine/audio/           miniaudio-backed mixer and emitters
engine/ui/              original debug/runtime UI
engine/bots/            waypoint and local AI systems
engine/net/             local transport first, custom multiplayer later
```

## Resource model

The engine reads only from configured local resource roots. These roots are mounted read-only. The repo does not contain proprietary resources and the engine must not write into configured user directories.

Initial resource discovery indexes the following extensions:

- `.bsp` maps;
- `.wad` texture archives;
- `.mdl` models;
- `.spr` sprites;
- `.wav` sounds.

Actual binary format loaders will be added after the config/VFS skeleton is stable.

## Compatibility boundary

OpenStrike provides format compatibility for user-provided files. It does not load proprietary game logic binaries, connect to official servers, implement official network protocols, or bypass DRM/anti-cheat systems.
