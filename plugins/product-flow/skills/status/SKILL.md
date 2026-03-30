---
description: "Shows current workflow position and what the next step is."
---

## Execution

### 0. Verify dependencies

Check that `gh` is installed:

```bash
which gh 2>/dev/null || echo "GH_NOT_FOUND"
```

If the result contains `GH_NOT_FOUND`, stop execution and show:

```
⚠️  GitHub CLI (`gh`) is not installed. It is required to query the PR status.

Install it with:
  brew install gh        # macOS

Then authenticate:
  gh auth login

During login:
  1. Select "GitHub.com"
  2. Select "HTTPS"
  3. Choose "Login with a web browser"
  4. Copy the code shown in the terminal
  5. The browser will open — paste the code and click Continue

Then run /product-flow:status again.
```

Do not check `gh auth status` — authentication will be validated implicitly when `gh pr list` runs in step 2. If it fails due to auth, surface the error then.

### 1. Fetch latest changes

Run a non-blocking fetch to update remote tracking refs without modifying the working tree. Also capture branch and file status in one call to reuse in step 2:

```bash
git fetch --quiet 2>&1
git status --branch --porcelain 2>/dev/null
```

From the `git status` output:
- First line (starts with `##`) contains branch tracking info — if it contains `behind`, show an inline note and continue:
  ```
  ⚠️  Your branch is behind the remote — consider running git pull when ready.
  ```
- Remaining lines are file changes — store them for step 2 (unsaved changes check) and step 4.

If `git fetch` failed for any reason (no remote, no network, etc.):

  Show a note and continue: `⚠️  Could not sync with remote. Showing local version.`

### 2. Gather all features

Run these two commands — do not skip any, do not loop manually over branches:

**Current branch** (reuse `git status` output from step 1 — no need to run again):
- Current branch name: from the `##` line of `git status --branch --porcelain`
- Uncommitted changes: from the remaining lines of the same output

**All branches + their spec files in one shell loop:**
```bash
for branch in $(git branch --format="%(refname:short)" | grep -v "^main$" | grep -v "^master$"); do
  echo "BRANCH:$branch"
  ls specs/$branch/ 2>/dev/null || echo "NO_SPEC"
done
```

**All open PRs in one call:**
```bash
gh pr list --state open --json headRefName,number,title,state,isDraft,url,body,reviewDecision --limit 100 2>&1
```

If the output contains `authentication` or `auth` errors, stop and show:
```
⚠️  GitHub CLI is not authenticated.

Run in your terminal:
  gh auth login

Then run /product-flow:status again.
```

The **branch list is the source of truth**. Every branch printed by the loop is a feature to display.

For each branch:
- Match it to a PR by `headRefName`. If no match → no PR.
- Check the `ls` output for that branch. If `NO_SPEC` → no spec files.

Inspect spec files to determine the furthest completed step:
- `spec.md` present → "Spec created" is done
- `plan.md` present → "Plan generated" is done
- `tasks.md` present → "Tasks generated" is done

Track branches with no PR but with at least `spec.md` as **SPEC-only branches**.

### 2b. Validate naming consistency and numbering

For every feature branch that has a SPEC (with or without PR), perform these checks in order. Collect all issues before surfacing them.

#### Check 1 — Branch name matches spec folder

For each feature branch with a SPEC, verify that a folder `specs/<branch_name>/` exists.

```bash
ls specs/ 2>/dev/null
```

If `specs/<branch_name>/` does not exist but there is exactly one other folder in `specs/` that shares the same non-numeric suffix (e.g., branch is `003-user-auth` and folder is `specs/001-user-auth/`), record a **name mismatch**.

If the PR title exists and differs from `<branch_name>`, also record a **PR title mismatch**.

#### Check 2 — No duplicate numbers

Extract the numeric prefix (zero-padded or not) from every feature branch name that follows the `NNN-<short-name>` pattern:

```bash
git branch --format="%(refname:short)" | grep -v "^main$" | grep -v "^master$" | grep -E '^[0-9]+'
```

If two or more branches share the same numeric prefix, record a **duplicate number error**. This is a blocking error — stop and surface it immediately:

```
🚨 DUPLICATE BRANCH NUMBERS DETECTED

  These branches share the same number and cannot coexist:
    • <branch_a>
    • <branch_b>

  Each feature must have a unique number.
  Rename one of them manually before continuing.
```

Do not proceed with the rest of the status until the user resolves this.

#### Check 3 — Numbers are chronological (001 = oldest)

