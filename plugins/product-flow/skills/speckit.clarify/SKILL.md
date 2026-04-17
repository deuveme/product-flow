---
description: Resolves ambiguities in the spec — technical ones autonomously, product ones by asking the PM.
user-invocable: false
model: sonnet
effort: high
handoffs:
  - label: Build Technical Plan
    agent: speckit.plan
    prompt: Create a plan for the spec. I am building with...
  - label: Analyze Split
    agent: speckit.split
    prompt: Analyze if this spec should be split
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

Goal: Detect and reduce ambiguity or missing decision points in the active feature specification and record the clarifications directly in the spec file.

Note: This clarification workflow is expected to run (and be completed) BEFORE invoking `/product-flow:speckit.plan`. If the user explicitly states they are skipping clarification (e.g., exploratory spike), you may proceed, but must warn that downstream rework risk increases.

Execution steps:

1. **Setup**: Resolve feature paths:

   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
   CURRENT_BRANCH="${SPECIFY_FEATURE:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
   ```

   If `CURRENT_BRANCH` does not match `^[0-9]{3}-`: ERROR "Not on a feature branch. Run /product-flow:start-feature or /product-flow:start-improvement first." and stop.

   Derive paths:
   - `FEATURE_DIR`  = `$REPO_ROOT/specs/$CURRENT_BRANCH`
   - `FEATURE_SPEC` = `$FEATURE_DIR/spec.md`
   - `IMPL_PLAN`    = `$FEATURE_DIR/plan.md`
   - `TASKS`        = `$FEATURE_DIR/tasks.md`

   If `FEATURE_SPEC` does not exist: ERROR "spec.md not found. Run /product-flow:start-feature or /product-flow:start-improvement first." and stop.

1b. **Load split context (if available)**:

   ```bash
   cat "$FEATURE_DIR/split-analysis.md" 2>/dev/null
   ```

   If `split-analysis.md` exists: load it as SPLIT_CONTEXT. Read the "Feature Context" section to determine:
   - Whether this is a child feature (if "Original feature" is not "This is the original feature.")
   - What scope boundaries were debated and decided in the split analysis
   - What was deliberately excluded from this feature's scope

   Use this context throughout the clarification: do not re-debate scope boundaries already decided in the split. When a potential ambiguity touches a boundary that was explicitly resolved in the split debate, respect that decision instead of re-opening it.

   If this is a child feature, also load the parent's split analysis (referenced in the "Inherited from parent" section) as additional background context.

1c. **Terminology validation** — runs before the main scan.

Load the spec and extract all domain-specific business terms: nouns that carry industry, company, or product-specific meaning and could be interpreted differently outside this context. Examples: financial instruments, process names, role names, product-specific states, business events.

For each extracted term:
- Derive the most reasonable definition based on the spec context and general domain knowledge.
- Skip terms that are self-evident from the spec text or are standard technical terms with no ambiguity.

For each term that needs confirmation, ask the PM via a **single `AskUserQuestion` call** grouping all terms:
- One entry per term:
  - `question`: "**[Term]** — [AI-proposed definition in one sentence]"
  - `header`: the term (max 12 chars)
  - `options`:
    - `A. Correct` — the definition is accurate for this context
    - `B. Incorrect` — the definition is wrong (free-text field for correction)
    - `C. I don't know` — the team needs to define this
  - `multiSelect`: false

