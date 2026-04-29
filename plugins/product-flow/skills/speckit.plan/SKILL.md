---
description: Generates design artifacts: research, data model, and contracts.
user-invocable: false
context: fork
model: sonnet
effort: high
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

## Scope Discipline

These rules are invariant — they apply regardless of whether a `constitution.md` exists in the project:

- **Design only what the spec requires.** Every entity, contract, service, and architectural decision must trace to a functional requirement in `spec.md`. Do not add components because they are best practice for the domain if no requirement calls for them.
- **Research informs — it does not expand scope.** If research reveals that "industry standard" for this domain includes a feature not in the spec, document it as a note, not as a design decision. Never let research output become a new requirement.
- **New dependencies require explicit justification.** Do not add a library or external service unless a specific functional requirement cannot be met without it. If one is needed, flag it explicitly — do not add it silently.
- **The simplest design that satisfies the spec is the correct design.** Avoid layers, abstractions, or patterns not required by the current feature. Over-engineering is as harmful as under-engineering.
- **Autonomous decisions stay within scope.** Resolving architecture unknowns autonomously is allowed. Adding subsystems (queues, caches, notification services, etc.) because they seem appropriate for the domain is not — those require a requirement.

## Outline

1. **Setup**: Resolve feature paths:

   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
   CURRENT_BRANCH="${SPECIFY_FEATURE:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
   ```

   If `CURRENT_BRANCH` does not match `^[0-9]{3}-`: ERROR "Not on a feature branch. Run /product-flow:start-feature or /product-flow:start-improvement first." **STOP.**

   Derive paths:
   - `FEATURE_DIR` = `$REPO_ROOT/specs/$CURRENT_BRANCH`
   - `FEATURE_SPEC` = `$FEATURE_DIR/spec.md`
   - `IMPL_PLAN`   = `$FEATURE_DIR/plan.md`
   - `SPECS_DIR`   = `$FEATURE_DIR`
   - `BRANCH`      = `$CURRENT_BRANCH`

   Create the feature directory if it does not exist:
   ```bash
   mkdir -p "$FEATURE_DIR"
   ```

   Copy the plan template into `IMPL_PLAN` if a template exists and `IMPL_PLAN` does not yet exist:
   ```bash
   PLAN_TEMPLATE="$REPO_ROOT/.specify/templates/plan-template.md"
   [ -f "$REPO_ROOT/.specify/templates/overrides/plan-template.md" ] && \
     PLAN_TEMPLATE="$REPO_ROOT/.specify/templates/overrides/plan-template.md"
   [ ! -f "$IMPL_PLAN" ] && { [ -f "$PLAN_TEMPLATE" ] && cp "$PLAN_TEMPLATE" "$IMPL_PLAN" || touch "$IMPL_PLAN"; }
   ```

2. **Load context**: Read FEATURE_SPEC and `.specify/memory/constitution.md`. Load IMPL_PLAN template (already copied).

   If `.specify/memory/constitution.md` does not exist, output:
   ```
   ⚠️  constitution.md not found at .specify/memory/constitution.md
      Project-specific governance rules are inactive.
      Scope discipline rules from this skill apply regardless.
   ```
   Continue — the Scope Discipline section above remains in effect.

   Also load gathered context if available (visual assets, external documentation, and decisions made during feature kick-off):

   ```bash
   cat $SPECS_DIR/gathered-context.md 2>/dev/null
   ls $SPECS_DIR/images/ 2>/dev/null
   ls $SPECS_DIR/docs/ 2>/dev/null
   cat $SPECS_DIR/images/sources.md 2>/dev/null
   cat $SPECS_DIR/docs/sources.md 2>/dev/null
   ```

   If `gathered-context.md` exists, use it as background for the plan:
   - Product clarifications and technical decisions already made — do not revisit or re-decide them.
   - Images in `$SPECS_DIR/images/` are the authoritative visual references for the feature (wireframes, mockups, flow diagrams).
   - Documents in `$SPECS_DIR/docs/` are the authoritative requirements and API references — read them if relevant to the plan.
   - External links are in `images/sources.md` and `docs/sources.md`.

   Also load technical context if available (extracted from the original feature description when the user provided implementation details):

   ```bash
   cat $SPECS_DIR/technical-context.md 2>/dev/null
   ```

   If the file exists, use its contents as a head start for Phase 0 research — it contains technical details the user already specified. Do not copy it verbatim into research.md; incorporate it after validating against the project stack and existing decisions.

   Also load split analysis context if available:

   ```bash
   cat $SPECS_DIR/split-analysis.md 2>/dev/null
   ```

   If `split-analysis.md` exists: load it as SPLIT_CONTEXT. Read the "Feature Context" section to determine:
   - Whether this is a child feature (if "Original feature" is not "This is the original feature.")
   - What boundaries were decided and why (including alternatives discarded)
   - Whether any expand-contract coordination is needed with related features
   - What entities or subsystems are shared with sibling or parent features

   Use this when designing the plan: respect the vertical slice boundaries defined by the split analysis, ensure the technical plan does not creep into scope that was deliberately extracted, and coordinate on shared entities where expand-contract was flagged.

   If this is a child feature, the "Inherited from parent" section contains the full parent debate — use it to avoid reintroducing scope that was extracted from the parent.

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

0. **Scope guard — trace all design decisions to spec requirements**:

   Before generating any artifact, build a traceability map:
   - List every entity, service, contract, and external integration you plan to introduce.
   - For each one, identify the functional requirement(s) in `spec.md` that justify it.

   If any item has no traceable requirement:
   - **Do not include it** in `data-model.md`, `contracts/`, or `plan.md`.
   - If you believe it is genuinely necessary, add a `[OUT_OF_SCOPE?]` comment in `research.md` with a one-line explanation of why you think it might be needed, and continue without it. Do not ask the PM — let them discover it during review if needed.

   This check is mandatory. "It is standard for this domain" is not a valid justification — only a functional requirement in `spec.md` is.

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
   - Update `CLAUDE.md` at repo root with the tech stack from `plan.md`:
     1. Read `plan.md` and extract: Language/Version, Primary Dependencies, Storage, Project Type.
     2. If `CLAUDE.md` does not exist:
        - Read `.specify/templates/agent-file-template.md` (if present) and substitute placeholders: `[PROJECT NAME]` → basename of repo root, `[DATE]` → today's date, `[EXTRACTED FROM ALL PLAN.MD FILES]` → `- <lang> + <framework> (<branch>)`.
        - Write the result to `CLAUDE.md`. If the template does not exist, skip silently.
     3. If `CLAUDE.md` exists:
        - Under `## Active Technologies`: append `- <lang> + <framework> (<branch>)` if not already present.
        - Under `## Recent Changes`: prepend `- <branch>: Added <lang> + <framework>`, keeping only the 3 most recent entries.
        - Update the `Last updated:` date.
        - Write back to `CLAUDE.md`.

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file

## Key rules

- Use absolute paths
- ERROR on gate failures or unresolved clarifications
