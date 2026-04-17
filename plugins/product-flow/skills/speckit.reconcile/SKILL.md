---
description: "Reconciles drift between implementation and spec/plan/tasks."
user-invocable: false
model: sonnet
effort: high
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding. The text after
`/product-flow:speckit.reconcile` **is** the gap report — a natural language
description of what is missing or changed in the implementation versus the
spec/plan.

**Examples of valid gap reports:**
- `"Backend + tests for Invoice Settings exist but there is no sidebar link or route."`
- `"The /api/v1/settings endpoint now requires an 'org_id' header that is not in the original plan."`
- `"The payment confirmation screen shows a modal but the spec says it should be an inline message."`

Optional flags in `$ARGUMENTS`:
- `--spec-only` — update only `spec.md`
- `--plan-only` — update only `plan.md`
- `--tasks-only` — update only `tasks.md`

If `$ARGUMENTS` is empty: output
`ERROR: No gap report provided. Usage: /product-flow:speckit.reconcile <gap description>`
and stop.

## Outline

**Constraint**: Operate strictly in place. Do **not** create branches, switch
branches, or run feature-creation scripts. All edits target existing files in
FEATURE_DIR.

### 0. Setup and Context Loading

Resolve feature paths:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
CURRENT_BRANCH="${SPECIFY_FEATURE:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
```

If `CURRENT_BRANCH` does not match `^[0-9]{3}-`: ERROR "Not on a feature branch. Run /product-flow:start-feature or /product-flow:start-improvement first." and stop.

Derive absolute paths:
- `FEATURE_DIR`  = `$REPO_ROOT/specs/$CURRENT_BRANCH`
- `FEATURE_SPEC` = `$FEATURE_DIR/spec.md`
- `IMPL_PLAN`    = `$FEATURE_DIR/plan.md`
- `TASKS_FILE`   = `$FEATURE_DIR/tasks.md`

Validate that `spec.md` and `plan.md` exist. If either is missing, stop with:
> ⚠️ Missing required files in `FEATURE_DIR`. Expected: spec.md, plan.md.
> Run `/product-flow:start-feature` or `/product-flow:start-improvement` first.

If `tasks.md` does not exist, create it with a `## Remediation: Gaps` heading
before appending new tasks.

Read `FEATURE_SPEC`, `IMPL_PLAN`, and `TASKS_FILE`.

If `$REPO_ROOT/.specify/memory/constitution.md` exists, read it and extract MUST-level
constraints and architecture standards. Any reconciliation item that conflicts
with a MUST principle is flagged as CRITICAL:
```
🔴 CONSTITUTION CONFLICT: [reconciliation item] conflicts with [principle]
→ This must be resolved in Step 2 clarification before edits proceed.
```

### 1. Gap Normalization

Analyze the gap report and normalize it into structured reconciliation items:

| Category | Typical Issues | Action |
|----------|----------------|--------|
| **Wiring & Navigation** | Missing routes, menu items, sidebar links | Add to `plan.md`, create tasks |
| **Contracts** | API field mismatches, missing headers, changed payloads | Update `plan.md` contracts, create tasks |
| **Acceptance Criteria** | Implementation behaves differently than planned | Update `spec.md` scenarios/criteria |
| **Test Coverage** | New behavior without verification | Add task for test |
| **Logic/UX** | Missing toasts, wrong error handling, incorrect state | Add tasks for implementation |

For each item, verify it does not conflict with any MUST-level constitution
constraint. Flag conflicts as CRITICAL and include in Step 2 clarification.

### 2. Clarify (Once, Max 5 Questions)

If the gap report is ambiguous (e.g., "the button doesn't work" without
specifying which button), classify each ambiguity and resolve it:

**Classification rule — when in doubt**: if a decision affects something the user sees, experiences, or can do directly — even if it sounds technical — classify it as **Product**. Only classify as Technical if the decision is completely invisible to users and affects only internal implementation.

- **Technical** (architecture, API contracts, data model, infrastructure): resolve autonomously using existing artifacts and project context. Invoke `/product-flow:pr-comments write` with:
  - `type`: `technical`, `status`: `ANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
    ```

