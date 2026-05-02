---
description: Generates a requirements quality checklist for the feature.
user-invocable: false
model: haiku
context: fork
effort: low
---

## Checklist Purpose: "Unit Tests for English"

**CRITICAL CONCEPT**: Checklists are **UNIT TESTS FOR REQUIREMENTS WRITING** - they validate the quality, clarity, and completeness of requirements in a given domain.

**NOT for verification/testing**:

- ❌ NOT "Verify the button clicks correctly"
- ❌ NOT "Test error handling works"
- ❌ NOT "Confirm the API returns 200"
- ❌ NOT checking if code/implementation matches the spec

**FOR requirements quality validation**:

- ✅ "Are visual hierarchy requirements defined for all card types?" (completeness)
- ✅ "Is 'prominent display' quantified with specific sizing/positioning?" (clarity)
- ✅ "Are hover state requirements consistent across all interactive elements?" (consistency)
- ✅ "Are accessibility requirements defined for keyboard navigation?" (coverage)
- ✅ "Does the spec define what happens when logo image fails to load?" (edge cases)

**Metaphor**: If your spec is code written in English, the checklist is its unit test suite. You're testing whether the requirements are well-written, complete, unambiguous, and ready for implementation - NOT whether the implementation works.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Execution Steps

Show at the very start, before any other work:

```
⏳ Reviewing requirements quality...
```

### 1. Setup

