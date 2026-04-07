---
description: "Detects phantom completions: tasks marked done with no real implementation."
user-invocable: false
context: fork
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

Supported arguments:
- Optional space/comma-separated task IDs to verify only specific tasks.
- `--scope branch|uncommitted|all` (default: `all`) to control which git changes count as evidence.

Display this advisory **immediately** before any other work:

> ⚠️ **FRESH SESSION ADVISORY**: For maximum reliability, run
> `/product-flow:speckit.verify-tasks` in a **separate** agent session from the
> one that ran `/product-flow:speckit.implement.withTDD`. The implementing
> agent's context biases it toward confirming its own work.

## Outline

**Asymmetric error model** — a false flag (flagging real work) is cheap; the
developer dismisses it in seconds. A missed phantom (marking genuine stub code
as VERIFIED) is a catastrophic failure of this tool. **When in doubt, flag.**

### 1. Setup

Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks`
from repo root and parse FEATURE_DIR. All paths must be absolute. For single
quotes in args like "I'm Groot", use escape syntax: e.g `'I'\''m Groot'`.

Verify that `FEATURE_DIR/spec.md`, `FEATURE_DIR/plan.md`, and
`FEATURE_DIR/tasks.md` all exist — if any is missing, stop with:

```
ERROR: Missing prerequisite: {file} not found.
Run the appropriate prerequisite command first.
```

### 2. Task Parsing

From `FEATURE_DIR/tasks.md`, extract all `[X]` (completed) tasks into a
**completed task list**. For each task:

- Extract task ID (first token after checkbox: `T001`, `T-003`, `1.1`, etc.).
  If no ID found, synthesize `LINE-{n}` and emit a warning.
- Extract optional markers: `[P]` (parallel), `[US1]`/`[US2]` (user story).
- Extract file paths: exact paths, backtick-wrapped paths, glob patterns,
  directory references.
- Extract code references: backtick-wrapped symbol names (function/class/type).
- Extract acceptance criteria: indented lines starting with `Given`, `When`,
  `Then`, or `-`.
- Record line number.

If `$ARGUMENTS` contains task IDs, restrict to those IDs only. Warn for any ID
not found in `tasks.md`.

If no `[X]` tasks found: output `No completed tasks found to verify.` and stop.

### 3. Diff Scope Determination

Parse `--scope` from `$ARGUMENTS` (default: `all`). Check git availability.
If git is unavailable, skip all git-dependent layers and note it in the report.

Determine the base ref by trying `origin/main`, `origin/master`, `main`,
`master` in that order. Collect changed files for the scope:

- `branch`: diff base ref to HEAD
- `uncommitted`: diff HEAD to working tree
- `all` (default): diff base ref to HEAD plus uncommitted/untracked changes

### 4. Verification Cascade

Process each completed task through all five layers before moving to the next.

#### Layer 1 — File Existence

Check whether all referenced file paths exist on disk. Expand glob patterns.
If a file is missing and git is available, check for renames.

Result: `positive` (all present) · `negative` (any missing) · `not_applicable`
(no file paths in task).

#### Layer 2 — Git Diff Cross-reference

Check whether any referenced file appears in the changed files list from step 3.

Result: `positive` (at least one changed) · `negative` (none changed) ·
`not_applicable` (no file paths) · `skipped` (git unavailable).

#### Layer 3 — Content Pattern Matching

Search referenced files for the expected symbols. Adapt by artifact type:

| Type | Strategy |
|------|----------|
| App code (`.py`, `.ts`, `.js`, `.go`, `.java`, `.rs`, etc.) | Search for definition-prefix patterns (`def`, `class`, `function`, `export`, `const`) |
| SQL (`.sql`, `.ddl`) | Search for DDL keywords + symbol name |
| Config (`.yml`, `.yaml`, `.toml`, `.json`) | Plain text match |
| Shell (`.sh`) | Function/variable declaration patterns |
| Markdown (`.md`) | Heading pattern match |
| CI/CD (`Dockerfile`, `Makefile`, `.github/` YAML) | Plain text match |

Only search files confirmed present by Layer 1. For unlisted types, fall back
to **word-boundary plain text match** (require the symbol to appear as a whole word, not as a substring of another identifier). For example, search for `\bsymbolName\b` rather than a bare string match to avoid false positives from comments, partial matches, or unrelated identifiers.

Result: `positive` (all symbols found) · `negative` (some missing) ·
`not_applicable` (no code references in task).

#### Layer 4 — Dead-Code Detection

Skip (`not_applicable`) for artifacts consumed by runtime/tooling: SQL
migrations, config files, CI/CD, shell scripts, prompts, static assets, test
files. Apply only to application code symbols.

