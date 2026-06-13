# ADR 0005: Reuse debug BSP viewer for local sandbox mode

## Status

Accepted

## Context

OpenStrike needs a first integrated local sandbox mode that launches a user-provided map from the main app. The project already has a native macOS Metal BSP debug viewer that validates map mesh extraction and texture lookup.

A final renderer abstraction is still out of scope for this milestone. Rebuilding the renderer path inside the app would duplicate behavior, while promoting the debug viewer to a permanent renderer would be premature.

## Decision

Reuse the current BSP debug viewer renderer path through a small shared runner:

- `OpenStrikeBspView` remains a standalone inspection tool.
- `OpenStrike --sandbox-map <path>` calls the same runner from the bootstrap client on macOS.
- Sandbox mode uses configured read-only resource roots plus any temporary `--resource-root` paths for texture lookup.
- The shared runner remains a debug/sandbox path, not the final engine renderer.

## Consequences

Positive:

- The first app-level sandbox mode uses the renderer path that is already validated by the debug viewer.
- Standalone viewer behavior stays available for focused map inspection.
- The app avoids proprietary UI, names, or gameplay content.
- Resource handling remains local and read-only.

Negative:

- The app target now temporarily links the debug Metal viewer runner on macOS.
- Sandbox mode is macOS-only until a renderer abstraction exists.
- Future renderer work must replace or wrap this runner instead of extending it into the final architecture by accident.

## Alternatives considered

- Build a new app renderer path now: rejected because it would duplicate the existing debug viewer before renderer architecture is settled.
- Spawn the standalone viewer process from the app: rejected because it would be fragile in build/install layouts and would not be an integrated app mode.
- Wait for final renderer abstraction: rejected because #20 explicitly asks for a local sandbox app milestone now.
