---
description: "STEP 4 — Saves the code and leaves it ready for team review. Repeatable to iterate."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body,isDraft
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 2. Gate: code verified

Read `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
```

Verify that `code_verified` is present. If missing: ERROR "The code has not been verified yet. Run /product-flow:build first."

### 2b. Verification gate

Invoke `/product-flow:speckit.verify`.

**Wait for `speckit.verify` to finish before continuing.**

- If it reports **CRITICAL** issues → **STOP**. Do not commit or push. Show:

  ```
  🚫 BLOCKED — Verification failed

  The implementation has critical issues that must be resolved before submitting.

  Options:
    A. Fix the issues manually and run /product-flow:submit again
    B. Run /product-flow:speckit.reconcile "<gap description>" if the
       implementation is correct and the spec/plan need updating instead

  What do you want to do?
  ```

  Wait for the user's response:
  - Option A → stop here. User fixes and re-runs `/product-flow:submit`.
  - Option B → invoke `/product-flow:speckit.reconcile` passing the gap
    description the user provides. After it finishes, re-run
    `/product-flow:speckit.verify` once more. If it still shows CRITICAL issues,
    stop and repeat this decision. If it passes, continue to step 3.

- If it reports only **HIGH / MEDIUM / LOW** issues → for each issue found:
  1. Attempt to resolve it.
  2. Invoke `/product-flow:pr-comments write` following the technical decision format — ANSWERED if resolved, UNANSWERED if not.

  Then ask:

  ```
  ⚠️  The code review found some minor issues. They have been posted on the PR for the team to review.

  Do you want to proceed anyway, or fix them first? (yes to proceed / no to stop)
  ```

  Wait for the user's response:
  - yes → continue to step 3.
  - no → stop here.

- If it reports **no issues** → continue to step 3 silently.

### 3. Verify there are changes to save

```bash
git status --porcelain
```

- If there are changes: continue normally.
- If there are **no changes**: ERROR "There are no new changes to save."

### 4. Show change summary

```bash
git diff --stat HEAD
git status --short
```

Show the user which files are going to be saved (including untracked files that will be added).

### 5. Commit and push

#### 5a. Commit

```bash
git add -A
git commit -m "feat(<branch-name>): <brief-summary-of-changes>"
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:submit again.
```
**STOP.**

#### 5b. Push

```bash
git push origin HEAD
```

### 6. Take the PR out of draft (first time only)

If the PR is in draft (`isDraft: true`):
```bash
gh pr ready
```

If it's already in review: do nothing, the push is sufficient.

### 7. Update PR status (first time only)

If the PR was in draft:

Write `in_review` to `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"in_review": $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record in_review in status.json"
git push origin HEAD
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:submit again.
```
**STOP.**

Mark `- [x] In code review` and add row:
```
| In code review | YYYY-MM-DD | PR ready for review |
```

```bash
gh pr edit --body "<updated-body>"
```

### 8. Propose ADRs

Read `specs/<branch>/research.md` and `specs/<branch>/decisions.md` (if they exist).

For each decision found, apply this filter before including it:

> Would a dev starting a new feature tomorrow make an inconsistent decision if they didn't know this?

If yes → include. If no → skip.

For each included decision, produce a one-line entry:

```
- [ ] **<short-title>** — <one sentence: what was decided and why it's not obvious>
```

If at least one decision passes the filter, insert a `### Proposed ADRs` subsection into the PR body immediately after the `<!-- /dev-checklist -->` marker, within the existing `## For Developers` section:

```markdown
### Proposed ADRs

> Decisions from this feature that may be worth consolidating as project-level Architecture Decision Records.
> Review and confirm before running /product-flow:deploy-to-stage.

- [ ] **<short-title>** — <rationale>
- [ ] **<short-title>** — <rationale>
```

If the section already exists (re-running submit), replace it entirely with the updated content.

If no decisions pass the filter, skip this step silently — do not add the section.

```bash
gh pr edit --body "<updated-body>"
```

### 10. Final report

```
✅ Code saved

🔗 PR: <PR_URL>

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
The development team will review the code.

If you need to make more changes:
  Run /product-flow:submit again

When the dev approves the PR, run:
  /product-flow:deploy-to-stage
─────────────────────────────────────────
```

### 11. Session close

Invoke `/product-flow:context`.
