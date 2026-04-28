---
description: "STEP 5 — Merges to main with squash merge and triggers the deployment pipeline. Requires the PR to be approved."
model: sonnet
effort: medium
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

Read `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
```

Verify that `IN_REVIEW` is present. If missing: ERROR "The code has not been submitted for review. Run /product-flow:submit first."

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

### 4. Consolidate ADRs (conditional)

Read the PR body obtained in step 1. Look for a `### Proposed ADRs` section.

If the section does not exist, or all items are already checked (`- [x]`), skip this step silently.

If there are unchecked items (`- [ ]`), collect them and ask:

```
AskUserQuestion:
  question: "During this feature, some technical decisions were made that could be useful for the whole project — not just this feature. Do you want to save them so the team can reference them in future work?"
  header: "Tech decisions"
  options:
    - label: "Yes, save them"
      description: "The decisions will be documented and added to the project so the whole team can find them later."
    - label: "No, skip"
      description: "Merge without saving. The decisions stay visible in this PR but won't be added to the project."
```

**If the user answers "No, skip":** continue to step 5.

**If the user answers "Yes, write them":**

1. Read `specs/<branch>/research.md` and `specs/<branch>/decisions.md` (if they exist) for context.

2. Determine the next ADR number:
   ```bash
   ls docs/adr/ 2>/dev/null | grep -E '^[0-9]+' | sort -V | tail -1
   ```
   Extract the highest number found and increment from there. If `docs/adr/` does not exist or is empty, start at `0001`.

3. For each unchecked proposed ADR, generate a file `docs/adr/NNNN-<slug>.md` using this format:

   ```markdown
   # NNNN — <Title>

   **Status:** Accepted
   **Date:** YYYY-MM-DD
   **Feature:** <branch-name>

   ## Context

   <2–4 sentences explaining the situation that led to this decision, drawn from research.md>

   ## Decision

   <1–3 sentences describing precisely what was decided>

   ## Consequences

   <2–4 sentences on what this enables, what it constrains, and what to watch for in future features>
   ```

   Derive `<slug>` from the title in kebab-case (e.g., `jwt-ttl-24h`). Increment the number for each ADR in the same batch.

4. Store the generated file paths and contents in memory — do NOT write them yet. They will be committed after the merge in step 7.

### 5. Prepare squash commit message

This is the single commit that will appear in `main`'s history — all iteration commits from the feature branch are discarded. It must follow Conventional Commits format.

**Infer the type** from the feature:
- Read `specs/<branch>/spec.md` — if it describes fixing broken behavior, errors, or regressions → `fix`
- If the branch slug contains `fix` or `bug` → `fix`
- If the branch slug contains `refactor` → `refactor`
- If the branch slug contains `docs` → `docs`
- Otherwise → `feat`

**Derive scope and description** from `BRANCH_NAME`:
- Strip the number prefix: `001-user-auth` → slug = `user-auth`
- Use slug as scope: `user-auth`
- Derive description from PR title (strip the number prefix and lowercase): `001: User auth` → `user auth`

Set `SQUASH_MSG = "<type>(<scope>): <description>"` and proceed.

### 6. Squash merge to main

```bash
gh pr merge --squash --delete-branch --subject "$SQUASH_MSG"
```

If the command fails:

- If the error output contains `already been merged` or the PR state is `MERGED`:

  ```
  ℹ️  This PR was already merged. Continuing to post-merge steps.
  ```

  Continue to step 7 — the merge already happened, ADRs and PR body may still need updating.

