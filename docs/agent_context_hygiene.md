# Agent Context Hygiene

This document defines the required workflow for preventing context rot in long
OpenStrike agent sessions. It applies to every non-trivial project task.

The goal is to normalize the current task into a compact, execution-ready
context before acting. Agents must not rely on full chat history blindly.

Agents must distinguish:

* current decisions from old rejected ideas;
* normative project contracts from drafts and discussions;
* active task requirements from background noise;
* known facts from assumptions.

## Mandatory Workflow

For every new non-trivial user task, first create a compact **Task Packet**.

The packet may stay internal for very small tasks. For project work,
architecture work, code work, research, specs or reviews, show it briefly
before execution.

## Task Packet

Use this structure:

```md
## Task Packet

### Current decision / current state
- What is currently accepted as true for this project/task.
- Mention only active decisions, not full history.

### User task
- What the user is asking to do now.

### Relevant constraints
- Technical constraints.
- Product constraints.
- Legal/licensing constraints.
- Repository/process constraints.
- Explicit user preferences.

### Out of scope
- What must not be solved, changed, or assumed in this task.

### Definition of done
- What output will count as a completed answer or completed implementation.

### Sources of truth
- Which files, docs, repository state, user messages, or external sources
  should be trusted most.

### Unknowns / risks
- What is not yet known.
- What may require verification.
```

The Task Packet must be short. It is not a summary of the whole conversation.
It is a working contract for the current task.

## Assumptions

After the Task Packet, explicitly list assumptions:

```md
## Assumptions

- Assumption 1.
- Assumption 2.
- Assumption 3.
```

Rules:

* Assumptions must be concrete and testable.
* Do not hide important uncertainty inside prose.
* If an assumption can materially change the answer, mark it clearly.
* If the task can proceed safely with a reasonable assumption, proceed and
  label it.
* Ask a clarifying question only when the task would otherwise be impossible,
  unsafe or likely wrong.
* Do not ask the user to repeat information already present in current context.

## Execution Rules

During execution:

* Prefer current project contracts over old chat history.
* Prefer repository files and decisions over memory.
* Prefer machine-checkable rules over verbal instructions.
* Do not revive deprecated decisions unless the user explicitly asks for
  historical comparison.
* If new evidence contradicts the Task Packet, stop and update the Task Packet
  before continuing.
* If the work is long, provide occasional short progress updates with concrete
  findings.

## Current Context Contract

When the user asks for a context handoff for a new chat, produce a
**Current Context Contract**.

Trigger phrases include:

* "сделай current context contract"
* "собери контекст для нового чата"
* "сделай handoff"
* "подготовь task packet для следующего чата"
* "сожми контекст"
* "зафиксируй текущее состояние"

The contract must be standalone and pasteable into a new chat.

Template:

```md
# Current Context Contract

## 1. Project / topic

Short description of the project or topic.

## 2. Current accepted decisions

- Decision 1.
- Decision 2.
- Decision 3.

Only active decisions go here.

## 3. Deprecated / rejected / historical decisions

- Old idea 1 - rejected because...
- Old idea 2 - superseded by...

This section exists to prevent the next agent from accidentally reviving old
plans.

## 4. Current architecture / state

- Current repo state, system design, or task state.
- Important files/modules/docs if known.

## 5. Active constraints

- Technical constraints.
- Legal/licensing constraints.
- Product constraints.
- Process constraints.
- User preferences.

## 6. Open questions / risks

- Unknown 1.
- Unknown 2.
- Risk 1.

## 7. Immediate next task

What the next agent should do first.

## 8. Definition of done for the next task

How to know the next task is complete.

## 9. Sources of truth

- Repository files.
- Decisions.
- Docs.
- User-provided files.
- External sources, if any.

## 10. Instructions to the next agent

- Start by forming a Task Packet.
- State assumptions before execution.
- Do not rely on stale chat history over this contract.
- Verify repository state before making code claims.
```

The Current Context Contract must be compact, current and operational. It must
not be a diary of the whole conversation.

## Output Policy

For small tasks, use a compact form:

```md
Task Packet:
- Current state: ...
- Task: ...
- Done when: ...

Assumptions:
- ...
```

For large tasks, use the full structure.

For direct factual questions or simple explanations, do not over-format unless
the answer depends on project context.

For code, architecture, research, repo review, specifications and handoff
tasks, always use the Task Packet plus Assumptions workflow.

## Anti-Context-Rot Rules

The agent must not:

* treat every previous message as equally authoritative;
* mix old rejected ideas with current decisions;
* assume that large context means reliable memory;
* silently overwrite the user's latest pivot;
* continue execution after discovering that the assumed project state is wrong;
* bury important uncertainty in vague wording;
* produce a long historical summary when a current operational contract is
  needed.

The agent must:

* compress context before acting;
* label uncertainty;
* separate current decisions from history;
* keep task scope explicit;
* preserve the user's latest stated direction;
* make the next step executable.

## OpenStrike-Specific Rule

New agents should start from these files before relying on conversation
history:

1. `AGENTS.md`
2. `docs/agent_context_hygiene.md`
3. `docs/current_context_contract.md`

Update `docs/current_context_contract.md` whenever accepted decisions,
current architecture state, active risks or immediate next tasks materially
change.