First, do a fast pre-check: extract all numeric prefixes from numbered branches and verify they are already in ascending order by name. If they are in order, **skip this check entirely** — no git log needed.

```bash
git branch --format="%(refname:short)" | grep -v "^main$" | grep -v "^master$" | grep -E '^[0-9]+' | sort -V
```

Only if the numeric prefixes are **not** in simple ascending order, run the per-branch date check to confirm:

```bash
git log --reverse --format="%ci" origin/<branch_name> ^origin/main 2>/dev/null | head -1
```

Sort all numbered branches by this date (ascending). The branch with the oldest first commit must have the lowest number.

If the numbers are out of chronological order, record a **sequence mismatch** for each affected branch (e.g., `002-user-auth` was created before `001-checkout`).

#### Surface and fix issues

**Name mismatches and PR title mismatches are fixed automatically** — no user confirmation needed. Execute immediately for each affected branch:

1. **Rename spec folder** to match branch name (if folder name differs):
   ```bash
   git mv specs/<old_folder> specs/<new_folder>
   git add -A
   git commit -m "chore: rename spec folder to match branch name"
   git push
   ```

2. **Update PR title** to match branch name (if PR title differs):
   ```bash
   gh pr edit <pr_number> --title "<branch_name>"
   ```

Show a brief inline note for each fix applied:
```
  🔧 Renamed specs/<old_folder> → specs/<new_folder>
  🔧 Updated PR title → "<branch_name>"
```

**Sequence mismatches** require user confirmation. Show:

```
⚠️  SEQUENCE MISMATCH

  Branch numbers are not in chronological order:
    • "002-user-auth" was created before "001-checkout" — numbers should be swapped

  Reorder branch numbers to match creation order? (yes / no)
```

- **If "no"**: continue with the rest of status (display state as-is, with the mismatch flagged inline).
- **If "yes"**: for each affected branch, rename local + remote branch, spec folder, and PR title:
  ```bash
  git branch -m <old_branch> <new_branch>
  git push origin :<old_branch> <new_branch>
  git push -u origin <new_branch>
  git mv specs/<old_folder> specs/<new_folder>
  git add -A
  git commit -m "chore: reorder branch numbers to match creation order"
  git push
  gh pr edit <pr_number> --title "<new_branch>"
  ```
  Then show:
  ```
  ✅ Branch numbers reordered.
  ```

Continue with step 3 using the corrected names.

### 3. Interpret and display

#### Branch-to-feature name translation

Convert branch names to human-readable feature names:
- Strip common prefixes: `feature/`, `feat/`, `fix/`, `pm/`, `chore/`
- If the branch starts with a numeric prefix (`NNN-`), replace the **first** hyphen with `: ` and keep the number — then replace remaining hyphens/underscores with spaces and capitalize the first word after the colon
  - Example: `001-workflow-mvp` → `001: Workflow mvp`
- Otherwise, replace all hyphens and underscores with spaces and capitalize the first word
  - Example: `feature/add-login-button` → `Add login button`

#### Workflow step labels

Use the PR body checkbox labels as-is:
- `Spec created`
- `Plan generated`
- `Tasks generated`
- `Code generated`
- `In code review`
- `Published`

Step status icons:
- ✅ completed
- 🟡 current step (next to run)
- ⚫ not yet reached
- ⚠️  warning or issue

---

Every output starts with a single top separator, then uses separators only as dividers between sections — never as closing borders. Omit a section entirely when it has nothing to show.

---

**Current state section** — always first

On main:
```
─────────────────────────────────────────
  📍 main  ·  no active feature
```

On a feature branch with PR:
```
─────────────────────────────────────────
  📍 Working on: **<feature name in human language>**

  🔗 <PR_URL>

  ✅ Spec created
  ✅ Plan generated
  🟡 **Tasks generated**
  ⚫ Code generated
  ⚫ In code review
  ⚫ Published

  ➡️  ***​/product-flow:continue***
```

On a feature branch with no PR and no spec:
```
─────────────────────────────────────────
  📍 Working on: **<feature name in human language>**

  (no PR yet)

  ➡️  ***​/product-flow:continue***
```

On a feature branch with no PR but spec exists:
```
─────────────────────────────────────────
  📍 Working on: **<feature name in human language>**

  ⚠️  no PR — spec found (no PR was created for this branch)
```

---

**OTHER FEATURES IN PROGRESS section** — only when other feature branches exist

Each entry can be in one of three states:

