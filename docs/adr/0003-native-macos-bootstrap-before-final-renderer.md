# ADR 0003: Native macOS bootstrap before final renderer abstraction

## Status

Accepted

## Context

The project needs early visual validation of map geometry on macOS. A final renderer backend decision will take more design work, but the mesh pipeline needs immediate feedback.

## Decision

Use small native macOS tools for early lifecycle and visualization milestones:

- Cocoa window bootstrap in the client.
- MetalKit debug viewer for untextured map wireframes.

These tools are intentionally narrow and are not the final renderer architecture.

## Consequences

Positive:

- Fast validation on Apple Silicon and modern macOS.
- No immediate dependency on a larger renderer stack.
- Confirms geometry extraction before texture and lighting work.

Negative:

- Some viewer code is macOS-only.
- A future renderer abstraction will need to replace or wrap this path.
- Debug viewer code must not become the permanent game renderer by accident.

## Alternatives considered

- SDL3 plus a renderer backend immediately: deferred until map parsing and mesh generation were validated.
- Software rasterizer: rejected as less useful for future GPU work.
- OpenGL: rejected for strategic macOS direction.