For each symbol found in Layer 3:
1. Find the project root (directory with `package.json`, `go.mod`,
   `pyproject.toml`, `Cargo.toml`, etc.). Fall back to repo root.
2. Search for references in source code files under that scope, **excluding the
   definition site**. Use `grep -rn` (not `git grep` — untracked files must be
   included).
3. Discard matches inside comments or string literals (unless it is a dynamic
   import).
4. Same-file references outside the definition site count as wired.

If references exist → symbol is wired (`positive`).
If none → dead code (`negative`); record `"{symbol}" declared in {file} but
never imported/called/referenced`.

Result: `positive` · `negative` · `not_applicable`.

#### Layer 5 — Semantic Assessment

Run only when no mechanical layer (1–4) returned `negative` — i.e., the task
would otherwise be VERIFIED or SKIPPED.

Read the referenced files and `FEATURE_DIR/spec.md`. Evaluate whether the
described behavior is genuinely implemented — not just structurally present
(stub functions, empty bodies, placeholder returns, TODO comments).

Label all findings as interpretive: `⚠️ Interpretive: {explanation}`.

**Downgrade rule**: a high-confidence semantic `negative` downgrades a
mechanically-verified task to `PARTIAL`. Must cite specific evidence (e.g.,
empty function body, `pass`/`TODO`/`NotImplementedError`, hardcoded return).

Result: `positive` · `negative` · `not_applicable`.

#### Verdict Assignment

| Verdict | Criteria |
|---------|---------|
| `✅ VERIFIED` | All applicable mechanical layers positive AND Layer 5 positive or not_applicable |
| `🔍 PARTIAL` | At least one mechanical layer positive AND at least one negative from any layer (including semantic downgrade) |
| `⚠️ WEAK` | Only semantic layer positive; all mechanical layers not_applicable or skipped |
| `❌ NOT_FOUND` | No layer returns positive |
| `⏭️ SKIPPED` | All layers not_applicable — no verifiable indicators |

Rules:
- `not_applicable` and `skipped` layers do **not** count against `VERIFIED`.
- `SKIPPED` tasks are not failures — they are behavior-only tasks with no
  mechanical indicators to check.

### 5. Report

Write `FEATURE_DIR/verify-tasks-report.md` (overwrite if exists). Include:

- Header with date, scope, task count, and the fresh session advisory.
- Summary scorecard (verdict counts by category).
- Flagged items section (NOT_FOUND → PARTIAL → WEAK) with per-layer detail.
- Verified items table.
- Unassessable items table (SKIPPED).
- Machine-parseable verdict line per task:
  `| {TASK_ID} | {EMOJI} {VERDICT} | {summary} |`

Output: `✅ Report written to: {FEATURE_DIR}/verify-tasks-report.md`

### 6. Interactive Walkthrough (multi-turn)

Present flagged items one at a time in severity order (NOT_FOUND first, then
PARTIAL, then WEAK).

If no flagged items: output `✅ No flagged items — verification complete.` and stop.

**For each flagged item, output exactly one item then STOP.** Do not display
the next item until the user has replied. Template:

```
### Flagged Item {i} of {total}: {TASK_ID} — {VERDICT_EMOJI} {VERDICT}

**Task**: {task description}
**Evidence gap**: {what was missing or failed}

**Actions**: **I** — investigate · **F** — propose fix · **S** — skip · **done** — end walkthrough

Awaiting your choice:
```

After printing the block above, **end your response immediately** and wait for
user input. This is a hard stop.

When the user replies:
- **I**: Investigate the gap in detail (read files, check imports), then
  re-display the action prompt for this item and STOP again.
- **F**: Propose a fix (do not apply without explicit confirmation), then
  re-display the action prompt and STOP again.
- **S**: Log as skipped, display the next flagged item and STOP again.
- **done** / **stop** / **exit**: End the walkthrough early.

After the last item (or early exit):
`✅ Walkthrough complete. {n} of {total} flagged items addressed.`

Append a `## Walkthrough Log` section to the report with the disposition of
each flagged item. Do not modify the original verdict table — it is the audit
record.

If fixes were applied, suggest re-running `/product-flow:speckit.verify-tasks`
for a clean re-evaluation.

### 7. Record verification summary in the PR

Invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `ANSWERED`
- `body`:
  ```
  **verify-tasks completed**

  **Scope:** [branch / uncommitted / all]
  **Tasks verified:** [N total — X ✅ VERIFIED · Y 🔍 PARTIAL · Z ❌ NOT_FOUND · W ⏭️ SKIPPED]

  **Walkthrough outcome:** [e.g. "2 flagged items — 1 fixed, 1 skipped" or "No flagged items"]

  Report: specs/<branch>/verify-tasks-report.md
  ```

Skip this step if the skill was stopped before completing the walkthrough (e.g. user typed `done` early and no items were addressed).
