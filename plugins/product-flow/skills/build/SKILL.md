---
description: "STEP 3 — Generates the feature code. Run when the plan is ready."
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

Show: `📬 Checking for new activity...`

**Part A — Answers to bot questions:**

Invoke `/product-flow:pr-comments read-answers`. For each new answer found:

1. Evaluate whether the answer is actionable as-is:
   - **Clear**: apply directly.
   - **Ambiguous or incomplete**: clarify before applying:
     - If the question was `type: technical`: resolve the ambiguity autonomously using project context. Do not ask the PM.
     - If the question was `type: product`: use **AskUserQuestion** (one entry for this question only) to ask the PM for clarification before applying.

2. Show before applying:
   ```
     ⏳ Question <N> — <one-line summary> → applying to <artifact>...
   ```
   Apply, then show:
   ```
     ✅ Question <N> — applied.
   ```

Invoke `/product-flow:pr-comments mark-processed` with the question numbers of all applied answers.

**Part B — New user comments:**

Invoke `/product-flow:pr-comments new-comments`. If `NO_NEW_COMMENTS`: continue silently.

For each new comment, classify it first using these rules:

- **Technical**: architecture, security, performance, data model, infrastructure, integration patterns.
- **Product**: business intent, scope, user flow, acceptance criteria, terminology.
- **Ambiguous type**: if the comment could be either — default to **product** and ask the PM. Never resolve autonomously when classification is uncertain.
- **Incomprehensible**: if the comment has no discernible actionable intent (e.g. `"???"`, stray emoji, link without context, unrelated text) — do not apply any change. Invoke `/product-flow:pr-comments write` with `type: product`, `status: UNANSWERED`, body:
  ```
  **Unrecognised comment:** "[original comment text]"

  ⚠️ This comment could not be interpreted. Please clarify what change (if any) you'd like.
  ```
  Skip to the next comment.

Then act on the classified comment:

- **Technical**: resolve autonomously using project context. Invoke `/product-flow:pr-comments write` with `type: technical`, `status: ANSWERED` (or `UNANSWERED` if unresolvable). Apply the decision to the relevant artifact.
- **Product** (including ambiguous type): use **AskUserQuestion** (single call, one entry per comment). After receiving the PM's answers, apply changes to the relevant artifact. Invoke `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`.

After processing all new comments, invoke `/product-flow:pr-comments mark-comments-processed` with the IDs of all processed comments.

Show: `✅ Inbox processed — <N> answer(s) applied, <M> comment(s) evaluated.`
(or `✅ Inbox clear.` if nothing to process)

### 2. Gate: plan generated

Read `specs/<branch>/status.json` and verify that `plan_generated` is present:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null | jq -e '.plan_generated' > /dev/null
```

If not marked:

```
🚫 The plan has not been generated yet.

Run /product-flow:continue to generate the plan first.
```

**STOP.**

### 2b. Pre-build comment review

This step runs only if the entry point is **Normal flow** (no prior progress detected). Skip if re-entering mid-build (`code_written` already set).

**1. Resolve unanswered comments:**

Invoke `/product-flow:pr-comments pending`. For each UNANSWERED comment:

- `type: technical`: attempt autonomous resolution using project context and industry standards. Invoke `/product-flow:pr-comments write` with `status: ANSWERED` and mark resolved via `/product-flow:pr-comments resolve`.
- `type: product`: use **AskUserQuestion** to ask the PM in a single call (one entry per comment). After receiving the PM's answers, post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`.

Only after all comments are resolved, continue.

**2. Check for unprocessed user answers:**

Invoke `/product-flow:pr-comments read-answers`. Show: `📬 Reading PR answers...`

For each new answer found, show before applying:
```
  ⏳ Question <N> — <one-line summary> → applying to <artifact>...
```
Apply it, then show:
```
  ✅ Question <N> — applied.
```

After all answers are processed, show: `✅ <N> answer(s) applied.` (or `No new answers found.` if none).

Invoke `/product-flow:pr-comments mark-processed` with the question numbers of all applied answers (e.g. `1 3`).

**3. Reminder to review AI-answered comments:**

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

