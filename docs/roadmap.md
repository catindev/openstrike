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
| #12 | Texture package metadata reader and dump tool. | #33 |
| #13 | Textured map viewer pass with in-memory texture decode and generated placeholders. | #34 |
| #14 | Map light data inspection with per-face lightmap metadata. | #35 |
| #15 | Point collision trace prototype over BSP clipnodes. | #36 |
| #16 | Player movement sandbox prototype with fixed-tick state, walk, jump, gravity, crouch hull selection, and synthetic debug output. | #40 |
| #17 | Model metadata inspection tool with safe header/table parsing and read-only CLI output. | #41 |
| #18 | Sprite metadata inspection tool with safe header, palette, and frame parsing. | #42 |
| #19 | WAV playback prototype with PCM metadata validation and macOS AVFoundation CLI playback. | #43 |
| #20 | Technical app map-window integration using the current BSP viewer runner. | #44 |
| #45 | Playable sandbox runtime shell and input command pipeline. | PR #54 |
| #46 | First-person BSP render mode for playable sandbox. | this PR |

## Active near-term work

| Priority | Issue | Task | Notes |
|---|---|---|---|
| P4 | #47 | Collision-backed player movement for playable sandbox. | Build on `--playable-map` first-person render mode; reuse `PlayerMovement` and `BspCollisionData` to allow walking, jumping, crouching, and collision detection. |

## Development principles

1. Keep every task read-only with respect to user resource roots.
2. Do not commit proprietary assets or generated data derived from them.
3. Prefer inspection tools before integrated runtime features.
4. Validate binary formats on local user files, but only commit synthetic fixtures.
5. Close issues only after the PR that implements them is merged.
6. Update this roadmap when priorities change.

## Suggested next sequence

1. Build on #46 with the next numbered playable issue (#47) to add collision-backed player movement using existing `PlayerMovement` and `BspCollisionData`.
2. Add a debug HUD/telemetry and placeholder weapon/hitscan prototypes.
3. Implement audio events and WAV mixing once the renderer/runtime plumbing is stable.

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
