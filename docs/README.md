# OpenStrike documentation

This directory is the operational memory of the project. Every AI/coding agent must read the relevant documents before changing code.

## Reading order

1. `../AGENTS.md` — mandatory agent rules.
2. `agent_context_hygiene.md` — task-packet, assumptions and handoff workflow
   for preventing context rot.
3. `current_context_contract.md` — compact current operational context for new
   agents. Update it when accepted project state changes.
4. `LEGAL_ORIGINALITY.md` — legal and originality boundaries.
5. `TAINTED_LABS_POLICY.md`, `TAINT_LEDGER.md` and
   `PUBLIC_OPEN_SOURCE_EXIT_PLAN.md` — dirty lab boundaries, accepted
   pre-release risks and release gates.
6. `DECISIONS.md` — binding implementation decisions and project boundaries.
7. `ARCHITECTURE.md` — target Godot architecture and layer boundaries.
8. `AGENT_SKILLS/GODOT_OPENSTRIKE_SKILL.md` — required before changing
   Godot code, GDScript, scenes, resources, presentation, asset-provider code
   or Godot smoke/CI checks.
9. `ROADMAP.md` — milestone path for the GoldSrc reimplementation.
10. `DEVELOPMENT_PLAN.md` — planned PR sequence and acceptance criteria.
11. `ASSET_PIPELINE.md` — planned local asset loading model.
12. `THIRD_PARTY_DEPENDENCIES.md` — committed third-party dependency inventory.
13. `LOCAL_GOLDSRC_CONFIG.md` — local asset configuration and VFS path rules.
14. `CVARS_AND_CONFIG.md` — cvar registry, config and bind rules.
15. `MOVEMENT.md` — cvar-backed movement simulation scope and telemetry.
16. `CS_1_6_FEEL.md` — research baseline for movement, weapons, prediction,
    presentation and map feel.
17. `VIEWMODEL_WORLD_PROFILE.md` — world/viewmodel scale, coordinate mapping,
    eye height and FOV contract for PR-06 profile preflight.
18. `VIEWMODEL_MANUAL_PREFLIGHT.md` — local real-asset viewmodel preflight
    instructions before gameplay/gunplay work.
19. `CS16_ASSET_ORCHESTRATION_ATLAS.md` — weapon, model, animation, audio,
    effect and lifecycle asset map for CS 1.6-style orchestration.
20. `COVERAGE_STATUS_CONTRACT.md` — status vocabulary for scanner, generated
    atlas and coverage report fields.
21. `3KLIKSPHILIP_RESEARCH_NOTES.md` — community-engineering research notes
    about experiment design, labs, latency, hitboxes, mapping and performance.
22. `SOURCE_CATALOG.md` — external source weighting and use/do-not-use rules.
23. `DEV_LABS_METHODOLOGY.md` — lab contract for turning feel claims into
    telemetry, debug overlays and acceptance criteria.
24. `test_reports/` — persistent reports from user-assisted dev-lab runs.
25. `GDSCRIPT_AGENT_NOTES.md` — GDScript/Godot parser, runtime and tooling
    pitfalls discovered during implementation.
26. `KNOWLEDGE_BASE.md` — current project knowledge base.
27. `TESTING.md` — testing strategy and smoke checks.

## Documentation rule

When code changes behavior, documentation must change in the same PR.

When a parity fact is uncertain, write `TODO: verify` instead of guessing.

Every implementation PR must update `../CHANGELOG.md` in English.

Before every non-trivial project task, follow `agent_context_hygiene.md`: form
a compact Task Packet, state explicit Assumptions and prefer current repository
contracts over stale chat history. When accepted decisions, architecture state
or immediate next tasks change, update `current_context_contract.md`.

When a GDScript or Godot-specific issue slows implementation down, append the
pitfall and fix to `GDSCRIPT_AGENT_NOTES.md` in the same PR.

Before changing Godot code, scenes, resources, presentation, asset-provider code
or Godot smoke/CI checks, read `AGENT_SKILLS/GODOT_OPENSTRIKE_SKILL.md`.

Before adding, updating or using committed third-party code or binary
dependencies, read `THIRD_PARTY_DEPENDENCIES.md` and update it in the same PR.

Before adding dirty labs, unreviewed dependency code or external comparison
experiments, read `TAINTED_LABS_POLICY.md`, `TAINT_LEDGER.md` and
`PUBLIC_OPEN_SOURCE_EXIT_PLAN.md`. Do not import tainted dev code from
production paths.

Before changing movement, weapon feel, prediction, BSP collision, viewmodels,
HUD or feedback timing, read `CS_1_6_FEEL.md` and update it or the linked
feature docs when new facts are accepted.

Before changing world/viewmodel scale, coordinate mapping, camera FOV, eye
height or first-person model placement, read `VIEWMODEL_WORLD_PROFILE.md` and
update it when profile facts or smoke obligations change.

Before asking a human to visually test real CS 1.6 viewmodels, read
`VIEWMODEL_MANUAL_PREFLIGHT.md` and use its local commands. Do not replace that
path with per-weapon transform tuning.

Before changing weapon assets, viewmodel orchestration, weapon animation
aliases, weapon audio, muzzle flashes, shell ejection, impact effects, grenade
presentation or HUD weapon sprites, read `CS16_ASSET_ORCHESTRATION_ATLAS.md`
and update it when new verified asset facts or gaps are discovered.

Before changing asset scanner output, generated asset atlas files, coverage
reports or coverage status fields, read `COVERAGE_STATUS_CONTRACT.md`. Status
vocabulary changes are made by editing only `../gen/coverage_status_matrix.json`
and then regenerating schema/document artifacts with `../gen/generate.py`.

Before accepting a subjective feel claim, read `DEV_LABS_METHODOLOGY.md` and
connect the claim to telemetry, a smoke test, a debug overlay or a planned lab.
After a user-assisted test scene run, inspect the trace/log artifacts and write
the report under `test_reports/` before moving to implementation follow-ups.

Before changing BSP map loading, spawn selection or map collision, read
decision 0017 in `DECISIONS.md` and the PR-07 checklist in `TESTING.md`; keep
`godot_scene_collision` separate from GoldSrc clipnode/hull trace parity.

## Current status

`0.1.0` began as a bootstrap milestone. The repository now also contains the
first local GoldSrc config/VFS layer, cvar/config layer, movement simulation
core, asset provider contracts, vendored `goldsrc-godot` adapters and an
opt-in real BSP walkable lab. It still does not implement real gameplay
weapons, HUD, networking, final GoldSrc hull-trace collision or complete
decoded GoldSrc model/sprite/audio presentation.