- **Product** (scope, user intent, acceptance criteria, UX behaviour): ask the PM via a single **AskUserQuestion** call (one entry per ambiguity):
  - `question`: describe the ambiguity and ask what to do, ending with "?"
  - `header`: short topic label max 12 chars
  - `options`: 2–4 choices with `description` explaining each. Place the recommended option first with `" (Recommended)"`.
  - `multiSelect`: false

  After receiving the PM's answers, invoke `/product-flow:pr-comments write` once per answered item with:
  - `type`: `product`, `status`: `ANSWERED`
  - `body`:
    ```
    **Reconcile question:** "[the question asked to the PM]"

    **Options:** A. "[option A]" B. "[option B]" (... etc)

    **PM answer:** "[the answer received]"

    **Change applied:** [what was updated and in which artifact]
    ```

After resolving all ambiguities, scan for any remaining `[NEEDS CLARIFICATION]` markers. If any exist, **STOP**:

```
🚫 Reconciliation blocked — <N> unresolved item(s) remain:

  · [item description]
  · ...

These could not be resolved automatically. Address them and run
/product-flow:speckit.reconcile again.
```

If the gap report is fully unambiguous from the start, skip this step entirely and proceed silently.

### 3. Impact Map

Before making any edits, output a brief impact map:

```markdown
### Sync Impact Map
| Artifact | Changes | Tasks Generated |
|----------|---------|-----------------|
| spec.md  | Update AC-04, add edge case scenario | None |
| plan.md  | Add route /settings, update API contract | None |
| tasks.md | Append remediation tasks | T045, T046 |
```

### 4. Surgical Edits

#### 4.1 Update `spec.md` (if needed)

- **Acceptance criteria**: amend existing criteria or add new ones that reflect
  the shipped reality.
- **User scenarios**: add missing scenarios discovered during implementation.
- **Revision note**: append at the bottom of the file:
  ```markdown
  ### Revision: Reconcile [YYYY-MM-DD]
  - Reason: [One-sentence summary of drift reconciled]
  ```

#### 4.2 Update `plan.md` (if needed)

- **Routing & navigation**: add missing routes, endpoints, or UI wiring details.
- **Integration contracts**: update API schemas, request/response headers, or
  payloads to match actual implementation.
- **Testing strategy**: ensure strategy covers the newly identified gaps.
- **Revision note**: append (same format as spec.md).

#### 4.3 Update `tasks.md` (if needed)

Create remediation tasks to close the drift. This is the most critical step.

**Task format**:
```
- [ ] T{NNN} [P?] [{story?}] {action verb} {what} in {exact/file/path.ext} [Reconcile]
```

- `[P]` is optional — include only for blocking or high-urgency tasks.
- `[Reconcile]` tag is always appended for traceability.

**Rules**:
1. **Increment IDs**: find the highest `T###` in `tasks.md`, start new tasks from `max + 1`. Never reuse or renumber existing IDs. Before appending, scan for ID gaps (e.g., T003 missing between T002 and T004) and log a warning in the Sync Impact Report: `⚠️ Gap detected in task IDs: T003 is missing. IDs are not sequential.` Do not renumber existing tasks — gaps are preserved for audit traceability.
2. **Phase placement**: put new tasks under the relevant user story phase. If
   none fits, create a `## Remediation: Gaps` section at the end.
3. **Exact paths**: every task MUST include the exact file path where the change
   is needed.
4. **Mandatory test**: if the gap is a **Wiring & Navigation** issue, add a
   corresponding integration test task.

### 5. Sync Impact Report

Output the final report:

```markdown
# Sync Impact Report

## Changed Files
| File (absolute path) | Change Summary |
|----------------------|----------------|
| /path/to/spec.md  | Updated acceptance criteria AC-04, added edge case scenario |
| /path/to/plan.md  | Added route /settings, updated API contract |
| /path/to/tasks.md | Added N remediation tasks |

## New Remediation Tasks
- **T045**: Add sidebar link in `src/components/Sidebar.tsx`
- **T046**: Add route in `src/router/index.ts`
- **T047**: Integration test: navigate to Settings in `tests/integration/navigation.test.ts`

## Outstanding Decisions
[List any [NEEDS CLARIFICATION] items, or "None"]

## Next Step
```

Next step recommendation:
- If remediation tasks were added → run `/product-flow:build` to execute them
  (runs checklist, implement, and proposes verify-tasks), then
  `/product-flow:submit` when done.
- If only spec/plan were updated with no new tasks → run
  `/product-flow:speckit.verify` to confirm alignment.

## Done Criteria

- Gap report parsed and normalized.
- `spec.md` and `plan.md` surgically updated (or confirmed unchanged).
- `tasks.md` updated with incremented `T###` IDs and exact file paths.
- Integration test task added for any Wiring & Navigation gaps.
- Revision notes appended to modified artifacts.
- Sync Impact Report printed.
