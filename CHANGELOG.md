# Changelog

All notable OpenStrike changes should be documented here.

## Unreleased

### Documentation

- Added repository handoff documentation for agents and contributors.
- Added ADR structure and current project status documents.
- Added issue-backed roadmap documentation.

### Testing

- Added CTest-based regression coverage for config parsing, config template generation, VFS mount validation, resource indexing, physical-file deduplication, and virtual-path shadowing.
- CI now runs the test suite after building.

### Fixed

- Fixed config array parsing so `roots` cannot accidentally match `open_asset_roots` by substring.

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
