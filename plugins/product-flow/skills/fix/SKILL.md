---
description: "STEP 3b — Fix cycle after a review finds issues. Runs TDD on targeted fix-tasks and re-verifies. Callable after build or submit."
user-invocable: true
model: sonnet
effort: high
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "There is no active feature. Use /product-flow:start to start a new one."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

Read and extract flags from `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")

PUBLISHED=$(echo "$STATUS"     | jq -r '.PUBLISHED     // empty')
IN_REVIEW=$(echo "$STATUS"     | jq -r '.IN_REVIEW     // empty')
CODE_VERIFIED=$(echo "$STATUS" | jq -r '.CODE_VERIFIED // empty')
CODE_WRITTEN=$(echo "$STATUS"  | jq -r '.CODE_WRITTEN  // empty')

FIX_TASKS=$(grep -c "FIX-" "specs/$BRANCH/tasks.md" 2>/dev/null || echo "0")
```

Check in order — stop at the first matching condition:

- `$PUBLISHED` is non-empty → ERROR:
  ```
  🚫 This feature is already published. /product-flow:fix cannot run after deploy.
  ```
- `$IN_REVIEW` is non-empty → valid. Continue.
- `$CODE_VERIFIED` is non-empty → valid. Continue.
- `$FIX_TASKS > 0` → a previous fix cycle was interrupted before completing. Valid. Continue.
- `$CODE_WRITTEN` is non-empty → ERROR:
  ```
  🚫 The code has not been verified yet. Run /product-flow:build to complete verification first.
  ```
- All empty → ERROR:
  ```
  🚫 /product-flow:fix can only run after the code has been built and verified.

  Current workflow position does not allow fix.
  Run /product-flow:status to see where you are and what to do next.
  ```

---

### 2. Check for pending fixes

Scan `specs/<branch>/fixes/` for any `fix-N.md` files where `## Result` contains `_Pending`:

```bash
BRANCH=$(git branch --show-current)
for f in "specs/$BRANCH/fixes/fix-"*.md 2>/dev/null; do
  [ -f "$f" ] && grep -q "_Pending" "$f" && echo "$f"
done
```

For each pending fix found, also read its progress from `tasks.md`:

```bash
FIX_N=$(basename "$f" .md | sed 's/fix-//')
TOTAL=$(grep -c "FIX-${FIX_N}-" "specs/$BRANCH/tasks.md" 2>/dev/null || echo "0")
DONE=$(grep "FIX-${FIX_N}-" "specs/$BRANCH/tasks.md" 2>/dev/null | grep -c "\[X\]\|\[x\]" || echo "0")
```

**If no pending fixes found:**

Use `AskUserQuestion` to ask:
```
No pending fixes found. Do you have a new issue to fix?
```
- Yes → proceed to step 3 (new fix).
- No → proceed to step 7 (done).

**If pending fixes found:**

Use `AskUserQuestion` to show the list and ask what to do:

```
⚠️  Found [N] pending fix(es):

  [1] fix-1 — "[symptom first line]"
      Tasks: [DONE]/[TOTAL] complete
  [2] fix-2 — "[symptom first line]"
      Tasks: [DONE]/[TOTAL] complete

What would you like to do?
  · Type the number to continue that fix (e.g. "1")
  · Type "delete [number]" to discard a fix (e.g. "delete 1")
  · Type "new" to start a fresh fix
```

Handle the response:

- **Number (e.g. "1")** → load the selected fix-N.md. Proceed to step 3 in **resume mode**.
- **"delete N"** → discard that fix:
  1. Remove `specs/<branch>/fixes/fix-N.md`.
  2. Remove all lines containing `FIX-N-` from `specs/<branch>/tasks.md`, including the section header `## Fix tasks — Fix N` and its separator.
  3. Restore verification state if needed:
     - If `CODE_VERIFIED` is **present**: nothing to restore — the fix was interrupted before step 5a cleared it. Skip to step 4.
     - If `CODE_VERIFIED` is **absent**: the fix had already cleared it. Run `/product-flow:speckit.verify` to re-validate the current code state.
       - If verify **passes**: write `CODE_VERIFIED` and `VERIFY_TASKS_DONE` back to `status.json`:
         ```bash
         EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
         echo "$EXISTING" | jq \
           --arg ts1 "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
           --arg ts2 "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
           '. + {"VERIFY_TASKS_DONE": $ts1, "CODE_VERIFIED": $ts2}' > "$STATUS_FILE"
         ```
       - If verify **fails**: show the issues and ask the user whether to fix them (start a new fix) or proceed without restoring CODE_VERIFIED.
  4. Commit: `git add -A && git commit -m "chore: discard fix-N" && git push origin HEAD`.
  5. **Loop back to step 2.**
- **"new"** → proceed to step 3 in **new fix mode**.

---

### 3. Start or resume

**New fix mode:**

Run inbox to surface any unprocessed PR comments before starting:

Invoke `/product-flow:inbox-sync`.

Then:
```bash
/product-flow:pr-comments new-comments
```

