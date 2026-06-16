# OpenStrike Communication Protocol

Status: normative for issue/PR communication between the project owner, analyst, tech lead, PM and implementation agents.

This document defines the shared communication protocol for OpenStrike planning. When a human says **"отвечай по регламенту"** / **"answer by the protocol"**, the agent must follow this file.

This protocol does not replace `AGENTS.md`, `docs/DECISIONS.md`, legal rules, clean-room rules or task-packet scope rules. It defines how people and agents communicate in GitHub Issues and Pull Requests so decisions are traceable and do not rot across chats.

---

## 1. Working model

OpenStrike uses GitHub Issues as the shared planning space.

```text
GitHub Issue = discussion, role inputs, questions, PM synthesis and decision
Pull Request = implementation and code review
Project docs = accepted long-lived contracts and source of truth
```

Do not rely on Telegram, private chat history or a ChatGPT conversation as source of truth. If a decision matters, it must be captured in a GitHub Issue comment, PR description/comment, `docs/DECISIONS.md`, or the relevant task packet.

---

## 2. Roles

### Project owner

The project owner defines goals, constraints and priorities. The owner may request analysis, ask for planning or approve a direction.

### Analyst

The analyst reviews architecture, contradictions, known CS 1.6 behavior, clean-room boundaries and whether current implementation preserves the intended internal structure.

The analyst should not directly assign Codex implementation work unless the project owner explicitly asks.

### Tech lead

The tech lead turns accepted goals and analyst findings into implementable technical direction. The tech lead may ask questions, challenge the analyst, narrow scope, split tasks and propose implementation strategy.

### PM / product-project manager

The PM plans the next step only after reading the issue, analyst input and tech-lead input. The PM resolves sequencing, demo value, acceptance criteria and what must not be done in the next PR.

The PM must not make final implementation decisions from only one role's input unless the owner explicitly overrides the protocol.

### Codex / implementation agent

Codex implements the approved issue/PR scope. Codex must follow `AGENTS.md`, the task packet, acceptance criteria and all out-of-scope boundaries.

---

## 3. Source-of-truth order

When sources disagree, use this order:

```text
1. Current GitHub Issue / PR comments with explicit [DECISION]
2. docs/DECISIONS.md
3. docs/COMPACT_PR_TASK_PACKETS.md
4. AGENTS.md and active docs/README.md routing
5. Current code on main and merged PR state
6. Archived docs and chat history, only as context
```

Archived docs are historical unless an active document explicitly re-promotes them.

---

## 4. Standard issue flow

For a planning issue:

```text
1. Owner opens an issue or points to an existing issue.
2. Analyst posts [ANALYST INPUT].
3. Tech lead posts [TECHLEAD INPUT], [TECHLEAD QUESTIONS] or [IMPLEMENTATION PROPOSAL].
4. PM posts [PM SYNTHESIS].
5. PM or owner posts [DECISION].
6. Approved implementation is split into task issues or PRs.
7. Codex implements only the approved task/PR scope.
```

If the tech lead asks questions, the issue remains blocked until the questions are answered or the owner explicitly narrows the decision.

---

## 5. Comment headings

GitHub labels apply to issues and PRs, not individual comments. To route comments, use exact headings.

Allowed headings:

```text
[OWNER CONTEXT]
[ANALYST INPUT]
[TECHLEAD INPUT]
[TECHLEAD QUESTIONS]
[IMPLEMENTATION PROPOSAL]
[PM SYNTHESIS]
[DECISION]
[ACCEPTANCE]
[OUT OF SCOPE]
[BLOCKER]
[TEST REPORT]
```

A comment may contain several headings if needed, but every substantive role input should start with one of these headings.

---

## 6. Required response format by role

### Analyst response

Use this format:

```markdown
[ANALYST INPUT]

## Verdict

## Facts checked

## What is safe to proceed with

## Blockers / risks

## Contradictions

## Recommended next questions for tech lead

## Not a decision

This is analyst input, not a final PM decision.
```

The analyst must separate facts from recommendations and must say when Godot was not run locally.

### Tech-lead response

Use this format:

```markdown
[TECHLEAD INPUT]

## Verdict on analyst input

## Implementation concerns

## Proposed implementation path

## Scope split

## Questions / missing information

## Acceptance changes

## Out of scope for the next PR
```

The tech lead should make implementation scope smaller, not larger, unless the owner explicitly asks for a bigger packet.

### PM response

Use this format:

```markdown
[PM SYNTHESIS]

## Inputs read

- Analyst: yes/no, link or comment summary
- Tech lead: yes/no, link or comment summary
- Repo/PR facts checked: yes/no

## Agreement

## Conflict

## Product/project decision

## Next issue / PR

## Demo value

## Acceptance criteria

## Out of scope

## Label/status changes
```

PM decision rule:

```text
No final PM decision without analyst input and tech-lead input, unless the project owner explicitly says to decide without one of them.
```

### Codex response

Use this format before implementation:

```markdown
[TASK PACKET]

## Goal

## Includes

## Excludes

## Files likely touched

## Acceptance

## Tests / checks

## Legal / asset check

## Assumptions
```

Codex must not start neighboring packets early.

---

## 7. Labels

