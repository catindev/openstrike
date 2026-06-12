# Roadmap

This roadmap is backed by GitHub issues. Open issue means not done. Closed issue means completed or explicitly not planned.

## Completed

| Issue | Result | PRs |
|---|---|---|
| #1 | First macOS window lifecycle and debug viewer path. | #4, #9 |
| #2 | Map header/lump inspection and mesh path. | #6, #7, #8, #9 |
| #10 | Documentation, ADRs, changelog, and agent handoff. | #21 |
| #3 | Config and VFS test hardening. | #22 |
| #11 | Debug viewer navigation controls. | #25 |
| #12 | Texture package metadata reader and dump tool. | Current PR |

## Active near-term work

| Priority | Issue | Task | Notes |
|---|---|---|---|
| P1 | #13 | Add textured map viewer pass. | Requires texture package metadata and decode path. |
| P2 | #14 | Add map light data inspection. | Required before lightmapped world rendering. |
| P2 | #15 | Add map collision trace prototype. | Required before movement and sandbox. |
| P2 | #16 | Add player movement sandbox prototype. | Requires collision trace prototype. |
| P3 | #17 | Add model metadata inspection tool. | Foundation for model rendering. |
| P3 | #18 | Add sprite metadata inspection tool. | Foundation for sprite rendering. |
| P3 | #19 | Add WAV playback prototype. | Foundation for audio system. |
| P4 | #20 | Create local sandbox app mode. | Integration milestone after viewer, collision, and basic movement. |

## Development principles

1. Keep every task read-only with respect to user resource roots.
2. Do not commit proprietary assets or generated data derived from them.
3. Prefer inspection tools before integrated runtime features.
4. Validate binary formats on local user files, but only commit synthetic fixtures.
5. Close issues only after the PR that implements them is merged.
6. Update this roadmap when priorities change.

## Suggested next sequence

1. Implement #13 textured map viewer pass.
2. Implement #14 map light data inspection.
3. Implement #15 map collision trace prototype.
4. Implement #16 player movement sandbox prototype.
5. Implement #17 model metadata inspection tool.

## Later roadmap

Later tasks should be opened as issues when their prerequisites are done:

- visibility set parsing and viewer toggle;
- renderer abstraction beyond the debug viewer;
- light atlas construction;
- collision hull debug overlay;
- movement tuning profiles;
- local match loop;
- bot navigation prototype;
- original UI shell;
- packaging, signing, and notarization.
