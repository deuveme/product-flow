---
description: "UTILITY — Shows where you are in the workflow right now."
---

## Execution

### 0. Verify dependencies

Check that `gh` is installed and authenticated:

```bash
which gh 2>/dev/null || echo "GH_NOT_FOUND"
gh auth status 2>/dev/null || echo "GH_NOT_AUTHENTICATED"
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

If the result contains `GH_NOT_AUTHENTICATED`, stop execution and show:

```
⚠️  GitHub CLI is installed but not authenticated.

Run in your terminal:
  gh auth login

During login:
  1. Select "GitHub.com"
  2. Select "HTTPS"
  3. Choose "Login with a web browser"
  4. Copy the code shown in the terminal
  5. The browser will open — paste the code and click Continue

Then run /product-flow:status again.
```

### 1. Pull latest changes

Run git pull on the current branch to sync with remote and capture the full output:

```bash
git pull 2>&1
```

Inspect the output:

- **If it succeeded**: continue normally.

- **If it failed with conflict markers** (output contains "CONFLICT" or "Automatic merge failed"):

  Stop execution and show:
  ```
  ⚠️  Your feature has changes that conflict with updates made by someone else on the team.

  This means two people edited the same part of the code at the same time.
  You need to decide which version to keep:

    [1] Keep the server version (discard your local changes)
        Run: git merge --abort && git reset --hard origin/<current_branch>

    [2] Keep your local version (ignore the incoming changes for now)
        Run: git merge --abort

    [3] Resolve manually (ask a developer for help)

  Type 1, 2, or 3 to choose.
  ```

  Wait for user input and execute the corresponding command. After resolving, re-run `/product-flow:status`.

- **If it failed for any other reason** (no remote, no network, etc.):

  Show a note and continue: `⚠️ Could not sync with remote. Showing local version.`

### 2. Gather all features

Run these three commands — do not skip any, do not loop manually over branches:

**Current branch and uncommitted changes:**
```bash
git branch --show-current
git status --porcelain
```

**All branches + their spec files in one shell loop:**
```bash
for branch in $(git branch --format="%(refname:short)" | grep -v "^main$" | grep -v "^master$"); do
  echo "BRANCH:$branch"
  ls specs/$branch/ 2>/dev/null || echo "NO_SPEC"
done
```

**All open PRs in one call:**
```bash
gh pr list --state open --json headRefName,number,title,state,isDraft,url,body,reviewDecision --limit 100 2>/dev/null
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

For each numbered branch, determine the date of its **first commit not in main**:

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
- Replace hyphens and underscores with spaces
- Capitalize the first word
- Example: `feature/add-login-button` → "Add login button"

#### Workflow step labels

Use the PR body checkbox labels as-is:
- `Spec created`
- `Plan generated`
- `Tasks generated`
- `Code generated`
- `In code review`
- `Published`

Step status icons:
- ✅ checkbox is marked
- ▶️  next step to run
- ⏳ waiting for team review/approval
- 🔒 blocked (previous steps incomplete)

---

**Case: on main with no other features**

```
📍 You have no active features.

To start a new one:
  /product-flow:start <description>
```

---

**Case: one or more feature branches exist**

Show current feature first, then others:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 CURRENT FEATURE: <feature name in human language>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If current branch is main, show instead:
```
🟢 CURRENT FEATURE: (none — you are on the main branch)
```

Then show progress for current feature (if it has a PR):
```
   🔗 <PR_URL>

   PROGRESS:
     ✅ Spec created
     ✅ Plan generated
     ▶️  Tasks generated
     🔒 Code generated
     🔒 In code review
     🔒 Published

   ➡️  NEXT: /product-flow:continue
```

If current feature branch has no PR yet and **no SPEC files found**:
```
   (No PR yet — has not been submitted for review)
   ➡️  NEXT: /product-flow:continue
```

If current feature branch has no PR yet but **SPEC files exist**:
```
   ⚠️  No PR yet — SPEC found (no PR was created for this branch)
   ➡️  NEXT: Create PR to track progress (see step 5a)
```

Then for each other feature branch:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 OTHER FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [1] <feature name> — <last completed step or "Not started">
      🔗 <PR_URL if exists>
      ⚠️  No PR yet — SPEC found   ← only if no PR but SPEC files exist

  [2] <feature name> — <last completed step or "Not started">
      🔗 <PR_URL if exists>
```

If no other feature branches exist, omit the "OTHER FEATURES" section entirely.

---

### 4. Unsaved changes

If `git status --porcelain` returns changes:
```
⚠️  You have unsaved changes on your current feature.
    They will be saved on the next /product-flow:submit.
```

---

### 5a. Offer to create PR for SPEC-only branches

If one or more branches have SPEC files but no PR, show the following prompt (one per branch, in order — current branch first, then others):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 MISSING PR: <feature name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  This branch has a SPEC but no GitHub PR.
  Progress so far: <list completed steps e.g. "Spec created, Plan generated">

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

If there are other feature branches, ask at the end:

```
Do you want to continue with the current feature or switch to another one?
  • Type the number of the feature you want to switch to (e.g. "1" or "2")
  • Or press Enter / say "continue" to stay where you are
```

Wait for user input:
- If the user inputs a valid number corresponding to a listed feature, run:
  ```bash
  git stash  # only if there are unsaved changes
  git checkout <branch_name>
  ```
  Then re-run the full status display for the newly checked-out branch.
- If the user says "continue", presses Enter, or says something unrelated, proceed normally.

---

### 6. Session close

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
