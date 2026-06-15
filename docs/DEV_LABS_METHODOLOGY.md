# Dev Labs Methodology

OpenStrike needs dev labs for mechanics where players usually report vague
symptoms such as "floaty", "late", "muddy", "wrong hitreg" or "bad recoil".
A lab is not a full feature. It is a controlled way to expose engine state,
record telemetry and compare behavior before accepting a parity claim.

## Lab Contract

Every dev lab should define:

* controlled setup;
* one primary variable under test;
* repeatable command or input script;
* on-screen debug overlay for invisible state;
* CSV or JSON telemetry export;
* screenshot or video capture points when visual evidence matters;
* reference notes and source weight;
* acceptance criteria.

## Manual Test Reports

After every user-assisted run in a test scene, the agent must inspect the
available trace/log artifacts and write a short report under
`docs/test_reports/` before moving on. The report should include:

* test scene, map and command used;
* user-visible observations from the run;
* trace/log facts that confirm or contradict those observations;
* current conclusion about the feature under test;
* concrete next actions or deferred items.

Do not treat a manual run as complete just because the scene launched. The
report is the handoff artifact that lets reviewers and later agents understand
what was actually learned.

## Evidence Rules

* A feel claim must map to a lab, smoke test or telemetry artifact before it is
  accepted as done.
* Before/after comparisons are required for changes that tune movement,
  shooting, hitboxes, hit registration, prediction, HUD cost or viewmodel cost.
* Exact CS 1.6 constants must come from primary or validated parity references,
  not from CS:GO/CS2 videos.
* Community engineering references can define questions and experiments; they
  do not define final numeric truth by themselves.

## Initial Lab Backlog

Do not build all labs immediately. Add them when their owning subsystem reaches
implementation scope.

| Lab | Owning Milestone | Purpose |
|---|---|---|
| `movement_lab` | M2/M6 | Speed-over-time, friction, fastrun, air-strafe, bhop FOG, duck and step telemetry. |
| `shooting_accuracy_lab` | M6/M7 | First-shot, stance, movement, burst and recovery comparisons. |
| `wall_spray_lab` | M6/M7 | Visible decal patterns and seeded spread/recoil comparison. |
| `hitbox_lab` | M6+ | Render model, server hitbox, predicted hitbox and animation mismatch debug. |
| `hitreg_lab` | M6+ | Bullet trace, accepted/rejected hit explanation and deterministic replay. |
| `input_latency_lab` | M6+ | Input event to usercmd, prediction, server tick, feedback and render timing. |
| `bsp_walkable_lab` | M5 | Real BSP map loading, spawn selection, imported collision contacts, speed and floor/wall telemetry before greybox or gunplay tuning. |
| `map_entities_lab` | M5 | Entity-lump counts, spawn/buyzone/objective metadata and debug volumes. |
| `bsp_visibility_lab` | M5+ | Active leaf, visible leaves, PVS and surface count diagnostics. |
| `hud_cost_lab` | M8 | HUD draw cost, nodes, asset lookup and frame-time impact. |
| `viewmodel_cost_lab` | M4/M8 | Viewmodel render cost and presentation-layer overhead. |
| `animation_readability_lab` | M6+ | Gameplay state vs animation pose and action timing visibility. |

## Current Gates

Movement PRs must include tick telemetry for changed behavior and should add or
extend smoke coverage before a visual tuning discussion starts.

Weapon/recoil/spread PRs must define how the change will later be verified in
`shooting_accuracy_lab` or `wall_spray_lab`, even if the lab is not implemented
in that PR.

Hitbox, hit registration and prediction PRs must include a debug overlay plan
before gameplay behavior is considered reviewable.

HUD/viewmodel PRs must avoid per-frame asset loading and should expose profiler
counters once presentation complexity grows beyond static bootstrap UI.