If unprocessed comments are found, show them as context:
```
💬 Feedback found on the PR:

[author] — [comment body]
...
```

Proceed to step 4 (diagnosis).

---

**Resume mode** (continuing an interrupted fix-N):

Read `specs/<branch>/fixes/fix-N.md` for full context (symptom, location, error type, fix-tasks).

Read task state from `tasks.md`:

```bash
BRANCH=$(git branch --show-current)
FIX_N=<selected N>
TOTAL=$(grep -c "FIX-${FIX_N}-" "specs/$BRANCH/tasks.md" 2>/dev/null || echo "0")
DONE=$(grep "FIX-${FIX_N}-" "specs/$BRANCH/tasks.md" 2>/dev/null | grep -c "\[X\]\|\[x\]" || echo "0")
VERIFY_TASKS_DONE=$(echo "$STATUS" | jq -r '.VERIFY_TASKS_DONE // empty')
```

Show:
```
⏩ Resuming fix-[N]: "[symptom first line]"
   Tasks: [DONE]/[TOTAL] complete
```

Route based on state (check in order):

| Condition | Skip to |
|---|---|
| `$VERIFY_TASKS_DONE` non-empty, `$CODE_VERIFIED` empty | Step 5e — re-establish verification state |
| `$DONE == $TOTAL` and `$TOTAL > 0` | Step 5c — re-run speckit.verify-tasks |
| `$DONE > 0` and `$DONE < $TOTAL` | Step 5b — implement remaining `[ ]` tasks |
| `$DONE == 0` and `$TOTAL > 0` | Step 5b — implement all tasks |
| `$TOTAL == 0` | Step 5a — append fix-tasks first |

Do not repeat completed steps.

---

### 4. Define

Conduct a structured diagnosis using the `AskUserQuestion` tool. Ask one question at a time. Resolve all four dimensions before proceeding to step 5.

Read `specs/<branch>/spec.md`, `specs/<branch>/plan.md`, and `specs/<branch>/tasks.md` before asking questions — use them to cross-reference every answer and formulate targeted follow-ups.

---

**Dimension 1 — Symptom**

Ask:
```
What did you find that doesn't work as expected? Describe it as freely as you like.
```

Cross-reference the response with spec.md, plan.md, and tasks.md to identify the likely location.

---

**Dimension 2 — Location in artifacts**

Confirm the mapping. Ask something like:
```
In the spec, scenario [X] describes [Y]. Is that what's failing — or is it something different?
```

Continue probing until the exact location in spec/plan/tasks is pinpointed.

---

**Dimension 3 — Error type**

Ask:
```
Was this behavior clearly described in the spec?
  A. Yes — it was clear, but the AI implemented it incorrectly.
  B. The spec was ambiguous and the AI interpreted it differently than intended.
  C. This scenario wasn't in the spec at all — it emerged during testing.
```

Record as: **Implementation** (A) / **Ambiguity** (B) / **Omission** (C).

---

**Dimension 4 — Scope**

Ask only if not already clear:
```
Is this isolated to [identified task/component], or does it affect other parts of the feature too?
```

---

Do not advance until all four dimensions are unambiguous.

**Determine fix number N:**

```bash
BRANCH=$(git branch --show-current)
ls "specs/$BRANCH/fixes/fix-"*.md 2>/dev/null | wc -l
```

N = count + 1. Fix-task IDs: `FIX-N-1`, `FIX-N-2`, etc.

**Show summary and confirm** via `AskUserQuestion`:

```
Here's what I understood. Please confirm before I proceed.

**Symptom**
[description]

**Location**
Spec: [section or scenario]
Plan: [section if relevant]
Task: [ID and title]

**Error type**
[Implementation / Ambiguity / Omission] — [one sentence explanation]

**Scope**
[Isolated / Multiple — details]

**Fix-tasks**
- FIX-N-1: [description]
  Acceptance criteria:
  · [criterion 1]
  · [criterion 2]
- FIX-N-2: [description]
  ...

Does this look correct? Should I proceed?
```

If the user requests corrections: adjust and ask again. Do not proceed until explicitly confirmed.

**Save fix record** — write `specs/<branch>/fixes/fix-N.md`:

```markdown
# Fix [N] — [YYYY-MM-DD]

## Symptom
[description]

## Location
**Spec:** [section or scenario]
**Plan:** [section, or "—" if not applicable]
**Task:** [ID and title]

## Error type
[Implementation / Ambiguity / Omission]

[One-sentence explanation]

## Scope
[Isolated / Multiple — details]

## Fix-tasks
- FIX-N-1: [description]
  Acceptance criteria:
  · [criterion 1]
  · [criterion 2]

## Result
_Pending — filled in after verification._
```

Create directory if needed: `mkdir -p "specs/$BRANCH/fixes"`

Post PR comment via `/product-flow:pr-comments write` (`type: product`, `status: ANSWERED`) with the confirmed summary.

Commit:
```bash
git add "specs/$BRANCH/fixes/fix-N.md"
git commit -m "docs: add fix-N diagnosis record"
git push origin HEAD
```