**With PR** — inline progress + link:
```
  [N]  **<feature name>**
       ✅ Spec  ✅ Plan  🟡 Tasks  ⚫ Code  ⚫ Review  ⚫ Done
       🔗 <PR_URL>
```

**No PR but has spec** — inline progress + warning:
```
  [N]  **<feature name>**
       ✅ Spec  ⚫ Plan  ⚫ Tasks  ⚫ Code  ⚫ Review  ⚫ Done
       *⚠️  no PR yet*
```

**No PR and no spec** — not started:
```
  [N]  **<feature name>**
       (not started)
```

Full section example:
```
─────────────────────────────────────────
  **OTHER FEATURES IN PROGRESS:**

  [1]  **001: Workflow mvp**
       ✅ Spec  🟡 Plan  ⚫ Tasks  ⚫ Code  ⚫ Review  ⚫ Done
       🔗 https://github.com/…/pull/6

  [2]  **003: New payments flow**
       ✅ Spec  ⚫ Plan  ⚫ Tasks  ⚫ Code  ⚫ Review  ⚫ Done
       *⚠️  no PR yet*

  [3]  **004: Experimental branch**
       (not started)
```

---

**Footer section** — always last

When other features exist and on a feature branch:
```
─────────────────────────────────────────
  Switch? Type 1 · 2 · …  or  Enter to stay
  *💡 /product-flow:start <description>  to start a new feature*
```

When other features exist and on main:
```
─────────────────────────────────────────
  Switch? Type 1 · 2 · …  or  Enter to stay on main
  *💡 /product-flow:start <description>  to start a new feature*
```

When no other features exist (regardless of branch):
```
─────────────────────────────────────────
  *💡 /product-flow:start <description>  to start a new feature*
```

---

### 4. Unsaved changes

Using the file changes captured in step 1 (`git status --branch --porcelain`), if any lines beyond the `##` header are present:
```
⚠️  Unsaved changes on your current feature — will be saved on the next /product-flow:submit.
```

---

### 5a. Offer to create PR for SPEC-only branches

If one or more branches have SPEC files but no PR, show the following prompt (one per branch, in order — current branch first, then others):

```
─────────────────────────────────────────
  🔧 MISSING PR: **<feature name>**

  This branch has a spec but no GitHub PR.
  Progress: <list completed steps e.g. "Spec created, Plan generated">

  Create a PR for this feature? (yes / no)
```

Wait for user input:

- **If "no"**: skip this branch and continue to the next one (or to step 5).
- **If "yes"**: build the PR body based on the SPEC files found, then run:

```bash
gh pr create \
  --title "<branch_name>" \
  --draft \
  --base main \
  --head <branch_name> \
  --body "<PR_BODY>"
```

The PR body must follow this exact template, with checkboxes pre-checked based on SPEC files found:

```
## Feature
Spec: specs/<branch_name>/spec.md

## Status
- [x] Spec created          ← always checked if spec.md exists
- [x] Plan generated        ← checked only if plan.md exists
- [x] Tasks generated       ← checked only if tasks.md exists
- [ ] Code generated
- [ ] In code review
- [ ] Published

## History

| Status | Date | Note |
|--------|------|------|
| PR created | <today YYYY-MM-DD> | PR created retroactively from existing SPEC |

## Notes
```

Unchecked steps that are not yet reached use `- [ ]`. Only mark `- [x]` for steps with corresponding files confirmed in step 2.

After creating the PR, show:
```
  ✅ PR created: <PR_URL>
```

Then continue to the next SPEC-only branch (if any), and finally proceed to step 5.

---

### 5. Offer to switch feature

The footer section (defined in step 3) already renders the switch prompt. Wait for user input:

- If the user inputs a valid number corresponding to a listed feature, run:
  ```bash
  git stash  # only if there are unsaved changes
  git checkout <branch_name>
  ```
  Then re-run the full status display for the newly checked-out branch.
- If the user says "continue", presses Enter, or says something unrelated, proceed normally.

---

### 6. Session close

Only run this check if the conversation already has significant context (more than ~10 messages or prior tool calls visible in the session). If the session is fresh, skip entirely.

If the check runs, apply `/product-flow:check-and-clear` logic:

- **🟢 / 🟡**: Show nothing.
- **🟠**: Show at the end of the report:
  ```
  🟠 Context is high. Open a new session before the next command.
  ```
- **🔴**: Show before the final report and interrupt if the user tries to continue:
  ```
  🔴 Critical context. Open a new session NOW before continuing.
  ```
