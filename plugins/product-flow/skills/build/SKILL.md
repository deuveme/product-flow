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

### 2. Gate: ready to build

Read `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null || echo "{}"
```

Check in order — stop at the first failing condition:

1. `TASKS_GENERATED` is present OR `specs/<branch>/tasks.md` exists on disk. If not:
   ```
   🚫 The tasks have not been generated yet.

   Run /product-flow:continue to generate the tasks first.
   ```
   **STOP.**

2. `CHECKLIST_DONE` is present in `status.json`. If not:
   ```
   🚫 The checklists have not been completed yet.

   Run /product-flow:continue to complete the checklist validation first.
   ```
   **STOP.**

### 2b. Pre-build comment review

This step runs only if the entry point is **Normal flow** (no prior progress detected). Skip if re-entering mid-build (`CODE_WRITTEN` already set).

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

- Code written? → `CODE_WRITTEN` is set in `status.json`
- Code verified? → `CODE_VERIFIED` is set in `status.json`
- Verify-tasks done? → `specs/<feature-dir>/verify-tasks-report.md` exists

Also check for uncommitted changes:

```bash
git status --porcelain
```

Determine entry point using these mutually exclusive cases (check in order):

1. **All done** — `CODE_VERIFIED` is set in `status.json` AND `verify-tasks-report.md` exists: skip all work and go directly to the final report.

2. **Re-entry shortcut** — `CODE_WRITTEN` is set in `status.json` AND `CODE_VERIFIED` is NOT set AND `verify-tasks-report.md` does NOT exist: a previous build session was interrupted after implement but before verify-tasks completed. **Skip directly to step 4b** without re-running implement.

2.5. **Partial implementation** — `CODE_WRITTEN` is NOT set in `status.json` AND uncommitted changes exist in files **outside** `specs/` (i.e., source code or test files): this is a previous interrupted implementation run.

To detect this, run:
```bash
git status --porcelain | grep -v "^.. specs/"
```
If the output is non-empty, this case applies. Show:

Use the `AskUserQuestion` tool to ask:
```
⚠️  Uncommitted code detected from a previous interrupted run.

  A. Save these changes and mark the code as generated
     (use this if the implementation looks complete or you want to keep the work)
  B. Discard all changes and restart the implementation from scratch
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

  Then write `CODE_WRITTEN` to `status.json`:
  ```bash
  BRANCH=$(git branch --show-current)
  STATUS_FILE="specs/$BRANCH/status.json"
  EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
  echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"CODE_WRITTEN": $ts}' > "$STATUS_FILE"
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

2.6. **Failed artifact commit** — code is NOT marked as generated (no `CODE_WRITTEN`) AND uncommitted changes exist **only** inside `specs/` (tasks, checklists, or other spec artifacts whose commit was interrupted, e.g. due to GPG): commit the artifacts and continue normally.

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

Skip this step if `CODE_WRITTEN` is already set in `status.json`.

Otherwise, show:
```
⏳ Generating feature code... (this may take several minutes)
```

Invoke `/product-flow:implement`.

**Wait for `/product-flow:implement` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

Show:
```
⚙️ Code generated. Checking that all tasks are complete...
```

Invoke `/product-flow:speckit.verify-tasks`.

**Wait for `speckit.verify-tasks` to finish before continuing.**

- If it flags **NOT_FOUND** or **PARTIAL** tasks: surface the interactive
  walkthrough and wait for the user to resolve each item.
- When the walkthrough finishes (or if no items are flagged): continue to
  step 5.

### 4b. Verify-tasks (re-entry)

**Entry condition** (must match exactly — both required):
- `CODE_WRITTEN` is set in `status.json` AND `CODE_VERIFIED` is NOT set, AND
- `verify-tasks-report.md` does NOT exist in FEATURE_DIR

This step runs only when the re-entry shortcut was triggered in step 3:
code is already generated AND `verify-tasks-report.md` does NOT exist.

Show:
```
🔍 Checking that all tasks are complete...
```

Invoke `/product-flow:speckit.verify-tasks`.

