---
description: "STEP 7 — Publishes to main with squash merge. Requires the PR to be approved."
---

## Purpose

Merges the feature to `main` with squash merge — all iteration commits are flattened into one. GitHub Actions deploys automatically upon detecting the merge.

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

If not marked: ERROR "The code has not been delivered. Run /submit first."

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

### 5. Verify GitHub Actions has triggered

```bash
gh run list --limit 3
```

Show the active workflows to confirm the deploy started.

### 6. Final report

```
✅ Published to main

🌿 Merged: <BRANCH> → main (squash)
🗑️  Branch deleted
🚀 Deploy in progress — GitHub Actions deploying

─────────────────────────────────────────
This feature is complete.
─────────────────────────────────────────
```

### Session close

Run the `/check-and-clear` logic to check the context and guide the user if they need to clear the session.

- **🟢 / 🟡**: Show nothing.
- **🟠**: Show at the end of the report:
  ```
  🟠 Context is high. Open a new session before the next command.
  ```
- **🔴**: Show before the final report and interrupt if the user tries to continue:
  ```
  🔴 Critical context. Open a new session NOW before continuing.
  ```
