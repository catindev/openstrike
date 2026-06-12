# OpenStrike

OpenStrike is an independent clean-room FPS engine/client experiment focused on modern macOS support and compatibility with user-provided legacy FPS resource formats.

This project is not affiliated with, endorsed by, sponsored by, or approved by Valve or any other rights holder.

The repository does not contain proprietary game assets, proprietary game code, trademarks, logos, original UI, original game data, or decompiled/leaked code.

The program may read certain legacy resource formats from files provided locally by the user. Users are responsible for ensuring they have the rights to access those files.

This project does not bypass DRM, does not connect to official servers, does not implement official network protocols, and does not include anti-cheat circumvention.

## Current status

Bootstrap phase. The repository currently contains:

- C++20 engine skeleton.
- CMake-based builds.
- macOS app bundle target.
- Config-driven read-only resource roots.
- Minimal config template generation and parser.
- Read-only directory VFS and resource index for `.bsp`, `.wad`, `.mdl`, `.spr`, and `.wav` files.
- Tooling for asset audits and future format inspection.
- GitHub Actions build/audit workflow.

## Repository rules

Do not commit proprietary assets, proprietary code, decompiled code, leaked code, trademarks, logos, original game UI, or files extracted from commercial games.

Only original or explicitly open-source assets may be committed to this repository.

## Build

```bash
cmake --preset macos-arm64-debug
cmake --build build/macos-arm64-debug
```

Portable fallback:

```bash
cmake -S . -B build/default-debug -DCMAKE_BUILD_TYPE=Debug
cmake --build build/default-debug
```

## Bootstrap CLI

Print the default config path:

```bash
OpenStrike --print-config-path
```

Validate config and print indexed resource counts:

```bash
OpenStrike --validate-config
```

Use a temporary resource root without editing config:

```bash
OpenStrike --validate-config --resource-root /absolute/path/to/user/owned/files
```

On macOS CMake builds, the executable is inside the generated app bundle:

```bash
./build/macos-arm64-debug/apps/client/OpenStrike.app/Contents/MacOS/OpenStrike --validate-config
```

## Local user resources

OpenStrike does not include game resources. Local paths to compatible user-provided files are configured through:

```text
~/Library/Application Support/OpenStrike/config.toml
```

If this file does not exist, the application creates a template config. Edit `[resources].roots` and add local directories containing files you are legally allowed to access.

Resource roots are mounted read-only and are never modified by the engine.

## License

OpenStrike is licensed under the MIT License. See `LICENSE`.
