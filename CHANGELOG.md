# Changelog

All notable changes to this project will be documented in this file.  The format is inspired by [Keep a Changelog](https://keepachangelog.com/) and adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

* Added `docs/DECISIONS.md` to record legal, architecture, reuse, fallback and changelog rules.
* Added a PR-01 bootstrap integrity and project-contract plan before asset, movement and weapon work.
* Added testing checklist coverage for bootstrap integrity, documentation consistency and changelog updates.

### Changed

* Reworked the roadmap around the GoldSrc reimplementation sequence: bootstrap, local config/VFS, cvars, movement, asset providers, viewmodel orchestration, BSP, game loop and gameplay systems.
* Updated the development plan so local asset resolution and cvar authority come before movement and weapon presentation.
* Clarified asset pipeline responsibilities: raw file resolution and diagnostics precede format parsing.
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
