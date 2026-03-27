---
description: "STEP 6 — Saves the code and leaves it ready for team review. Repeatable to iterate."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body,isDraft
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 2. Gate: code generated

Verify in the PR body: `- [x] Code generated`

If not marked: ERROR "The code has not been generated yet. Run /product-flow:build first."

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

- If it reports only **HIGH / MEDIUM / LOW** issues → show the findings summary
  and ask:

  ```
  ⚠️  Verification found warnings (no blockers). Do you want to proceed with
  submit anyway, or fix them first? (yes to proceed / no to stop)
  ```

  Wait for the user's response:
  - yes → continue to step 3.
  - no → stop here.

- If it reports **no issues** → continue to step 3 silently.

### 3. Verify there are changes to save

```bash
git status --porcelain
```

If there are no changes: ERROR "There are no new changes to save."

### 4. Show change summary

```bash
git diff --stat HEAD
git status --short
```

Show the user which files are going to be saved (including untracked files that will be added).

### 5. Commit and push

```bash
git add -A
git commit -m "feat(<branch-name>): <brief-summary-of-changes>"
git push origin HEAD
```

### 6. Take the PR out of draft (first time only)

If the PR is in draft (`isDraft: true`):
```bash
gh pr ready
```

If it's already in review: do nothing, the push is sufficient.

### 7. Update PR status (first time only)

If the PR was in draft, mark: `- [x] In code review`

Add row:
```
| In code review | YYYY-MM-DD | PR ready for review |
```

```bash
gh pr edit --body "<updated-body>"
```

### 8. Final report

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

### Session close

Run the `/product-flow:check-and-clear` logic to check the context and guide the user if they need to clear the session.

- **🟢 / 🟡**: Show nothing.
- **🟠**: Show at the end of the report:
  ```
  🟠 Context is high. Open a new session before the next command.
  ```
- **🔴**: Show before the final report and interrupt if the user tries to continue:
  ```
  🔴 Critical context. Open a new session NOW before continuing.
  ```
