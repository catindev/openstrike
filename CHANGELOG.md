# Changelog

All notable OpenStrike changes should be documented here.

## Unreleased

### Added

- Added a trace-backed fixed-tick player movement prototype with gravity, walking, and jumping state updates.
- Added BSP collision plane/clipnode/model metadata loading and a minimal point trace CLI, `OpenStrikeBspTrace`.
- Added BSP light data inspection with per-face light offsets, styles, estimated lightmap dimensions, sample counts, and range validation in `OpenStrikeBspDump`.
- Added a textured BSP debug viewer pass with memory-only indexed texture decode, read-only WAD lookup, generated missing-texture placeholders, and a transient Metal texture atlas.
- Added read-only legacy texture package metadata parsing and the `OpenStrikeTexturePkgDump` CLI.
- Added debug BSP viewer navigation controls for rotation, zoom, and view reset.

### Documentation

- Added the long-form first vision document to the project documentation index.
- Documented fixed-tick player movement prototype status and remaining #16 sandbox limitations.
- Documented BSP collision trace prototype usage, status, architecture, and roadmap progress for #15.
- Documented BSP light data inspection status, dump output, architecture, and roadmap progress for #14.
- Documented textured map viewer usage, status, architecture, and roadmap progress for #13.
- Documented texture package metadata inspection status, tool usage, and roadmap progress for #12.
- Documented debug BSP viewer controls and updated project status/roadmap after #11.
- Added repository handoff documentation for agents and contributors.
- Added ADR structure and current project status documents.
- Added issue-backed roadmap documentation.

### Testing

- Added synthetic coverage for trace-backed fixed-tick player movement, gravity landing, jumping, and missing trace context warnings.
- Added synthetic coverage for BSP collision tables, clear traces, hit traces, start-solid traces, and malformed collision data.
- Added synthetic coverage for BSP light metadata, missing lighting, and truncated light data handling.
- Added synthetic coverage for indexed texture decode into RGBA buffers.
- Added synthetic coverage for texture package header, directory, mip metadata, and malformed-file rejection.
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
