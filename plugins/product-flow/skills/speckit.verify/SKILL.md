---
description: "Post-implementation quality gate. Validates code against spec, plan and tasks."
user-invocable: false
context: fork
model: sonnet
effort: medium
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). If the
user passes specific task IDs or file globs, restrict verification scope to those.

## Outline

**STRICTLY READ-ONLY**: Do **not** modify any files. Output a structured
analysis report only. Offer remediation suggestions only after the user
explicitly asks.

### 1. Setup

Resolve feature paths:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
CURRENT_BRANCH="${SPECIFY_FEATURE:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
```

If `CURRENT_BRANCH` does not match `^[0-9]{3}-`:
- Stop immediately and output:
  > ⚠️ No active feature detected. Verification requires a feature branch (format: `NNN-...`).
  > Run `/product-flow:status` to see available features.
- Do not proceed further.

Derive absolute paths:
- `FEATURE_DIR` = `$REPO_ROOT/specs/$CURRENT_BRANCH`
- `SPEC`        = `$FEATURE_DIR/spec.md`
- `PLAN`        = `$FEATURE_DIR/plan.md`
- `TASKS`       = `$FEATURE_DIR/tasks.md`
- `CONST`       = `$REPO_ROOT/.specify/memory/constitution.md`

Abort with a clear message if any required file is missing, instructing the
user which prerequisite command to run.

### 2. Load Artifacts (minimal, progressive)

Load only what is needed for each check. Do not dump full file contents into
memory at once.

**From `spec.md`**: user stories, acceptance scenarios, edge cases, functional
requirements, success criteria.

**From `plan.md`**: architecture decisions, tech stack, technical constraints,
project structure layout.

**From `data-model.md`** (if present): entities, relationships, validation
rules, state transitions.

**From `tasks.md`**: task IDs, completion status (`[x]`/`[X]` vs `[ ]`),
descriptions, referenced file paths, phase grouping.

**From `constitution.md`** (if present): extract all MUST-level constraints and
architecture principles.

### 3. Identify Implementation Scope

Parse all tasks from `tasks.md` — completed and incomplete.

- Extract file paths referenced in each completed task → **REVIEW_FILES** set.
- Track file paths in incomplete tasks → **INCOMPLETE_TASK_FILES** set.
- Flag any completed task whose referenced file does not exist on disk.

### 4. Verification Checks

Run all checks. Limit reported findings to the 20 highest-signal items;
summarize the rest in an overflow note at the end of the report.

#### A — Task Completion

- Compare `[x]`/`[X]` tasks vs total tasks in `tasks.md`.
- Flag as **CRITICAL** if more than 20% of tasks remain incomplete (i.e., fewer than 80% are marked done). A single incomplete task out of many is not a blocker.

#### B — File Existence

- Report every completed-task-referenced file that does not exist on disk.
- Report tasks with ambiguous or unresolvable paths.

#### C — Requirement Coverage

- For each functional requirement in `spec.md`, check for implementation
  evidence in REVIEW_FILES (function names, identifiers, or patterns that
  correspond to the requirement).
- Flag requirements with zero evidence.

#### D — Scenario and Test Coverage

- For each acceptance scenario and edge case in `spec.md`, check for a
  corresponding test, guard clause, or error-handling code path.
- Flag if no test files at all are found in REVIEW_FILES.

#### E — Spec Intent Alignment

- Spot-check acceptance criteria against actual behavior in REVIEW_FILES.
- Flag divergences between spec intent and implementation.
- Skip business/UX metrics that require post-deployment measurement.

#### F — Constitution Alignment

- For each MUST principle in `constitution.md`, check for violations in
  REVIEW_FILES.
- Constitution conflicts are automatically **CRITICAL** — they require fixing
  the spec, plan, tasks, or code, not reinterpreting the principle.

#### G — Design and Structure Consistency

- Verify that architectural decisions and patterns from `plan.md` are reflected
  in code.
- Compare planned project structure with actual layout.
- Flag public APIs, exports, or endpoints not described in `plan.md`.
- Flag naming, module, or error-handling conventions that deviate from the
  existing codebase patterns.

### 5. Severity Assignment

| Severity | Criteria |
|----------|---------|
| **CRITICAL** | Constitution MUST violation · majority of tasks incomplete · task-referenced file missing · requirement with zero implementation evidence |
| **HIGH** | Spec intent divergence · fundamental acceptance criteria mismatch · missing scenario or test coverage |
| **MEDIUM** | Design pattern drift · minor spec intent deviation |
| **LOW** | Structure deviations · naming inconsistencies · minor observations not affecting functionality |

### 6. Handle findings

Do **not** output a report. Classify and handle each finding silently:

**Classification rule — when in doubt**: if a decision affects something the user sees, experiences, or can do directly — even if it sounds technical — classify it as **Product**. Only classify as Technical if the decision is completely invisible to users and affects only internal implementation.

**Technical** — architecture, security, auth, compliance, data retention, integration patterns, infrastructure, performance, scalability, task completion, file existence, constitution alignment, design consistency:
1. Resolve autonomously using project context, existing code, and industry standards. If the gap is in the code, fix it. If the gap is in the spec/plan, invoke `/product-flow:speckit.reconcile`.
2. Post a PR comment via `/product-flow:pr-comments write` with `type: technical`, `status: ANSWERED`, documenting the finding, resolution path, and reasoning. If unresolvable, use `status: UNANSWERED`.

**Product** — business intent, functional scope, user flows, priorities, terminology, acceptance criteria:
1. Use the `AskUserQuestion` tool to ask the user. Be concise — one question at a time.
2. Once answered, apply the resolution.
3. Post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`, recording the question and the user's answer.

If there are no findings: return silently with a PASS signal for the calling skill.