Process each answer:
- **A (Correct)**: record the confirmed definition in working memory. Add to `## Glossary` section in the spec (create it before `## Clarifications` if missing). Format: `- **[Term]**: [definition]`.
- **B (Incorrect)**: record the user's correction as the canonical definition. Add to `## Glossary` with the corrected definition. Record any conflicting uses in the spec as flags for step 2.
- **C (I don't know)**: invoke `/product-flow:pr-comments write` with:
  - `type`: `product`, `status`: `UNANSWERED`
  - `body`:
    ```
    **Undefined term: "[Term]"**

    This term appears in the spec but its exact meaning in this context is unclear.

    **AI proposed definition:** [proposed definition]

    ⚠️ The team must define this term before the spec can be finalized.
    ```
  Mark the term internally as **unresolved** — flag any spec sections that use it as potentially incorrect.

After processing all terms: if any terms are unresolved (C answers), warn:
```
⚠️  [N] term(s) left undefined and posted to the PR for team input.
   Sections using these terms may need revision once defined.
   Proceeding with the rest of the analysis using the AI-proposed definitions as a placeholder.
```

If no domain-specific terms are found, skip this step silently.

2. Load the current spec file. Perform a structured ambiguity & coverage scan using this taxonomy. For each category, mark status: Clear / Partial / Missing. Produce an internal coverage map used for prioritization (do not output raw map unless no questions will be asked).

   Functional Scope & Behavior:
   - Core user goals & success criteria
   - Explicit out-of-scope declarations
   - User roles / personas differentiation

   Domain & Data Model:
   - Entities, attributes, relationships
   - Identity & uniqueness rules
   - Lifecycle/state transitions
   - Data volume / scale assumptions

   Interaction & UX Flow:
   - Critical user journeys / sequences
   - Error/empty/loading states
   - Accessibility or localization notes

   Non-Functional Quality Attributes:
   - Performance (latency, throughput targets)
   - Scalability (horizontal/vertical, limits)
   - Reliability & availability (uptime, recovery expectations)
   - Observability (logging, metrics, tracing signals)
   - Security & privacy (authN/Z, data protection, threat assumptions)
   - Compliance / regulatory constraints (if any)

   Integration & External Dependencies:
   - External services/APIs and failure modes
   - Data import/export formats
   - Protocol/versioning assumptions

   Edge Cases & Failure Handling:
   - Negative scenarios
   - Rate limiting / throttling
   - Conflict resolution (e.g., concurrent edits)

   Constraints & Tradeoffs:
   - Technical constraints (language, storage, hosting)
   - Explicit tradeoffs or rejected alternatives

   Terminology & Consistency:
   - Canonical glossary terms
   - Avoided synonyms / deprecated terms

   Completion Signals:
   - Acceptance criteria testability
   - Measurable Definition of Done style indicators

   Misc / Placeholders:
   - TODO markers / unresolved decisions
   - Ambiguous adjectives ("robust", "intuitive") lacking quantification

   For each category with Partial or Missing status, add a candidate question opportunity unless:
   - Clarification would not materially change implementation or validation strategy
   - Information is better deferred to planning phase (note internally)

3. Generate (internally) a prioritized list of candidate clarification questions. Apply these constraints:
    - Include a question only if its answer would materially change the spec — architecture, data modeling, task decomposition, test design, UX behavior, operational readiness, or compliance validation.
    - Exclude questions already answered, trivial stylistic preferences, or plan-level execution details (unless blocking correctness).
    - Favor clarifications that reduce downstream rework risk or prevent misaligned acceptance tests.
    - Ensure category coverage balance: prioritize highest-impact unresolved categories first.
    - **Classify each question** as **Technical** or **Product**:
      - **Technical**: authentication, authorisation, security, compliance, data retention, integration patterns, infrastructure constraints, performance targets — resolve autonomously, never ask the PM.
      - **Product**: business intent, priorities, functional scope, user flows, terminology, acceptance criteria — ask the PM.
    - Ask all product questions that survive the quality filter — do not cap or silently drop any.

4. Resolve all questions:

    **Step 4a — Technical questions (autonomous, no PM involvement):**

    For each technical question:
    - Attempt to resolve using project context: existing code, `.agents/rules/base.md`, project stack, industry standards.
    - If resolved: invoke `/product-flow:pr-comments write` with:
      - `type`: `technical`, `status`: `ANSWERED`
      - `body`:
        ```
        **Technical question:** "[question]"

        **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

        **Chosen answer:** "[chosen option]" — [brief reasoning]
        ```
    - If unresolved: invoke `/product-flow:pr-comments write` with:
      - `type`: `technical`, `status`: `UNANSWERED`
      - `body`:
        ```
        **Technical question:** "[question]"

        **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

        ⚠️ Unresolved — requires input from the development team.
        ```

    **Step 4b — Product questions (single grouped call to PM):**

    If there are no product questions: output the following message to the user and skip to step 5.

    > "I have no product doubts about this spec. Proceeding with autonomous technical resolution."

    Otherwise, ask all product questions in a **single AskUserQuestion call**:
    - One entry per question:
      - `question`: full question text ending with "?"
      - `header`: short topic label max 12 chars
      - `options`: 2–4 choices. Place the recommended option **first** with `" (Recommended)"`. Each option has a `description` explaining implications.
      - `multiSelect`: false
    - The tool adds "Other" automatically for free-form answers.
    - Wait for all answers before continuing.
    - If any answer is ambiguous, ask a follow-up for that question only (does not count toward the 7-question limit).
    - Record all answers in working memory before writing to disk.

5. Integration after EACH accepted answer (incremental update approach):
    - Maintain in-memory representation of the spec (loaded once at start) plus the raw file contents.
    - For the first integrated answer in this session:
       - Ensure a `## Clarifications` section exists (create it just after the highest-level contextual/overview section per the spec template if missing).
       - Under it, create (if not present) a `### Session YYYY-MM-DD` subheading for today.
    - Append a bullet line immediately after acceptance: `- Q: <question> → A: <final answer>`.
    - Then immediately apply the clarification to the most appropriate section(s):
       - Functional ambiguity → Update or add a bullet in Functional Requirements.
       - User interaction / actor distinction → Update User Stories or Actors subsection (if present) with clarified role, constraint, or scenario.
       - Data shape / entities → Update Data Model (add fields, types, relationships) preserving ordering; note added constraints succinctly.
       - Non-functional constraint → Add/modify measurable criteria in Non-Functional / Quality Attributes section (convert vague adjective to metric or explicit target).
       - Edge case / negative flow → Add a new bullet under Edge Cases / Error Handling (or create such subsection if template provides placeholder for it).
       - Terminology conflict → Normalize term across spec; retain original only if necessary by adding `(formerly referred to as "X")` once.
    - If the clarification invalidates an earlier ambiguous statement, replace that statement instead of duplicating; leave no obsolete contradictory text.
    - Save the spec file AFTER each integration to minimize risk of context loss (atomic overwrite).
    - Preserve formatting: do not reorder unrelated sections; keep heading hierarchy intact.
    - Keep each inserted clarification minimal and testable (avoid narrative drift).

6. Validation (performed after EACH write plus final pass):
   - Clarifications session contains exactly one bullet per accepted answer (no duplicates).
   - All product questions that survived the quality filter were asked — none silently dropped.
   - Updated sections contain no lingering vague placeholders the new answer was meant to resolve.
   - No contradictory earlier statement remains (scan for now-invalid alternative choices removed).
   - Markdown structure valid; only allowed new headings: `## Clarifications`, `### Session YYYY-MM-DD`.
   - Terminology consistency: same canonical term used across all updated sections.

7. Write the updated spec back to `FEATURE_SPEC`.

8. Record clarifications in the PR: after the questioning loop ends, invoke `/product-flow:pr-comments write` once per answered question with:
   - `type`: `product`, `status`: `ANSWERED`
   - `body`:
     ```
     **Clarification:** "[the question asked]"

     **Answer:** [the user's accepted answer]

     **Applied to spec:** [which section(s) were updated and what changed]
     ```

If no questions were asked (no critical ambiguities found), skip this step entirely.

9. Report completion (after questioning loop ends or early termination):
   - Number of questions asked & answered.
   - Path to updated spec.
   - Sections touched (list names).
   - Coverage summary table listing each taxonomy category with Status: Resolved (was Partial/Missing and addressed), Deferred (exceeds question quota or better suited for planning), Clear (already sufficient), Outstanding (still Partial/Missing but low impact).
   - If any Outstanding or Deferred remain, recommend whether to proceed to `/product-flow:speckit.plan` or run `/product-flow:speckit.clarify` again later post-plan.
   - Suggested next command.

Behavior rules:

- If no meaningful ambiguities found (or all potential questions would be low-impact), respond: "No critical ambiguities detected worth formal clarification." and suggest proceeding.
- If spec file missing, instruct user to run `/product-flow:start-feature` or `/product-flow:start-improvement` first (do not create a new spec here).
- Never ask the PM technical questions — resolve them autonomously and write to PR.
- Avoid speculative tech stack questions unless the absence blocks functional clarity.
- Respect user early termination signals ("stop", "done", "proceed").
- If no product questions exist, output a compact coverage summary (all categories Clear or Deferred to plan) then suggest advancing.
- If many product questions arise, ask them all in a single grouped AskUserQuestion call — never silently drop any.

Context for prioritization: $ARGUMENTS
