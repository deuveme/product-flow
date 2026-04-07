---
description: Generates design artifacts: research, data model, and contracts.
user-invocable: false
context: fork
handoffs:
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Analyze Split
    agent: speckit.split
    prompt: Analyze if this spec should be split
    send: true
  - label: Create Checklist
    agent: speckit.checklist
    prompt: Create a checklist for the following domain...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Run `.specify/scripts/bash/setup-plan.sh --json` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load context**: Read FEATURE_SPEC and `.specify/memory/constitution.md`. Load IMPL_PLAN template (already copied).

   Also load technical context if available (extracted from the original feature description when the user provided implementation details):

   ```bash
   cat $SPECS_DIR/technical-context.md 2>/dev/null
   ```

   If the file exists, use its contents as a head start for Phase 0 research — it contains technical details the user already specified. Do not copy it verbatim into research.md; incorporate it after validating against the project stack and existing decisions.

   Also load event model context if available:

   ```bash
   cat $SPECS_DIR/event-model.md 2>/dev/null
   ```

   If the file exists, read it before starting Phase 0. The event model defines aggregates, commands, events, and Given/When/Then specs already agreed — use it as the authoritative source for `data-model.md` entities and `contracts/` when generating Phase 1 artifacts. Do not redefine what is already modeled there.

2b. **Detect redesign mode**: Scan FEATURE_SPEC for visual or UX redesign signals. Keywords: "redesign", "rediseño", "new look", "new design", "visual overhaul", "UI revamp", "rework the UI", "rework the UX", "visual refresh", "new interface", "change the look", "change the UI", "new layout".

If any are found, set `REDESIGN_MODE = true` and apply these rules for the rest of this skill:

- **Existing code is the baseline, not the deliverable.** Finding that a feature already exists does NOT mean work is done — it means the current implementation is the starting point to be replaced or modified.
- **Phase 0 research must document two states:** current state (what exists now) and target state (what the spec describes). The gap between them is the scope of work.
- **Phase 1 artifacts must represent the TARGET state**, not the current implementation. Do not copy existing data models or contracts verbatim — evaluate whether they need to change.
- Do not mark any item as "already implemented" or "no changes needed" based solely on existing code. Only mark as complete if the existing code already matches the target spec AND the spec explicitly confirms no change is needed.

3. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Phase 1: Update agent context by running the agent script
   - Re-evaluate Constitution Check post-design

4. **Stop and report**: Command ends after Phase 2 planning. Report branch, IMPL_PLAN path, and generated artifacts.

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

   If `REDESIGN_MODE = true`, add a mandatory section to `research.md`:

   ```markdown
   ## Redesign Baseline

   **Current state:** [description of what currently exists — UI, flows, components, data]
   **Target state:** [description of what the spec requires — new UI, new flows, new visual outcomes]
   **Delta (scope of work):** [explicit list of what must change — even if functionality is unchanged]
   ```

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Define interface contracts** (if project has external interfaces) → `/contracts/`:
   - Identify what interfaces the project exposes to users or other systems
   - Document the contract format appropriate for the project type
   - Examples: public APIs for libraries, command schemas for CLI tools, endpoints for web services, grammars for parsers, UI contracts for applications
   - Skip if project is purely internal (build scripts, one-off tools, etc.)

3. **Agent context update**:
   - Run `.specify/scripts/bash/update-agent-context.sh claude`
   - These scripts detect which AI agent is in use
   - Update the appropriate agent-specific context file
   - Add only new technology from current plan
   - Preserve manual additions between markers

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file

## Key rules

- Use absolute paths
- ERROR on gate failures or unresolved clarifications