Use the following label groups.

### Role labels

```text
role: analyst-input-needed
role: techlead-input-needed
role: pm-decision-needed
```

### Status labels

```text
status: triage
status: ready
status: blocked
status: in-progress
status: in-review
status: accepted
status: deferred
```

Only one `status:*` label should normally be active on a task issue. Planning umbrella issues may keep `status: blocked` while waiting for role input.

### Phase labels

```text
phase: runtime-spine
phase: bsp
phase: movement
phase: gameplay-loop
phase: docs
```

Multiple `phase:*` labels are allowed when an issue crosses subsystem boundaries.

### Type labels

```text
type: decision
type: task
type: risk
type: demo
```

Use only one `type:*` label unless there is a strong reason.

---

## 8. Issue types

### Decision issue

Use when the team must choose direction.

Required sections:

```markdown
# Context
# Analyst input
# Teamlead input
# PM synthesis
# Decision
# Acceptance criteria
# Out of scope
```

### Task issue

Use for a specific PR-sized implementation task.

Required sections:

```markdown
# Goal
# Current status
# Analyst input
# Teamlead input
# PM synthesis
# Scope
# Acceptance
# Out of scope
```

### Risk issue

Use for a blocker or risk that can invalidate future work.

Required sections:

```markdown
# Risk
# Source
# Why it matters
# Mitigation candidates
# Exit criteria
```

### Demo issue

Use for a customer-visible or owner-visible checkpoint.

Required sections:

```markdown
# Demo goal
# Depends on
# Demo acceptance
# Out of scope
```

---

## 9. Status transitions

Typical transitions:

```text
triage -> blocked -> ready -> in-progress -> in-review -> accepted
triage -> deferred
blocked -> deferred
accepted -> closed
```

Meaning:

- `status: triage`: issue exists but role inputs or scope are not organized.
- `status: blocked`: cannot proceed; missing role input, decision, dependency or evidence.
- `status: ready`: PM decision exists and Codex/tech lead can start the next action.
- `status: in-progress`: implementation or active analysis is underway.
- `status: in-review`: PR or decision is waiting for review.
- `status: accepted`: decision or task is accepted.
- `status: deferred`: intentionally postponed; do not start without a new decision.

---

## 10. Decision rules

A decision comment must include:

```text
[DECISION]
Decision: accepted / rejected / deferred / split / needs more input
Next action:
Owner:
Acceptance:
Out of scope:
Links:
```

A decision is not valid if it only says "sounds good" or "do it". It must name the next issue/PR and scope boundaries.

---

## 11. Demo rules

Every demo issue must answer:

```text
What can the owner see?
What proves it is not fake?
What telemetry/test/report backs it?
What is explicitly not claimed yet?
```

For OpenStrike, demos must not overclaim CS 1.6 parity. Use wording like:

```text
This demo proves the current runtime slice, not full CS 1.6 parity.
```

---

## 12. What agents must do when told "отвечай по регламенту"

When the owner says **"отвечай по регламенту"**, the agent must:

1. Identify its role: analyst, tech lead, PM or Codex.
2. Read the current issue/PR content and comments if a link or issue number is provided.
3. Use the required heading for its role.
4. Separate facts, assumptions and recommendations.
5. Avoid final decisions unless its role is PM and the required inputs are present.
6. State missing input explicitly instead of pretending it has enough context.
7. Preserve scope boundaries and out-of-scope items.
8. End with the next required action.

Minimal prompt for agents:

```text
Прочитай docs/COMMUNICATION_PROTOCOL.md и отвечай по регламенту.
Роль: <аналитик | тимлид | PM | Codex>.
Issue/PR: <link or number>.
```

---

## 13. Examples

### Analyst example

```markdown
[ANALYST INPUT]

## Verdict

Do not start Phase 4 yet.

## Facts checked

- PR-09B merged.
- Runtime snapshots exist.
- Real-map wall contact is not proven.

## Blockers / risks

Real BSP movement may still be free-volume.

## Not a decision

This is analyst input, not a final PM decision.
```

### Tech-lead example

```markdown
[TECHLEAD INPUT]

## Verdict on analyst input

Agree with the blocker, but split docs repair from collision work.

## Proposed implementation path

1. Docs source-of-truth repair.
2. Real-map trace diagnostic.
3. Runtime backend switch only after diagnostic passes.

## Out of scope for the next PR

No weapons, HUD, economy or moving brushes.
```

### PM example

```markdown
[PM SYNTHESIS]

## Inputs read

- Analyst: yes
- Tech lead: yes
- Repo/PR facts checked: yes

## Product/project decision

Start PR-09C.0 first. PR-10A remains deferred.

## Next issue / PR

#32

## Acceptance criteria

- Active doc paths exist.
- Current context is not stale.
- Checks pass.
```

---

## 14. Maintenance

Update this document when:

- the role workflow changes;
- new labels are introduced;
- GitHub Project fields become normative;
- PM decision rules change;
- issue templates are formalized.

Changes to this file should be small and should not redefine architecture or legal policy. Architecture goes to `docs/ARCHITECTURE.md` / `docs/DECISIONS.md`; legal policy goes to `AGENTS.md` and legal docs.