- Tasks done? → `tasks_generated` is set in `status.json` OR `specs/<feature-dir>/tasks.md` exists on disk
- Checklist done? → `checklist_done` is set in `status.json` OR `specs/<feature-dir>/checklists/` exists with at least one file
- Code written? → `code_written` is set in `status.json`
- Code verified? → `code_verified` is set in `status.json`
- Verify-tasks done? → `specs/<feature-dir>/verify-tasks-report.md` exists

Also check for uncommitted changes:

```bash
git status --porcelain
```

Determine entry point using these mutually exclusive cases (check in order):

1. **All done** — `code_verified` is set in `status.json` AND `verify-tasks-report.md` exists: skip all work and go directly to the final report.

2. **Re-entry shortcut** — `code_written` is set in `status.json` AND `code_verified` is NOT set AND `verify-tasks-report.md` does NOT exist: the user chose option B ("open a new session") from the verify-tasks proposal. **Skip directly to step 6b** without re-running tasks, checklist, or implement.

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

  Add a History row `| Code written | YYYY-MM-DD | recovered from interrupted run |` to the PR body. Skip directly to step 6b.

- **B** → run:
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

Then re-read `specs/<branch>/status.json` and continue with the appropriate remaining step (step 4, 5, or 6) based on what fields are not yet set.

3. **Normal flow** — code is NOT yet generated (and no uncommitted changes): build the pending steps list based on what is NOT yet done and show:

```
📍 Current status: Plan generated · Ready to build

🔜 I'm going to:
   [only list pending steps, e.g.:]
   1. Break down the plan into development tasks   ← skip if already done
   2. Validate requirements quality                ← skip if already done
   3. Generate the feature code                    ← skip if already done

This may take several minutes.

Starting...
```

If all steps (including verify-tasks) are already done, skip to the final report.

### 4. Generate tasks

Skip this step if `tasks_generated` is already set in `status.json` OR if `specs/<feature-dir>/tasks.md` already exists on disk.

Otherwise, show:
```
⏳ Step 1/3 — Breaking down the plan into tasks...
```

Invoke `/product-flow:tasks`.

**Wait for `/product-flow:tasks` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

Then show:
```
✅ Step 1/3 — Tasks ready.
```

### 5. Validate requirements quality

Skip this step if `checklist_done` is set in `status.json` OR if `specs/<feature-dir>/checklists/` already exists and contains at least one file other than `requirements.md`.

Otherwise, show:
```
⏳ Step 2/3 — Validating requirements quality...
```

Invoke `/product-flow:checklist`.

**Wait for `/product-flow:checklist` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

If the checklist reveals CRITICAL issues (gaps, conflicts, or ambiguities that would break implementation):

For each critical issue, classify and resolve:

- **Technical** (architecture, performance, security, data model, infrastructure): resolve autonomously using available context. Invoke `/product-flow:pr-comments write` with:
  - `type`: `technical`, `status`: `ANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
    ```
- **Product** (scope, user flow, acceptance criteria, business rules): use **AskUserQuestion** to ask the PM (single call, one entry per issue). After receiving answers, invoke `/product-flow:pr-comments write` with:
  - `type`: `product`, `status`: `ANSWERED`
  - `body`:
    ```
    **Checklist issue:** "[the gap or ambiguity found]"

    **Options:** A. "[option A]" B. "[option B]" (... etc)

    **PM answer:** "[the answer received]"

    **Change applied:** [what was updated, or "no change — decision recorded"]
    ```

After all critical issues are resolved via the decision flow, write `checklist_done` to `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"checklist_done": $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record checklist_done in status.json"
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

Show `✅ Step 2/3 — Requirements validated.` and continue to step 6.

The only case that warrants a **STOP** is if the PM explicitly answers "Other" with a response requiring follow-up before building. In that case, state clearly what is needed and stop.

### 6. Implement

Skip this step if `code_written` is already set in `status.json`.

Otherwise, show:
```
⏳ Step 3/3 — Generating feature code... (this may take several minutes)
```

Invoke `/product-flow:implement`.

**Wait for `/product-flow:implement` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 6b. Verify-tasks (re-entry from new session)

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
  step 7.

### 6c. Mark code as verified

Runs after step 6 or step 6b completes successfully (verify-tasks passed or no flagged items).

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

Mark `- [x] Code generated` in the PR body and add a History row:

```
| Code generated | YYYY-MM-DD | verify-tasks passed |
```

```bash
gh pr edit --body "<updated-body>"
```

### 7. Final report

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
