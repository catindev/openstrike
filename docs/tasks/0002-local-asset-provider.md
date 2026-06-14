# Task 0002 — Local resource provider

Goal: implement the boundary that discovers resources from a user-selected local installation without copying them into the repository.

Deliverables:

- `AssetManager` contract.
- Local provider skeleton.
- Example config with fake paths.
- Ignored real local config.
- Resource index diagnostics.

Acceptance:

- Missing path reports a clear error.
- Valid path produces a local index.
- No real local paths or resource bytes are committed.
