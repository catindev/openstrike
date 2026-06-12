# ADR 0001: Clean-room project and local user resources

## Status

Accepted

## Context

OpenStrike needs compatibility with legacy resource formats while remaining legally and ethically clean. The repository must not include proprietary content or code.

## Decision

OpenStrike is a clean-room project. The repository and releases must not include proprietary assets, proprietary source code, leaked code, decompiled code, protected branding, original UI, or copied gameplay data tables.

The engine may read compatible local files only when the user has configured local resource roots. These directories are mounted read-only. OpenStrike tools must not copy, extract, convert, write, or redistribute user-provided assets.

## Consequences

Positive:

- The project can remain open-source and independently distributable.
- Contributors have clear boundaries.
- Tools can support compatibility without bundling protected material.

Negative:

- Tests need synthetic fixtures or local manual validation.
- Some compatibility work is slower because no proprietary samples can be committed.
- Documentation must be careful and neutral.

## Alternatives considered

- Bundling sample commercial resources: rejected.
- Auto-detecting local installations: rejected for now because config-first is more explicit and less ambiguous.
- Loading proprietary game logic binaries: rejected.
