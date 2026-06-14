# Architecture

Openstrike is a Godot project with a provider boundary around local resources.

Layers:

- UI and settings
- Runtime logic
- Fixed simulation
- Asset manager
- Provider implementations
- Local user installation
- Godot engine services

Principles:

- Godot handles rendering, audio, input, windowing, export, and platform services.
- Runtime code asks for logical resource IDs.
- Providers translate logical IDs to local files and normalized runtime objects.
- Simulation code must not depend on render frame rate.
- Debug scenes are required for parity work.

Suggested folders:

- `scripts/assets/`
- `scripts/sim/`
- `scripts/player/`
- `scripts/rules/`
- `scripts/input/`
- `scripts/ui/`
- `scenes/debug/`
