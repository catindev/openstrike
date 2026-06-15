# Tainted Labs Policy

OpenStrike uses fast experiments to learn how Counter-Strike 1.6 behaves, but
experimental shortcuts must not silently become production architecture. This
policy defines where dirty research is allowed, how it is tracked and what must
be cleaned before public release.

## Definitions

**Clean production code** is original OpenStrike code, or dependency code whose
license and redistribution status have been reviewed. Clean code may live under
`src/core`, `src/game` and `src/presentation`.

**Dirty or tainted lab code** is code, scripts or notes derived from copied
internet snippets, GPL/proprietary/no-license source, HLSDK/Xash3D experiments
or other unreviewed implementation material. Dirty code is allowed only for
private research or clearly isolated dev labs.

**Optional dependency** is third-party code that is committed or expected by a
dev workflow but is not game asset data. Optional dependencies need a ledger
entry when their license, provenance or release status affects redistribution.

**Accepted pre-release risk** means the maintainer has accepted temporary local
development use despite unresolved release concerns. It does not mean the code
is safe to redistribute publicly.

**Public open-source gate** is the required review before public release,
package distribution or wider licensing claims. The gate checks assets,
licenses, taint scope and release scripts.

## Rules

1. Valve, Half-Life and Counter-Strike asset bytes are never allowed in this
   repository or release artifacts.
2. Copied code is tainted unless its license and provenance are reviewed and
   explicitly accepted.
3. Tainted code may live only under `src/dev/labs`, `src/dev/tainted` or
   private local branches.
4. `src/core`, `src/game` and `src/presentation` must not import
   `src/dev/tainted`.
5. Xash3D, HLSDK and similar projects may be used as architecture or behavior
   references, not as production implementation templates.
6. Every tainted experiment must produce clean findings: documentation, tests,
   telemetry reports, contracts or explicit rewrite notes.
7. Every tainted item must have a clean replacement, release exclusion or
   reviewed-license plan in `docs/TAINT_LEDGER.md`.

## Lab Boundary

Dirty labs are allowed to move quickly. They may inspect local licensed assets,
compare behavior against reference projects and produce telemetry. They must not
be imported by the production runtime.

When a lab proves useful, the promotion path is:

```text
dirty experiment
  -> documented findings / behavior / contracts
  -> clean OpenStrike-owned implementation
  -> production import
```

## Current PR-07 Policy

The PR-07 BSP walkable scene remains a dev lab. It may use
`goldsrc-godot` and `godot_scene_collision` to make real maps testable, but it
does not define final GoldSrc hull trace parity. Gameplay features such as
weapons, HUD, economy, buy flow and round logic must be implemented through
clean game/runtime layers, not directly inside the BSP lab runner.
