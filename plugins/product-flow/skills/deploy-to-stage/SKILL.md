---
description: "STEP 7 — Merges to main with squash merge and triggers the deployment pipeline. Requires the PR to be approved."
---

## Purpose

Merges the feature to `main` with squash merge — all iteration commits are flattened into one. This is the final step of the feature lifecycle: the branch is deleted and any CI/CD pipeline configured in the repository will trigger automatically upon detecting the merge (e.g. deploying to staging or production).

> **Note:** This skill performs the merge to `main`. It does not deploy directly — deployment is handled by whatever CI/CD pipeline the repository has configured.

---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body,reviewDecision
```

- If the branch is `main`: ERROR "You are already on main."
- If there is no PR: ERROR "There is no open PR for this branch."

### 2. Gate: code delivered

Verify in the PR body: `- [x] In code review`

If not marked: ERROR "The code has not been delivered. Run /product-flow:submit first."

### 3. Gate: PR approved

Check `reviewDecision`.

If it is NOT `APPROVED`:

```
🚫 BLOCKED

The PR does not have approval yet.

The team must review and approve the PR on GitHub
before publishing to main.

🔗 PR: <PR_URL>
```

**STOP.**

### 4. Mark as published

Mark `- [x] Published` in the PR body and add a history row:

```
| Published | YYYY-MM-DD | Merged to main |
```

```bash
gh pr edit --body "<updated-body>"
```

### 5. Squash merge to main

```bash
gh pr merge --squash --delete-branch
```

If it fails due to conflicts:

```
🚫 ERROR: There are conflicts when merging with main.

No changes have been made.
Resolve the conflicts manually before continuing.
```

**STOP.**

### 6. Check CI/CD status

```bash
gh run list --limit 3
```

If any runs appear, show them so the user can confirm that the pipeline triggered. If no runs appear, skip silently — the project may use a different CI/CD system.

### 7. Final report

```
✅ Published to main

🌿 Merged: <BRANCH> → main (squash)
🗑️  Branch deleted
🚀 Published — check your deployment pipeline for progress

─────────────────────────────────────────
This feature is complete.
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
