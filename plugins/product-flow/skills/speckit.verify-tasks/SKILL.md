---
description: "Detects phantom completions: tasks marked done with no real implementation."
user-invocable: false
context: fork
model: sonnet
effort: medium
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

Supported arguments:
- Optional space/comma-separated task IDs to verify only specific tasks.
- `--scope branch|uncommitted|all` (default: `all`) to control which git changes count as evidence.

## Outline

**Asymmetric error model** — a false flag (flagging real work) is cheap; the
developer dismisses it in seconds. A missed phantom (marking genuine stub code
as VERIFIED) is a catastrophic failure of this tool. **When in doubt, flag.**

### 1. Setup

Resolve feature paths and validate prerequisites:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
CURRENT_BRANCH="${SPECIFY_FEATURE:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
```

If `CURRENT_BRANCH` does not match `^[0-9]{3}-`: ERROR "Not on a feature branch. Run /product-flow:start-feature or /product-flow:start-improvement first." and stop.

Derive `FEATURE_DIR` = `$REPO_ROOT/specs/$CURRENT_BRANCH`.

Verify that `FEATURE_DIR/spec.md`, `FEATURE_DIR/plan.md`, and `FEATURE_DIR/tasks.md` all exist — if any is missing, stop with:

```
ERROR: Missing prerequisite: {file} not found.
Run the appropriate prerequisite command first.
```

Build `AVAILABLE_DOCS` list:
- `research.md` if it exists
- `data-model.md` if it exists
- `contracts/` if the directory exists and is non-empty
- `quickstart.md` if it exists
- `tasks.md` (always included when it exists)

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

Write `VERIFY_TASKS_DONE` to `status.json` — no commit needed here, `build` will include it when committing `CODE_VERIFIED`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"VERIFY_TASKS_DONE": $ts}' > "$STATUS_FILE"
```

### 6. Handle flagged items

If no flagged items:
```
✅ All tasks verified.
```
Continue silently.

Show:
```
⚠️ Found some incomplete tasks — resolving them...
```

For each flagged item, classify and handle it without showing technical details to the user:

**Technical** — missing implementation, incomplete code, phantom completions, file structure issues:
1. Investigate the gap in detail (read files, check imports, verify actual implementation).
2. Apply a fix directly if possible.
3. Post a PR comment via `/product-flow:pr-comments write` with `type: technical`, `status: ANSWERED`, documenting the task, the gap found, and how it was resolved. If unresolvable, use `status: UNANSWERED`.

**Product** — unclear acceptance criteria, missing business logic, ambiguous functional scope:
1. Use the `AskUserQuestion` tool to ask the user. Be concise — one question at a time.
2. Once answered, apply the resolution.
3. Post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`, recording the question and the user's answer.

After handling all flagged items, show:
```
✅ All tasks resolved — continuing.
```

Append a `## Resolution Log` section to the report with the disposition of each item.

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
