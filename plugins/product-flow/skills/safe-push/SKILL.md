---
description: "Pushes to the remote branch and resolves any sync conflicts with the remote."
user-invocable: false
model: sonnet
effort: low
---

## Purpose

Pushes current changes to the remote branch. If the push is rejected because the remote has new commits, syncs and resolves any conflicts before retrying.

## Execution

### 1. Push

```bash
git push origin HEAD
```

If the push succeeds: done.

If the push fails and the error does **not** contain `rejected` or `non-fast-forward`: surface the raw error and **STOP**.

### 2. Sync with remote

```bash
git pull origin HEAD
```

If this fails for any reason other than merge conflicts: surface the raw error and **STOP**.

### 3. Resolve conflicts (if any)

```bash
git diff --name-only --diff-filter=U
```

If no conflicted files: the pull merged cleanly. Continue to step 4.

For each conflicted file, read its content and identify conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).

**Try to auto-resolve** if the intent of both sides is unambiguous (e.g. one side added a block the other didn't touch, or one side deleted something the other didn't modify). If auto-resolved, apply the change, `git add <file>`, and continue to the next file silently.

**If the conflict is ambiguous**, do NOT guess. Translate each version into plain PM language and ask:

```
AskUserQuestion:
  question: |
    There's a conflict in <file> between your local changes and the remote version of this branch.

    **Option A — keep your local version:**
    <1–2 sentences explaining in plain language what this version does and what it means for the product>

    **Option B — keep the remote version:**
    <1–2 sentences explaining in plain language what this version does and what it means for the product>

    Which version should we keep?
  options:
    - label: "Keep my local version"
      description: "<one-line consequence>"
    - label: "Keep the remote version"
      description: "<one-line consequence>"
    - label: "I'll resolve it myself — stop here"
      description: "Claude will abort the merge. Resolve the conflict manually and retry the operation."
```

If the user chooses "I'll resolve it myself — stop here":
```bash
git merge --abort
```
Show:
```
⏸️  Merge aborted. Resolve the conflicts in <file>, commit, and retry the operation.
```
**STOP.**

Apply the chosen version, `git add <file>`, and continue to the next conflicted file.

### 4. Commit the resolution

```bash
git commit -m "chore: resolve sync conflicts with remote"
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then retry the operation.
```
**STOP.**

### 5. Retry push

```bash
git push origin HEAD
```

If this fails for any reason: surface the raw error and **STOP**.
