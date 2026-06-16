# OpenStrike docs

## Current state

- PR-09A and PR-09B are merged through PR #28.
- PR #30 added PR-09C and PR-09D planning packets.
- Phase 4 / PR-10A is closed until PR-09C and PR-09D complete the real-map
  runtime collision and telemetry gate.

## Plan (single source of truth for "what to do next")

- `COMPACT_PR_TASK_PACKETS.md` - take the first unclosed packet. Do not pull
  neighboring packet scope forward.
- Current routing: finish `PR-09C.0` docs source-of-truth repair, then continue
  with `PR-09C` real-map clipnode trace (Contract B), then `PR-09D` walkable
  telemetry invariants.

## Decided matters

- `DECISIONS.md`

## How to implement

- `CODEX_SPEC_GOLDSRC_RUNTIME_SPINE.md` - collision, movement and trace
  contracts.
- `MOVEMENT.md`, `CS_1_6_FEEL.md` - movement behavior and feel-sensitive
  acceptance criteria.
- `GODOT_OPENSTRIKE_SKILL.md` - Godot/GDScript workflow for current Godot work.
- `DEV_LABS_METHODOLOGY.md` - evidence rules for subjective feel claims and
  user-assisted lab runs.

## Agent workflow

- `AGENTS.md` - process, legal and clean-room rules.
- `agent_context_hygiene.md` - Task Packet, Assumptions and handoff workflow.
- `current_context_contract.md` - live compact context. Read it after
  `AGENTS.md` and verify it against current git/GitHub state.

## Deferred and historical material

- `docs/future/` - Phase 4+ weapon, viewmodel, asset orchestration and coverage
  material. Read these only when the active packet requires that subsystem.
- `docs/archive/` - old plans and research. Historical reference only, not an
  active source of truth.