Resolve feature paths and validate prerequisites:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
CURRENT_BRANCH="${SPECIFY_FEATURE:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
```

If `CURRENT_BRANCH` does not match `^[0-9]{8}-[0-9]{4}-`: ERROR "Not on a feature branch. Run /product-flow:start-feature or /product-flow:start-improvement first." and stop.

Derive paths (all absolute):
- `FEATURE_DIR` = `$REPO_ROOT/specs/$CURRENT_BRANCH`

Validate:
- If `FEATURE_DIR` does not exist: ERROR "Feature directory not found. Run /product-flow:start-feature or /product-flow:start-improvement first." and stop.
- If `$FEATURE_DIR/plan.md` does not exist: ERROR "plan.md not found. Run /product-flow:continue first." and stop.

Build `AVAILABLE_DOCS` list (optional files present in `FEATURE_DIR`):
- `research.md` if it exists
- `data-model.md` if it exists
- `contracts/` if the directory exists and is non-empty
- `quickstart.md` if it exists

### 2. Clarify scope (product questions only)

Read spec.md and plan.md to infer checklist scope automatically. Determine which quality dimensions are relevant based on the feature domain and available artifacts.

Only ask the user if there is a genuine **product** decision about scope that cannot be inferred from the artifacts — for example, whether to include accessibility requirements when the spec is ambiguous about target audience, or whether to cover offline/error scenarios when the spec doesn't mention them.

**Never ask technical questions** (architecture, frameworks, performance thresholds, data model details). Resolve those autonomously.

If product scope questions are needed, ask them all in a **single AskUserQuestion call**:
- One entry per question
- `question`: full question text ending with "?"
- `header`: short topic label max 12 chars
- `options`: 2–4 choices. Place the recommended option **first** with `" (Recommended)"`.
- `multiSelect`: false

After receiving answers, record each one as a PR comment using `/product-flow:pr-comments write`:
- `type`: `product`
- `status`: `ANSWERED`
- `body`:
  ```
  **Checklist scope decision:** "[question asked]"

  **Answer:** [the user's answer]

  **Applied:** [how this shaped the checklist scope]
  ```

### 3. Load feature context

Read from FEATURE_DIR:
- `spec.md`: Feature requirements and user stories
- `plan.md`: Technical decisions, data model, dependencies
- `tasks.md` (if exists): Implementation tasks

Load only the portions relevant to the determined focus areas.

### 4. Generate and auto-evaluate checklist items

For each checklist item, execute a two-phase process:

**Phase 1 — Generate the question**: Write a requirement quality question following the rules below.

**Phase 2 — Evaluate against artifacts**: Immediately check whether the spec/plan/tasks already answer that question.
- If the requirement is clearly present in the artifacts: mark `- [x]` and add an evidence reference.
- If the requirement is genuinely missing or ambiguous: mark `- [ ]` and tag with `[Gap]`, `[Ambiguity]`, or `[Conflict]`.

**Item format**:
```
- [x] CHK001 Are the exact number of featured episodes specified? [Completeness, Spec §FR-1: "3 featured episodes displayed in a horizontal row"]
- [ ] CHK002 Is the fallback behavior defined when the API returns no episodes? [Gap]
```

**CORE PRINCIPLE - Test the Requirements, Not the Implementation**:
Every checklist item MUST evaluate the REQUIREMENTS THEMSELVES for:
- **Completeness**: Are all necessary requirements present?
- **Clarity**: Are requirements unambiguous and specific?
- **Consistency**: Do requirements align with each other?
- **Measurability**: Can requirements be objectively verified?
- **Coverage**: Are all scenarios/edge cases addressed?

**Category Structure** - Group items by requirement quality dimensions:
- **Requirement Completeness** (Are all necessary requirements documented?)
- **Requirement Clarity** (Are requirements specific and unambiguous?)
- **Requirement Consistency** (Do requirements align without conflicts?)
- **Acceptance Criteria Quality** (Are success criteria measurable?)
- **Scenario Coverage** (Are all flows/cases addressed?)
- **Edge Case Coverage** (Are boundary conditions defined?)
- **Non-Functional Requirements** (Performance, Security, Accessibility, etc.)
- **Dependencies & Assumptions** (Are they documented and validated?)
- **Ambiguities & Conflicts** (What needs clarification?)

**Traceability**:
- ≥80% of `- [x]` items MUST include a spec/plan reference: `[Spec §X.Y: "quote"]`
- All `- [ ]` items MUST include a marker: `[Gap]`, `[Ambiguity]`, `[Conflict]`, or `[Assumption]`

**Content Consolidation**:
- Soft cap: If raw candidate items > 40, prioritize by risk/impact
- Merge near-duplicates
- If >5 low-impact edge cases, consolidate into one item

**🚫 ABSOLUTELY PROHIBITED**:
- ❌ Items starting with "Verify", "Test", "Confirm", "Check" + implementation behavior
- ❌ References to code execution, user actions, system behavior
- ❌ "Displays correctly", "works properly", "functions as expected"
- ❌ Implementation details (frameworks, APIs, algorithms)

### 5. Resolve unchecked items

For each `- [ ]` item remaining after step 4:

**Technical gaps** (architecture, data model, infrastructure, performance, security implementation details):
- Resolve autonomously using existing artifacts and best practices.
- Update the item to `- [x]` with the chosen approach as evidence.
- Record the decision as a PR comment via `/product-flow:pr-comments write`:
  - `type`: `technical`, `status`: `ANSWERED`
  - `body`:
    ```
    **Checklist gap detected:** "[the gap identified]"

    **Proposed answers:** A. "[option A]" B. "[option B]"

    **Autonomously chosen answer:** "[chosen option]" because "[brief reasoning]"
    ```

**Product gaps** (user stories, business rules, acceptance criteria, UX flows, feature scope):
- Collect ALL product gaps and ask the PM in a **single AskUserQuestion call** (one entry per gap).
- After receiving answers:
  - Update each item to `- [x]` with the PM's answer as evidence.
  - Record each answer as a PR comment via `/product-flow:pr-comments write`:
    - `type`: `product`, `status`: `ANSWERED`
    - `body`:
      ```
      **Checklist gap detected:** "[the gap identified]"

      **Options:** A. "[option A]" B. "[option B]"

      **PM answer:** "[the answer received]"

      **Applied:** [what was updated in the checklist or artifacts]
      ```

After resolving all gaps, every item in the checklist should be `- [x]`. Any item that genuinely cannot be resolved (requires external input not available) remains `- [ ]` with an explicit note explaining what is blocking it.

### 6. Write checklist file

Generate the checklist file following the canonical template in `$REPO_ROOT/.specify/templates/checklist-template.md` for title, meta section, category headings, and ID formatting. If template is unavailable, use: H1 title, purpose/created meta lines, `##` category sections.

File handling:
- If file does NOT exist: create new file, number items starting from CHK001.
- If file exists: compare scope against existing items. If same scope, ask whether to append or skip. If different scope, append continuing from the last CHK ID.
- Never delete or replace existing checklist content.

Use a short, descriptive filename based on domain (e.g., `requirements.md`, `ux.md`, `api.md`).

### 7. Report

```
✅ Checklist complete — <N> items verified, <M> gaps resolved.
📋 specs/<branch>/checklists/<filename>
```

If any items remain `- [ ]` after resolution, list them briefly:

```
⚠️ <K> unresolved items require external input — see checklist for details.
```

No status tables, no item-by-item breakdown.

**Important**: Each invocation uses a short, descriptive checklist filename and either creates a new file or appends to an existing one. This allows multiple checklists of different types (e.g., `ux.md`, `api.md`, `security.md`). To avoid clutter, clean up obsolete checklists when done.

## Anti-Examples: What NOT To Do

**❌ WRONG - These test implementation, not requirements:**

```markdown
- [ ] CHK001 - Verify landing page displays 3 episode cards [Spec §FR-001]
- [ ] CHK002 - Test hover states work correctly on desktop [Spec §FR-003]
```

**✅ CORRECT - These test requirements quality, auto-evaluated:**

```markdown
- [x] CHK001 - Are the number and layout of featured episodes explicitly specified? [Completeness, Spec §FR-001: "3 cards in horizontal row"]
- [ ] CHK002 - Are hover state requirements consistently defined for all interactive elements? [Gap]
- [x] CHK003 - Are navigation requirements clear for all clickable brand elements? [Clarity, Spec §FR-010: "logo navigates to home"]
```
