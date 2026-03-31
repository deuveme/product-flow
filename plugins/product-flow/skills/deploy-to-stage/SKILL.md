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

Save the `number` field as `PR_NUMBER` and the `url` field as `PR_URL`. These are needed in later steps after the branch is deleted.

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

### 4. Squash merge to main

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

### 5. Mark as published

Use `$PR_NUMBER` from step 1 (the branch may no longer exist after the merge).

Mark `- [x] Published` in the PR body and add a history row:

```
| Published | YYYY-MM-DD | Merged to main |
```

```bash
gh pr edit $PR_NUMBER --body "<updated-body>"
```

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

Invoke `/product-flow:context`.