- If the error output contains `conflict`:

  Enter conflict resolution mode:

  #### 6a. Surface the conflicts locally

  ```bash
  git fetch origin main
  git merge origin/main
  ```

  List conflicted files:

  ```bash
  git diff --name-only --diff-filter=U
  ```

  #### 6b. Resolve each conflict

  For each conflicted file, read its content and identify the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).

  **Try to auto-resolve** if the intent of both sides is unambiguous (e.g. one side added a block the other didn't touch, or one side deleted something the other didn't modify). If auto-resolved, apply the change, `git add <file>`, and continue to the next file silently.

  **If the conflict is ambiguous**, do NOT guess. Instead, translate each version into plain PM language and ask:

  ```
  AskUserQuestion:
    question: |
      There's a conflict in <file> between this feature and recent changes in main.

      **Option A — keep this feature's version:**
      <1–2 sentences explaining in plain language what this version does and what it means for the product>

      **Option B — keep main's version:**
      <1–2 sentences explaining in plain language what this version does and what it means for the product>

      Which version should we keep?
    options:
      - label: "Keep this feature's version"
        description: "<one-line consequence>"
      - label: "Keep main's version"
        description: "<one-line consequence>"
      - label: "I'll resolve it myself — stop here"
        description: "Claude will abort. You resolve the conflict manually and run deploy again."
  ```

  If the user chooses "I'll resolve it myself":
  ```bash
  git merge --abort
  ```
  Show:
  ```
  ⏸️  Merge aborted. Resolve the conflicts in <file>, commit, push, and run /product-flow:deploy again.
  ```
  **STOP.**

  Apply the chosen version, `git add <file>`, and continue to the next conflicted file.

  #### 6c. Commit the resolution and retry

  Once all conflicts are resolved:

  ```bash
  git commit -m "chore: resolve merge conflicts with main"
  git push origin <branch>
  ```

  Then retry:

  ```bash
  gh pr merge --squash --delete-branch --subject "$SQUASH_MSG"
  ```

  If it fails again for any reason other than `already been merged`: surface the raw error and **STOP**.

- Any other error: surface the raw error message and **STOP**.

### 7. Write ADR files (conditional)

If the user chose "Yes, write them" in step 4:

```bash
mkdir -p docs/adr
```

Before writing, check whether `docs/adr/` would be ignored by git:

```bash
git check-ignore -q docs/adr && echo "GITIGNORED"
```

If the output is `GITIGNORED`, warn the user:

```
⚠️  docs/adr/ is listed in .gitignore — ADR files written there will not be tracked in version control.

To fix it, remove or adjust the relevant .gitignore entry, then run /product-flow:deploy again.
```

**STOP.**

Write each generated ADR file to `docs/adr/`. Then:

```bash
git add docs/adr/
git commit -m "docs: add ADRs from <branch-name>"
git push origin main
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:deploy again.
```
**STOP.**

If the user chose "No, skip": skip this step silently.

### 8. Mark as published

Use `$PR_NUMBER` from step 1 (the branch may no longer exist after the merge).

Read the current PR body first (`gh pr view --json body -q '.body'`). If the output is empty, stop with ERROR "Could not read PR body — check GitHub access and try again." Then apply these changes — preserve all other sections intact:
- Mark `- [x] Published` in `## Status`
- Add row to `## History`: `| Published | YYYY-MM-DD HH:MM:SS | @github-user | Merged to main |`

```bash
gh pr edit $PR_NUMBER --body "<updated-body>"
```

Write `PUBLISHED` to `specs/$BRANCH/status.json` (use `$BRANCH` saved in step 2 — the branch name is still valid as a path even after the branch is deleted):

```bash
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"PUBLISHED": $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record published in status.json"
git push origin main
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:deploy again.
```
**STOP.**

Show:
```
🌐 Published. Feature is live.
```

### 9. Check CI/CD status

```bash
gh run list --limit 3
```

If any runs appear, show them so the user can confirm that the pipeline triggered. If no runs appear, skip silently — the project may use a different CI/CD system.

### 10. Final report

```
✅ Feature published

🚀 Live — check your deployment pipeline for progress

─────────────────────────────────────────
This feature is complete.
─────────────────────────────────────────
```

### 11. Session close

Invoke `/product-flow:context`.
