---
description: "STEP 4 — Saves the code and leaves it ready for team review. Repeatable to iterate."
model: haiku
effort: low
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body,isDraft
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start-feature or /product-flow:start-improvement?"

### 1b. Inbox

Invoke `/product-flow:inbox-sync`.

### 2. Gate: code verified

Read `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
```

Verify that `CODE_VERIFIED` is present. If missing: ERROR "The code has not been verified yet. Run /product-flow:build first."

### 3. Detect whether there are local changes to save

```bash
git status --porcelain
```

- If there are changes: continue to step 4.
- If there are **no changes**:
  - Show:
    ```
    ℹ️  No new local changes to save.
    The code is already created in this branch/PR, so we'll continue and move the PR to review.

    Found issues during testing or review? Run /product-flow:fix instead.
    ```
  - Skip steps 4 and 5 and continue directly to step 6.

### 4. Show change summary

```bash
git diff --stat HEAD
git status --short
```

Show the user which files are going to be saved (including untracked files that will be added).

### 5. Commit and push (only when step 3 found local changes)

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

### 6. Update PR status (first time only)

If `IN_REVIEW` is not yet present in `specs/<branch>/status.json`:

Write `IN_REVIEW` to `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"IN_REVIEW": $ts}' > "$STATUS_FILE"
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

Also take the PR out of draft if it still is:

```bash
gh pr view --json isDraft --jq '.isDraft' | grep -q true && gh pr ready
```

Read the current PR body first (`gh pr view --json body -q '.body'`). If the output is empty, stop with ERROR "Could not read PR body — check GitHub access and try again." Then apply these changes — preserve all other sections intact:
- Mark `- [x] In code review` in `## Status`
- Add row to `## History`: `| In code review | YYYY-MM-DD HH:MM:SS | @github-user | PR ready for review |`

```bash
gh pr edit --body "<updated-body>"
```

Show:
```
👀 In code review. Waiting for team approval.
```

### 6b. Generate quickstart and populate "How to test"

Show:
```
📋 Generating testing guide...
```

Read `specs/<branch>/spec.md`, `specs/<branch>/plan.md`, and `specs/<branch>/tasks.md` to understand what was built.

Generate `specs/<branch>/quickstart.md` with the following structure:

```markdown
# How to test: <feature name>

## For PM

<Acceptance scenarios any reviewer can execute without technical knowledge.
One scenario per user story, written as numbered steps. Include:
- Preconditions (what state the system needs to be in)
- Steps to follow
- Expected result>

## For Devs

<Technical test steps. Include:
- Setup or migration commands to run
- Endpoints or API calls to verify (with example payloads)
- Edge cases and error scenarios to validate
- Any flags or environment variables needed>
```

Commit the file:

```bash
git add specs/<branch>/quickstart.md
git commit -m "docs: add quickstart testing guide"
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

Then update the PR body `## How to test` section. Read the current PR body first (`gh pr view --json body -q '.body'`). If the output is empty, stop with ERROR "Could not read PR body — check GitHub access and try again." Then replace the contents of `## How to test` — preserve all other sections intact:

```markdown
## How to test

### For PM

<summary of PM scenarios — concise, 3–5 bullet points max, linking to quickstart.md for full detail>

### For Devs

<summary of Dev steps — concise, 3–5 bullet points max, linking to quickstart.md for full detail>
```

```bash
gh pr edit --body "<updated-body>"
```

Show:
```
✅ Testing guide ready — specs/<branch>/quickstart.md
```

### 7. Propose ADRs

Read `specs/<branch>/research.md` and `specs/<branch>/decisions.md` (if they exist).

For each decision found, apply this filter before including it:

> Would a dev starting a new feature tomorrow make an inconsistent decision if they didn't know this?

If yes → include. If no → skip.

For each included decision, produce a one-line entry:

```
- **<short-title>** — <one sentence: what was decided and why it's not obvious>
```

If at least one decision passes the filter, insert a `### Proposed ADRs` subsection into the PR body immediately after the `<!-- /dev-checklist -->` marker, within the existing `## For Developers` section:

```markdown
### Proposed ADRs

> Decisions from this feature that may be worth consolidating as project-level Architecture Decision Records.
> Review and confirm before running /product-flow:deploy.

- **<short-title>** — <rationale>
- **<short-title>** — <rationale>
```

If the section already exists (re-running submit), replace it entirely with the updated content.

If no decisions pass the filter, skip this step silently — do not add the section.

Read the current PR body first (`gh pr view --json body -q '.body'`). If the output is empty, stop with ERROR "Could not read PR body — check GitHub access and try again." Then insert or replace the `### Proposed ADRs` subsection immediately after `<!-- /dev-checklist -->` — preserve all other sections intact.

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

If the team finds issues during review:
  Run /product-flow:fix
  → Fix cycle with full TDD guarantees.

When the team approves the PR, run:
  /product-flow:deploy
─────────────────────────────────────────
```

### 9. Session close

Invoke `/product-flow:context`.
