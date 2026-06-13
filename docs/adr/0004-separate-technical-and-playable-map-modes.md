# ADR 0004: Separate technical map-window and playable sandbox modes

## Status

Accepted

## Context

OpenStrike now has two different needs that both start from a local user-provided map path:

- a technical map-window path used to validate BSP mesh and texture rendering;
- a playable sandbox path that will own input, fixed-tick commands, runtime state, and later movement/collision/gameplay integration.

The existing `--sandbox-map` app path intentionally reuses the BSP debug viewer runner. It is useful for technical map inspection, but treating it as the playable runtime would couple early gameplay work to debug viewer assumptions.

## Decision

Keep `OpenStrike --sandbox-map` as the technical app-level map-window integration that uses the current BSP debug viewer runner.

Introduce `OpenStrike --playable-map` as the separate playable sandbox runtime shell. This path owns input sampling, deterministic fixed-tick player commands, app-owned runtime loop state, and debug input output. In the first slice it opens a placeholder window and does not yet promise collision-backed movement or a production renderer.

## Consequences

Positive:

- The standalone `OpenStrikeBspView` and app `--sandbox-map` debug viewer path remain stable.
- Playable runtime work can evolve without making debug renderer code the permanent game renderer.
- Input and command mapping are testable without user assets or proprietary fixtures.

Negative:

- There are temporarily two map launch modes to document.
- Later renderer work must decide whether the playable path wraps, replaces, or bypasses the debug viewer runner.

## Alternatives considered

- Reusing `--sandbox-map` for playable runtime: rejected because the name and existing behavior already mean technical map-window integration.
- Adding input directly to the BSP debug viewer runner: rejected because it would mix debug inspection with gameplay runtime ownership.
- Waiting for a full renderer abstraction before any playable shell: rejected because input and fixed-tick command plumbing can be validated independently now.