GPG error? Run `git config commit.gpgsign false` and re-run `/product-flow:fix`. **STOP.**

---

### 5. Implement

#### 5a. Reset verification state and append fix-tasks

Skip if `CODE_VERIFIED` is already absent (already cleared in a prior interrupted run).

Clear `CODE_VERIFIED` and `VERIFY_TASKS_DONE`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq 'del(.CODE_VERIFIED) | del(.VERIFY_TASKS_DONE)' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: clear verification flags for fix-N"
git push origin HEAD
```

GPG error? Same fix. **STOP.**

Append fix-tasks to `specs/<branch>/tasks.md`:

```markdown

---
## Fix tasks — Fix N ([YYYY-MM-DD])

- [ ] FIX-N-1: [description]
  Acceptance criteria:
  · [criterion 1]
  · [criterion 2]

- [ ] FIX-N-2: [description]
  ...
```

Commit:
```bash
git add "specs/$BRANCH/tasks.md"
git commit -m "docs: append fix-tasks for fix-N"
git push origin HEAD
```

GPG error? Same fix. **STOP.**

Show:
```
🔄 Verification state cleared. Starting fix cycle...
```

#### 5b. Implement fix-tasks (TDD)

Show:
```
⏳ Implementing fix-tasks with TDD... (this may take several minutes)
```

Invoke `/product-flow:speckit.implement.withTDD` with the pending fix-task IDs (space-separated). If resuming, pass only the remaining `[ ]` tasks:

```
/product-flow:speckit.implement.withTDD FIX-N-1 FIX-N-2
```

Wait for it to finish. If ERROR: propagate and stop.

#### 5c. Verify fix-tasks

Show:
```
🔍 Checking that all fix-tasks are complete...
```

Invoke `/product-flow:speckit.verify-tasks` with the fix-task IDs:

```
/product-flow:speckit.verify-tasks FIX-N-1 FIX-N-2
```

Wait for it to finish.

- If it flags **NOT_FOUND** or **PARTIAL**: surface the interactive walkthrough and wait for the user to resolve each item.
- When walkthrough finishes (or no items flagged): continue to 5d.

#### 5d. Full verification gate

Show:
```
🔍 Verifying full implementation against spec, plan and tasks...
```

Invoke `/product-flow:speckit.verify`.

Wait for it to finish.

- **CRITICAL issues** → classify and handle following the same protocol as `/product-flow:build` step 5. Re-run verify after resolving. If it passes, continue.
- **HIGH / MEDIUM / LOW issues** → classify and handle. Continue after.
- **No issues** → continue.

#### 5e. Re-establish verification state

Write `VERIFY_TASKS_DONE` and `CODE_VERIFIED` back to `status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq \
  --arg ts1 "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg ts2 "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '. + {"VERIFY_TASKS_DONE": $ts1, "CODE_VERIFIED": $ts2}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: re-record verify_tasks_done and code_verified after fix-N"
git push origin HEAD
```

GPG error? Same fix. **STOP.**

Update `specs/<branch>/fixes/fix-N.md` — fill in the Result section:

```markdown
## Result
✅ Verification passed on [YYYY-MM-DD].
Fix-tasks implemented: [FIX-N-1, FIX-N-2, ...]
```

Commit:
```bash
git add "specs/$BRANCH/fixes/fix-N.md"
git commit -m "docs: record fix-N result"
git push origin HEAD
```

---

### 6. Retro

**Amendments** (skip if error type was Implementation):

Show:
```
📝 Recording spec amendment...
```

Append to `specs/<branch>/spec-amendments.md` (create if needed):

```markdown
## Amendment [M] — [short title] (Fix N, [YYYY-MM-DD])

**Original (spec.md [§section or scenario]):** [what the spec said, or "Not present" for Omission]
**Detected during review:** [what was discovered during testing]
**Decision:** [what was implemented instead / added]
**Type:** [Ambiguity / Omission]
```

M = global amendment count + 1. Commit: `git add "specs/$BRANCH/spec-amendments.md" && git commit -m "docs: append spec amendment M from fix-N" && git push origin HEAD`

**Gap retrospective:**

Show:
```
🔁 Running gap retrospective...
```

Invoke `/product-flow:speckit.retro` with context:
```
after fix N — [error type] gap in [task ID / spec section]
```

Wait for it to finish.

**Update PR history:**

Add a row to `## History` in the PR body:
```
| Fix N complete | YYYY-MM-DD HH:MM:SS | @github-user | [error type] fix — FIX-N-1, FIX-N-2 |
```

```bash
gh pr edit --body "<updated-body>"
```

Show:
```
✅ Fix N complete.
```

---

### 7. Loop

**Go back to step 2.**

The skill continues until step 2 finds no pending fixes and the user confirms there are no more issues. At that point, exit with:

```
✅ All fixes complete.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /product-flow:submit
  → Saves the fixed code and sends it for team review.
─────────────────────────────────────────
```

### Session close

Invoke `/product-flow:context`.