**Wait for `speckit.verify-tasks` to finish before continuing.**

- If it flags **NOT_FOUND** or **PARTIAL** tasks: surface the interactive
  walkthrough and wait for the user to resolve each item.
- When the walkthrough finishes (or if no items are flagged): continue to
  step 5.

### 5. Verification gate

Show:
```
🔍 Verifying implementation against spec, plan and tasks...
```

Invoke `/product-flow:speckit.verify`.

**Wait for `speckit.verify` to finish before continuing.**

- If it reports **CRITICAL** issues → Do not proceed. Show:
  ```
  ⚠️ Found some issues — resolving them...
  ```
  Then classify and handle each issue autonomously:

  **Technical** — architecture, security, auth, compliance, data retention, integration patterns, infrastructure, performance, scalability:
  1. Analyze whether the gap is in the **code** (incomplete or incorrect implementation) or in the **spec/plan** (artifacts out of sync with a correct implementation).
  2. If the code needs fixing: apply the fix directly.
  3. If the spec/plan need updating: invoke `/product-flow:speckit.reconcile` with a description of the gap. After it finishes, re-run `/product-flow:speckit.verify`. If CRITICAL issues remain, repeat this process. If it passes, continue to step 5b.
  4. Post a PR comment via `/product-flow:pr-comments write` with `type: technical`, `status: ANSWERED`, documenting the issue, the chosen resolution path, and the reasoning.

  **Product** — business intent, functional scope, user flows, priorities, terminology, acceptance criteria:
  1. Use the `AskUserQuestion` tool to ask the user. Be concise — one question at a time.
  2. Once answered, apply the resolution (fix code or invoke `/product-flow:speckit.reconcile` as appropriate).
  3. Post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`, recording the question and the user's answer.

  After resolving all CRITICAL issues, show:
  ```
  🔍 Re-verifying after fixes...
  ```
  Re-run `/product-flow:speckit.verify`. If it passes, show:
  ```
  ✅ All issues resolved — continuing.
  ```
  Then continue to step 5b. If new CRITICAL issues appear, repeat this block.

- If it reports only **HIGH / MEDIUM / LOW** issues → Show:
  ```
  ⚠️ Found some issues — resolving them...
  ```
  Then classify each issue before acting:

  **Technical** — architecture, security, auth, compliance, data retention, integration patterns, infrastructure, performance, scalability:
  1. Attempt to resolve it autonomously using project context and industry standards.
  2. Invoke `/product-flow:pr-comments write`:
     - If resolved: `type: technical`, `status: ANSWERED`, body:
       ```
       **Technical question detected:** "[identified issue]"

       **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

       **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
       ```
     - If unresolved: `type: technical`, `status: UNANSWERED`, body:
       ```
       **Technical question detected:** "[identified issue]"

       **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

       ⚠️ **Unresolved — requires input from the development team.**
       ```

  **Product** — business intent, functional scope, user flows, priorities, terminology, acceptance criteria:
  1. Use the `AskUserQuestion` tool to ask the user. Be concise — one question at a time.
  2. Once answered, invoke `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`, recording the question and the user's answer.

  After handling all issues, show:
  ```
  ✅ All issues resolved — continuing.
  ```
  Then continue to step 5b.

- If it reports **no issues** → Show:
  ```
  ✅ No issues found — everything looks correct.
  ```
  Then continue to step 5b.

### 5b. Mark code as verified

Runs after the verification gate passes (step 5).

Write `CODE_VERIFIED` to `specs/<branch>/status.json` and update the PR body:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"CODE_VERIFIED": $ts}' > "$STATUS_FILE"
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
- Add row to `## History`: `| Code generated | YYYY-MM-DD | verify-tasks and verify passed |`
- Replace the `- [ ] **Implementation** — pending` line inside `<!-- dev-checklist -->` with `- [x] **Implementation** — complete`

```bash
gh pr edit --body "<updated-body>"
```

Show:
```
🔒 Code verified. Run /product-flow:submit to send for review.
```

### 6. Final report

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
