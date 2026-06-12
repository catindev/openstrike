# Changelog

All notable OpenStrike changes should be documented here.

## Unreleased

### Testing

- Added CTest-backed config and VFS regression tests using only synthetic temporary files.

### Fixed

- Hardened config array parsing so `[resources].roots` cannot accidentally match `[resources].open_asset_roots`.

### Documentation

- Added repository handoff documentation for agents and contributors.
- Added ADR structure and current project status documents.
- Added issue-backed roadmap documentation.

## 2026-06-12

### Added

- Bootstrapped the repository with clean-room README, contribution rules, CMake presets, and audit tooling.
- Added config-driven local resource roots.
- Added read-only VFS mounting and resource indexing.
- Added duplicate physical file handling across overlapping mount roots.
- Added native macOS window lifecycle and CLI-only mode.
- Added map header and lump summary parser.
- Added map dump command-line tool.
- Added map geometry summary extraction.
- Added triangulated map world mesh generation.
- Added macOS native Metal debug viewer for untextured wireframe rendering.

### Validated manually

- macOS arm64 CMake configure and build.
- Config validation against local read-only resource roots.
- Summary parsing, mesh generation, and wireframe display on local files.

### Safety

- No proprietary assets were added to the repository.
- Tools operate on local user-provided files and do not copy, extract, write, or redistribute those files.
