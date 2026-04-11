---
description: "STEP 3 — Generates the feature code. Run when the tasks are ready."
model: sonnet
effort: medium
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "There is no active feature. Use /product-flow:start to start a new one."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 1b. Inbox

Invoke `/product-flow:inbox-sync`.

### 2. Gate: tasks generated

Read `specs/<branch>/status.json` and verify that `tasks_generated` is present, or that `specs/<branch>/tasks.md` exists on disk:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null | jq -e '.tasks_generated' > /dev/null || ls "specs/$BRANCH/tasks.md" > /dev/null 2>&1
```

If neither condition is met:

```
🚫 The tasks have not been generated yet.

Run /product-flow:continue to generate the tasks first.
```

**STOP.**

### 2b. Pre-build comment review

This step runs only if the entry point is **Normal flow** (no prior progress detected). Skip if re-entering mid-build (`code_written` already set).

Reminder to review AI-answered comments:

```
💬 Last chance to review decisions before code is written.
   · Technical decisions: answered autonomously by the AI on your behalf.
   · Product decisions: taken together with you during spec and planning.
   If anything looks wrong, stop now and reply with: Question <N>. Answer: [your preference]
   Link: <PR_URL>

Proceeding... (run /product-flow:continue to make changes instead)
```

### 3. Detect progress and decide entry point

First, verify the feature directory exists:

```bash
ls specs/<feature-dir>/ 2>/dev/null
```

If the directory does not exist: ERROR "No feature directory found at specs/<feature-dir>/. Did you run /product-flow:start to initialize this feature?"

**STOP.**

Then read `specs/<branch>/status.json` and the feature directory:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null || echo "{}"
```

- Code written? → `code_written` is set in `status.json`
- Code verified? → `code_verified` is set in `status.json`
- Verify-tasks done? → `specs/<feature-dir>/verify-tasks-report.md` exists

Also check for uncommitted changes:

```bash
git status --porcelain
```

Determine entry point using these mutually exclusive cases (check in order):

1. **All done** — `code_verified` is set in `status.json` AND `verify-tasks-report.md` exists: skip all work and go directly to the final report.

2. **Re-entry shortcut** — `code_written` is set in `status.json` AND `code_verified` is NOT set AND `verify-tasks-report.md` does NOT exist: the user chose option B ("open a new session") from the verify-tasks proposal. **Skip directly to step 4b** without re-running implement.

2.5. **Partial implementation** — `code_written` is NOT set in `status.json` AND uncommitted changes exist in files **outside** `specs/` (i.e., source code or test files): this is a previous interrupted implementation run.

To detect this, run:
```bash
git status --porcelain | grep -v "^.. specs/"
```
If the output is non-empty, this case applies. Show:

```
⚠️  Uncommitted code detected from a previous interrupted run.

  A. Save these changes and mark the code as generated
     (use this if the implementation looks complete or you want to keep the work)
  B. Discard all changes and restart the implementation from scratch

Your choice:
```

- **A** → run:
  ```bash
  git add -A
  git commit -m "feat(<branch-name>): generate feature code"
  ```
  If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
  ```
  🚫 Commit failed — GPG signing is blocking automatic commits.

  To fix it, run in your terminal:
    git config commit.gpgsign false

  Then run /product-flow:build again.
  ```
  **STOP.**

  Then write `code_written` to `status.json`:
  ```bash
  BRANCH=$(git branch --show-current)
  STATUS_FILE="specs/$BRANCH/status.json"
  EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
  echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"code_written": $ts}' > "$STATUS_FILE"
  git add "$STATUS_FILE"
  git commit -m "chore: record code_written in status.json"
  git push origin HEAD
  ```
  If this commit also fails with a GPG error: same fix as above. **STOP.**

  Add a History row `| Code written | YYYY-MM-DD HH:MM:SS | @github-user | recovered from interrupted run |` to the PR body. Skip directly to step 4b.

- **B** → run:
  first show the exact files that will be deleted or reset:
  ```bash
  git status --short
  ```
  Then ask for explicit confirmation:
  ```
  ⚠️  This will permanently discard all local changes listed above.
  Type exactly: CONFIRM DELETE
  ```
  - If the response is not exactly `CONFIRM DELETE`: show `Aborted — no files were deleted.` and **STOP**.
  - If the response is exactly `CONFIRM DELETE`, run:
    ```bash
    git checkout -- .
    git clean -fd
    ```
    Then continue with Normal flow (step 6).

2.6. **Failed artifact commit** — code is NOT marked as generated AND uncommitted changes exist **only** inside `specs/` (tasks, checklists, or other spec artifacts whose commit was interrupted, e.g. due to GPG): commit the artifacts and continue normally.

To confirm this is the case, verify that:
```bash
git status --porcelain | grep -v "^.. specs/"
```
produces **no output** (all changes are under `specs/`).

Run:
```bash
git add specs/
git commit -m "docs: recover uncommitted spec artifacts"
git push origin HEAD
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:build again.
```
**STOP.**

Then re-read `specs/<branch>/status.json` and continue with the appropriate remaining step based on what fields are not yet set.

3. **Normal flow** — code is NOT yet generated (and no uncommitted changes): show:

```
📍 Current status: Tasks and requirements validated · Ready to build

🔜 Generating the feature code...

This may take several minutes.

Starting...
```

If all steps (including verify-tasks) are already done, skip to the final report.

### 4. Implement

Skip this step if `code_written` is already set in `status.json`.

Otherwise, show:
```
⏳ Generating feature code... (this may take several minutes)
```

Invoke `/product-flow:implement`.

**Wait for `/product-flow:implement` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 4b. Verify-tasks (re-entry from new session)

**Entry condition** (must match exactly — both required):
- `code_written` is set in `status.json` AND `code_verified` is NOT set, AND
- `verify-tasks-report.md` does NOT exist in FEATURE_DIR

This step runs only when the re-entry shortcut was triggered in step 3:
code is already generated AND `verify-tasks-report.md` does NOT exist.

The user opened a new session specifically to run verify-tasks with a clean
context — execute it directly without re-proposing.

Invoke `/product-flow:speckit.verify-tasks`.

**Wait for `speckit.verify-tasks` to finish before continuing.**

- If it flags **NOT_FOUND** or **PARTIAL** tasks: surface the interactive
  walkthrough and wait for the user to resolve each item.
- When the walkthrough finishes (or if no items are flagged): continue to
  step 5.

### 4c. Mark code as verified

Runs after step 4 or step 4b completes successfully (verify-tasks passed or no flagged items).

Write `code_verified` to `specs/<branch>/status.json` and check `- [x] Code generated` in the PR body:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"code_verified": $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record code_verified in status.json"
git push origin HEAD
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:build again.
```
**STOP.**

Read the current PR body first (`gh pr view --json body -q '.body'`), then apply these changes — preserve all other sections intact:
- Mark `- [x] Code generated` in `## Status`
- Add row to `## History`: `| Code generated | YYYY-MM-DD | verify-tasks passed |`
- Replace the `- [ ] **Implementation** — pending` line inside `<!-- dev-checklist -->` with `- [x] **Implementation** — complete`

```bash
gh pr edit --body "<updated-body>"
```

### 5. Final report

```
✅ Feature built

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /product-flow:submit

It will save the code and leave it ready
for the development team's review.
─────────────────────────────────────────
```

### Session close

Invoke `/product-flow:context`.
