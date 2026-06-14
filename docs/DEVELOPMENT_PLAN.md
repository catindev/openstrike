# Development Plan

This document outlines the initial series of pull requests (PRs) planned for the OpenStrike project.  Each PR represents a focused, incremental contribution following the GitHub Flow model.  Contributors should not combine unrelated changes into a single PR.

## PR‑00 Bootstrap

**Goal:** Lay the groundwork for the project with a minimal Godot 4 project and documentation.

**Includes:**

* Create repository structure, `.gitignore` and `.gitattributes`.
* Add Godot `project.godot` file and a `Main.tscn` scene that displays a bootstrap screen with project name, version and legal notice.
* Add initial documentation: roadmap, development plan, legal originality guidelines, architecture, asset pipeline, knowledge base and testing strategy.
* Add `AGENTS.md` with rules for AI agents.

**Excludes:**

* Any gameplay code, asset loading or movement logic.
* AssetManager implementation or parsing of GoldSrc formats.
* Migration of code from Readytostrike or other prototypes.

**Acceptance criteria:**

* Project opens in Godot 4.x and runs the main scene without errors.
* Repository contains the documented structure and documentation files.
* No Valve assets or local user configuration files are present.

## PR‑01 Core utilities and diagnostics

**Goal:** Introduce foundational utilities and diagnostic tools to aid development.

**Includes:**

* Basic logging, assertions and debug utilities under `src/core/`.
* A simple diagnostics overlay or console accessible via a debug flag.
* Unit test harness setup for future modules.

**Excludes:**

* Asset loading or gameplay logic.

**Acceptance criteria:**

* Utilities can be imported from `src/core` without circular dependencies.
* Diagnostic overlay can be toggled on and off during runtime.

## PR‑02 AssetManager

**Goal:** Implement a unified `AssetManager` to locate and read GoldSrc assets from the user’s local installation.

**Includes:**

* Definition of `local_goldsrc.json` format and loading mechanism.
* Basic virtual file system abstraction to read files from `valve/` and `cstrike/` directories.
* Placeholder interfaces for BSP, MDL, WAD, SPR and WAV providers.

**Excludes:**

* Parsing of any GoldSrc file formats.
* Caching or conversion of assets.

**Acceptance criteria:**

* Given a valid `local_goldsrc.json`, the `AssetManager` can locate and read raw bytes from expected directories.
* Appropriate error handling is implemented when the configuration is missing or invalid.

## PR‑03 GoldSrc VFS

**Goal:** Provide a virtual file system layer that mimics GoldSrc’s search paths and file resolution rules.

**Includes:**

* Resolution order for game directories, mod directories and PAK files.
* Support for searching for files by extension and name.

**Excludes:**

* Parsing of PAK, WAD or BSP archives themselves.

**Acceptance criteria:**

* The VFS correctly resolves file paths in unit tests across typical GoldSrc directory structures.

## PR‑04 Movement parity

**Goal:** Implement a player controller that matches *Counter‑Strike 1.6* movement behaviour.

**Includes:**

* Physics constants (gravity, friction, stopspeed, stepsize, etc.) loaded from cvars.
* Basic walking, jumping and air movement respecting GoldSrc limits.

**Excludes:**

* Weapon handling, animations or view bobbing.

**Acceptance criteria:**

* Movement telemetry matches expected ranges from the knowledge base (e.g. maxspeed 320, air wishspeed cap 30).

## PR‑05 Cvars/config/binds

**Goal:** Introduce a cvar system and configuration/binding management.

**Includes:**

* Data structures for console variables with default values (see `data/cvars/default.cfg`).
* Parsing of configuration files and user binds.
* Command registration mechanism for developer console.

**Excludes:**

* Networking or remote console features.

**Acceptance criteria:**

* Cvars can be defined, queried and modified at runtime and saved/loaded from config files.

## PR‑06 Viewmodel/weapon presentation migration

**Goal:** Port the visual representation of weapons and hands from the prototype in a structured manner.

**Includes:**

* Scene graph components for viewmodels.
* Animation playback and recoil camera logic.

**Excludes:**

* Damage calculation or bullet simulation.

**Acceptance criteria:**

* Viewmodel animations play correctly when triggered by stub events in the game logic.

## PR‑07 Weapon server model

**Goal:** Implement the authoritative server‑side representation of weapons and ammunition.

**Includes:**

* Data structures for weapon definitions, ammo counts and firing modes.
* Basic firing and reload timers.

**Excludes:**

* Client‑side effects or audio.

**Acceptance criteria:**

* Weapon logic runs deterministically and can be tested without the client presentation layer.

## PR‑08 Combat/damage/armor

**Goal:** Add combat logic, hit detection and armor mechanics.

**Includes:**

* Hitboxes, damage scaling and falloff.
* Armor absorption and health reduction.
* Death and respawn handling.

**Excludes:**

* Networking or lag compensation.

**Acceptance criteria:**

* Damage calculations match expected values based on reference data.

## PR‑09 BSP import integration

**Goal:** Finalise integration of BSP file loading with the asset pipeline and VFS.

**Includes:**

* Parsing of GoldSrc BSP format into Godot mesh and collision objects.
* Support for lightmaps and texture lookup via WAD files.

**Excludes:**

* Visleaf culling or advanced rendering optimisations.

**Acceptance criteria:**

* BSP maps load without crashes and are navigable in a test environment.
