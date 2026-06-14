# Changelog

All notable changes to this project will be documented in this file.  The format is inspired by [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

* Added `CvarRegistry`, `OpenStrikeConfigLoader` and `BindRegistry` for default cvars, user-style overrides, serialization and key-command binding data.
* Added a headless cvar/config smoke test for default cvar loading, overrides, serialization and bind/unbind parsing.
* Added `docs/CVARS_AND_CONFIG.md` to document the cvar, config and bind layer.
* Added `AssetManager`, `GoldSrcLocalConfig`, `GoldSrcVFS` and structured asset diagnostics for raw local asset resolution.
* Added a headless Asset VFS smoke test that uses synthetic files under `user://`.
* Added `docs/LOCAL_GOLDSRC_CONFIG.md` to document the local config schema, search order and VFS path rules.
* Added `docs/DECISIONS.md` to record legal, architecture, reuse, fallback and changelog rules.
* Added a PR-01 bootstrap integrity and project-contract plan before asset, movement and weapon work.
* Added testing checklist coverage for bootstrap integrity, documentation consistency and changelog updates.

### Changed

* Reworked the roadmap around the GoldSrc reimplementation sequence: bootstrap, local config/VFS, cvars, movement, asset providers, viewmodel orchestration, BSP, game loop and gameplay systems.
* Updated the development plan so local asset resolution and cvar authority come before movement and weapon presentation.
* Clarified asset pipeline responsibilities: raw file resolution and diagnostics precede format parsing.
* Documented the initial local GoldSrc config and VFS implementation classes.
* Clarified architecture boundaries for semantic gameplay events, presentation orchestration and provider-driven assets.
* Restored `project.godot` to a valid Godot 4 configuration with an explicit main scene.

### Process

* Closed superseded pull request #3 without merge in favor of a smaller bootstrap/project-contract branch from `main`.

## [0.1.0] – Bootstrap

* Initial repository structure and Godot 4 project created.
* Added documentation: roadmap, development plan, legal originality, architecture, asset pipeline, knowledge base and testing strategy.
* Added `AGENTS.md` with strict guidelines for AI agents.
* Configured `.gitignore` and `.gitattributes` to exclude caches, imported assets and local configuration files.
* Implemented a simple `Main.tscn` scene that displays a bootstrap screen.
