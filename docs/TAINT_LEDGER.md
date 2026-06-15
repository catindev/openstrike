# Taint Ledger

This ledger tracks unreviewed, dirty or pre-release-risk code paths that matter
for OpenStrike's public release path. It does not track proprietary local game
assets because those must never be committed at all.

## T-0001: `alanfischer/goldsrc-godot`

Status:

* Accepted pre-release risk.

Path:

* `addons/goldsrc/`

License status:

* The vendored snapshot inspected on 2026-06-15 has no `LICENSE`, `COPYING` or
  `NOTICE` file.
* Absence of a license does not grant reuse or redistribution rights.
* The OpenStrike MIT license does not cover this vendored dependency.

Used for:

* BSP, WAD, MDL and SPR development bridges.
* PR-06 viewmodel preflight.
* PR-07 walkable BSP lab scene loading.

Release impact:

* Public release/package distribution is blocked until this dependency is
  license-reviewed, replaced, excluded from release artifacts or explicitly
  approved under a documented maintainer decision.

Clean exit:

* Prefer an OpenStrike-owned reader/import path for required runtime behavior,
  or re-evaluate if upstream adds a usable license file.

## T-0002: Future Xash3D / HLSDK Dirty Research

Status:

* Not present in the repository as production code.

Rule:

* Xash3D and HLSDK may be used as behavior and architecture references.
* Any dirty comparison scripts must remain private or under `src/dev/tainted`
  and must not be imported by `src/core`, `src/game` or `src/presentation`.

Clean exit:

* Promote only neutral specs, tests, telemetry findings and original
  OpenStrike-owned implementations.
