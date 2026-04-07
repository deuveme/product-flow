---
description: "STEP 5 — Merges to main with squash merge and triggers the deployment pipeline. Requires the PR to be approved."
model: haiku
effort: low
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

Verify that `in_review` is present. If missing: ERROR "The code has not been submitted for review. Run /product-flow:submit first."

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
  question: "This feature has proposed Architecture Decision Records. Do you want to write them to docs/adr/ before merging?"
  header: "ADRs"
  options:
    - label: "Yes, write them"
      description: "Each proposed ADR will be saved as a separate file in docs/adr/ and committed to main alongside the merge."
    - label: "No, skip"
      description: "Proceed with the merge without writing any ADR files."
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

4. Store the generated file paths and contents in memory — do NOT write them yet. They will be committed after the merge in step 6.

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

### 6. Write ADR files (conditional)

If the user chose "Yes, write them" in step 4:

```bash
mkdir -p docs/adr
```

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

Then run /product-flow:deploy-to-stage again.
```
**STOP.**

If the user chose "No, skip": skip this step silently.

### 7. Mark as published

Use `$PR_NUMBER` from step 1 (the branch may no longer exist after the merge).

Mark `- [x] Published` in the PR body and add a history row:

```
| Published | YYYY-MM-DD | Merged to main |
```

```bash
gh pr edit $PR_NUMBER --body "<updated-body>"
```

### 8. Check CI/CD status

```bash
gh run list --limit 3
```

If any runs appear, show them so the user can confirm that the pipeline triggered. If no runs appear, skip silently — the project may use a different CI/CD system.

### 9. Final report

```
✅ Feature published

🚀 Live — check your deployment pipeline for progress

─────────────────────────────────────────
This feature is complete.
─────────────────────────────────────────
```

### 10. Session close

Invoke `/product-flow:context`.
