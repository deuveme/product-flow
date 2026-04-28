---
description: "Shows current workflow position and what the next step is."
model: haiku
effort: low
---

## Execution

### 0a. Check for plugin updates

Check whether a newer version of product-flow is available on the remote.

```bash
PLUGIN_DIR="$HOME/.claude/plugins/marketplaces/product-flow"
if [ -d "$PLUGIN_DIR/.git" ]; then
  LOCAL_HASH=$(git -C "$PLUGIN_DIR" rev-parse HEAD 2>/dev/null)
  LOCAL_VER=$(grep '"version"' "$PLUGIN_DIR/plugins/product-flow/.claude-plugin/plugin.json" 2>/dev/null | head -1 | sed 's/.*"version"[^"]*"\([^"]*\)".*/\1/')
  git -C "$PLUGIN_DIR" fetch --quiet 2>/dev/null
  REMOTE_HASH=$(git -C "$PLUGIN_DIR" rev-parse FETCH_HEAD 2>/dev/null)
  REMOTE_VER=$(git -C "$PLUGIN_DIR" show FETCH_HEAD:plugins/product-flow/.claude-plugin/plugin.json 2>/dev/null | grep '"version"' | head -1 | sed 's/.*"version"[^"]*"\([^"]*\)".*/\1/')
  echo "LOCAL_HASH=$LOCAL_HASH"
  echo "REMOTE_HASH=$REMOTE_HASH"
  echo "LOCAL_VER=$LOCAL_VER"
  echo "REMOTE_VER=$REMOTE_VER"
else
  echo "PLUGIN_NOT_INSTALLED"
fi
```

**Evaluate the result:**

- If `PLUGIN_NOT_INSTALLED` or any command failed silently: skip this step and continue to step 0.
- If `LOCAL_HASH` equals `REMOTE_HASH` (or `REMOTE_HASH` is empty due to no network): skip this step and continue to step 0.
- If `LOCAL_HASH` differs from `REMOTE_HASH`:

Use the `AskUserQuestion` tool to ask:
```
─────────────────────────────────────────
  🆕 product-flow update available

  Installed: v<LOCAL_VER>  →  Latest: v<REMOTE_VER>

  Update now? (yes / no)
```

**If "no"**: continue to step 0.

**If "yes"**: run the official plugin update command:

```bash
/plugin update product-flow@product-flow
```

After it completes, verify the version actually changed:

```bash
grep '"version"' "$HOME/.claude/plugins/marketplaces/product-flow/plugins/product-flow/.claude-plugin/plugin.json" 2>/dev/null | head -1 | sed 's/.*"version"[^"]*"\([^"]*\)".*/\1/'
```

- If the new version matches `REMOTE_VER`: show `✅ Updated to v<REMOTE_VER> — restart Claude Code for the changes to take effect.`
- If the version is unchanged: the update silently failed. Before surfacing anything to the user, investigate:
  1. Check network connectivity: `curl -sI https://github.com 2>&1 | head -1`
  2. Check the git remote is reachable: `git -C "$HOME/.claude/plugins/marketplaces/product-flow" remote -v 2>&1`
  3. Check if the local repo has uncommitted changes or conflicts blocking the pull: `git -C "$HOME/.claude/plugins/marketplaces/product-flow" status --short 2>&1`
  4. If a fixable issue is found (e.g. uncommitted changes), resolve it (stash or reset) and retry `/plugin update product-flow@product-flow` once.
  5. Only if the problem cannot be resolved automatically, show the user a clear diagnosis:
     ```
     ⚠️  Could not update product-flow. Diagnosis: <specific reason found>

     To fix manually: <concrete command or action>
     ```

Then stop execution (do not continue to step 0 — the user should restart after the update).

---

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

### 0b. Check Claude Code permissions

Read `~/.claude/settings.json`. Check whether it contains a `permissions.deny` block with `"Bash(git push * main)"` and a `permissions.allow` block with `"Read"`.

- If both are present: continue.
- If the file doesn't exist or the permissions are missing:
  - Use the `AskUserQuestion` tool to ask:
    ```
    ⚠️  Claude Code permissions are not configured on this machine.

    Do you want to set them up now? (yes / no)
    ```
  - If **yes**: run the following and stop execution:
    ```bash
    mkdir -p "$HOME/.claude"
    [ -f "$HOME/.claude/settings.json" ] && cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup"
    cat > "$HOME/.claude/settings.json" << 'EOF'
    {
      "permissions": {
        "deny": [
          "Bash(git push * main)",
          "Bash(git push *:main)",
          "Bash(git push *:refs/heads/main)",
          "Bash(git merge * main)",
          "Bash(git checkout main)"
        ],
        "allow": [
          "Read",
          "Glob",
          "Grep",
          "Bash(ls *)",
          "Bash(ls)",
          "Bash(find *)",
          "Bash(cat *)",
          "Bash(head *)",
          "Bash(tail *)",
          "Bash(git status *)",
          "Bash(git status)",
          "Bash(git log *)",
          "Bash(git log)",
          "Bash(git diff *)",
          "Bash(git diff)",
          "Bash(git show *)",
          "Bash(git branch *)",
          "Bash(git branch)",
          "Bash(git remote *)",
          "Bash(git remote)",
          "Edit",
          "Write",
          "NotebookEdit",
          "Bash(git add *)",
          "Bash(git add)",
          "Bash(git commit *)",
          "Bash(git push *)",
          "Bash(git checkout *)",
          "Bash(git switch *)"
        ]
      }
    }
    EOF
    ```
    Then show:
    ```
    ✅ Permissions configured. Restart Claude Code for the changes to take effect.
    ```
  - If **no**: stop execution and show:
    ```
    You can run /product-flow:status again whenever you're ready.
    ```

### 0b2. Check GPG commit signing

```bash
git config --get commit.gpgsign 2>/dev/null
```

If the output is `true`:
  Use the `AskUserQuestion` tool to ask:
  ```
  ⚠️  GPG commit signing is enabled on this machine.

  product-flow makes automatic commits during the workflow. If the GPG agent is unavailable (e.g. in a new terminal session), these commits will fail and block the workflow.

  Disable GPG signing for this repository? (yes / no)
  ```

  - If **yes**: run:
    ```bash
    git config commit.gpgsign false
    ```
    Then show:
    ```
    ✅ GPG signing disabled for this repository.
    ```
  - If **no**: show a note and continue:
    ```
    ℹ️  GPG signing is active. If commits fail during the workflow, run:
        git config commit.gpgsign false
    ```

### 0c. Sync with remote

Before doing anything else, bring the local branch up to date with the remote.

```bash
git status --porcelain 2>/dev/null
```

- If there are uncommitted changes (output is non-empty):
  ```bash
  git stash
  git pull
  git stash pop
  ```
- If the working tree is clean (output is empty):
  ```bash
  git pull
  ```

If `git pull` fails for any reason (no remote, no network, not tracking a remote branch, etc.), show a note and continue:
```
⚠️  Could not pull from remote. Showing local version.
```

If `git stash pop` fails (e.g. conflict after pull), show:
```
⚠️  Could not restore stashed changes automatically. Run `git stash pop` manually.
```
and continue without the stash pop.

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

For each feature with a spec directory, read `specs/<branch>/status.json` if it exists — it is the primary source of truth. Fall back to file existence for branches without `status.json`:

```bash
cat "specs/$branch/status.json" 2>/dev/null || echo "{}"
```

Extract `flow` field: `"feature"` or `"improvement"`. If absent, treat as `"feature"`.

- `SPEC_CREATED` in status.json (or `spec.md` present) → "Spec created" is done
- `PLAN_GENERATED` in status.json (or `plan.md` present) → "Plan generated" is done
- `TASKS_GENERATED` in status.json (or `tasks.md` present) → "Tasks generated" is done
- `CODE_WRITTEN` in status.json → implementation in progress (not yet verified)
- `CODE_VERIFIED` in status.json → "Code generated" is done
- `IN_REVIEW` in status.json → "In code review" is done
- `SPLIT_PREPLAN_ANALIZED` in status.json → internal routing flag; not displayed as a discrete step (sits between Spec and Plan in the lifecycle — scope split was analyzed before planning)
- `SPLIT_POSTPLAN_ANALIZED` in status.json → internal routing flag; not displayed as a discrete step (sits between Plan and Tasks in the lifecycle — scope split was analyzed after planning)

For the **next step** recommendation, use the `flow` field:
- `flow === "improvement"`: use the improvement lifecycle (`IMPROVEMENT_STARTED → SPEC_CREATED → PLAN_GENERATED → TASKS_GENERATED → CODE_WRITTEN → CODE_VERIFIED → IN_REVIEW → PUBLISHED`). No `CHECKLIST_DONE` step.
- `flow === "feature"` or absent: use the full feature lifecycle as before.

Track branches with no PR but with at least `spec.md` as **SPEC-only branches**.

### 2b. Check for unanswered PR questions

Only run this if the current branch has an open PR. Invoke `/product-flow:pr-comments pending`.

Store the result as `PENDING_COMMENTS`:
- If it returns `NO_PENDING_COMMENTS`: `PENDING_COMMENTS = []`
- Otherwise: store the list of UNANSWERED comments (question number, type, short body)

This will be surfaced in step 3.

---

### 2c. Validate naming consistency and numbering

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
git log --reverse --format="%ct" origin/<branch_name> ^origin/main 2>/dev/null | head -1
```

Use `%ct` (Unix epoch seconds) for comparison — this avoids timezone ambiguity. Sort all numbered branches by this timestamp (ascending). The branch with the oldest first commit must have the lowest number.

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

**Sequence mismatches** require user confirmation. Use the `AskUserQuestion` tool to ask:

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

  💡 /product-flow:start-feature <description>  — new feature
  💡 /product-flow:start-improvement <description>  — improve something already live
```

On a feature branch with PR (show type badge based on `flow` field — `"feature"` or absent → ✨ Feature, `"improvement"` → 🔧 Improvement):
```
─────────────────────────────────────────
  📍 Working on: **<feature name in human language>**  ✨ Feature
  (or)
  📍 Working on: **<feature name in human language>**  🔧 Improvement

  🔗 <PR_URL>

  ✅ Spec created
  ✅ Plan generated
  🟡 **Tasks generated**
  ⚫ Code generated
  ⚫ In code review
  ⚫ Published

  ➡️  ***​/product-flow:continue***
```

The `➡️` next step line adapts to the current state.

Flag order (earliest → latest):
`FEATURE_STARTED` → `DESIGN_DONE` → `SPEC_CREATED` → `SPLIT_PREPLAN_ANALIZED` → `PLAN_GENERATED` → `SPLIT_POSTPLAN_ANALIZED` → `TASKS_GENERATED` → `CHECKLIST_DONE` → `CODE_WRITTEN` → `VERIFY_TASKS_DONE` → `CODE_VERIFIED` → `IN_REVIEW` → `PUBLISHED`

Backward-compat: if `SPLIT_DONE` is present but `SPLIT_PREPLAN_ANALIZED` is absent, treat `SPLIT_DONE` as equivalent to `SPLIT_PREPLAN_ANALIZED` when determining the latest flag.

Non-lifecycle fields (`parent`, `processed_answers`, `processed_comment_ids`) are ignored for routing.

Determine the **latest flag present** in `status.json` using the order above, then apply this table:

| Latest flag present | Next step shown |
|---|---|
| `FEATURE_STARTED`, `DESIGN_DONE`, `SPEC_CREATED`, `SPLIT_PREPLAN_ANALIZED`, `PLAN_GENERATED`, `SPLIT_POSTPLAN_ANALIZED`, `TASKS_GENERATED`, `CHECKLIST_DONE`, `CODE_WRITTEN`, or `VERIFY_TASKS_DONE` | `***​/product-flow:continue***` |
| `CODE_VERIFIED` | `***​/product-flow:submit***` + hint: *Found issues? Run /product-flow:fix* |
| `IN_REVIEW` | `***​/product-flow:deploy***` (when PR approved) + hint: *Team found issues? Run /product-flow:fix* |
| `PUBLISHED` | *(no next step — feature complete)* |

If `PENDING_COMMENTS` is non-empty, append a warning block after the step list:
```
  ⚠️  <N> unanswered question(s) on the PR — reply before continuing:
     · Q<N> (<type>) — <short summary of the question>
     · Q<N> (<type>) — <short summary of the question>
     🔗 <PR_URL>
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

**With PR** — inline progress + link (include type badge from `flow` field):
```
  [N]  **<feature name>**  ✨ Feature
       ✅ Spec  ✅ Plan  🟡 Tasks  ⚫ Code  ⚫ Review  ⚫ Done
       🔗 <PR_URL>
  (or)
  [N]  **<feature name>**  🔧 Improvement
       ✅ Spec  🟡 Plan  ⚫ Tasks  ⚫ Code  ⚫ Review  ⚫ Done
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
  *💡 /product-flow:start-feature <description>  to start a new feature*
  *💡 /product-flow:start-improvement <description>  to improve something already live*
```

When other features exist and on main:
```
─────────────────────────────────────────
  Switch? Type 1 · 2 · …  or  Enter to stay on main
  *💡 /product-flow:start-feature <description>  to start a new feature*
  *💡 /product-flow:start-improvement <description>  to improve something already live*
```

When no other features exist (regardless of branch):
```
─────────────────────────────────────────
  *💡 /product-flow:start-feature <description>  to start a new feature*
  *💡 /product-flow:start-improvement <description>  to improve something already live*
```

---

### 4. Unsaved changes

Using the file changes captured in step 1 (`git status --branch --porcelain`), if any lines beyond the `##` header are present:
```
⚠️  Unsaved changes on your current feature — will be saved on the next /product-flow:submit.
```

---

### 5a. Offer to create PR for SPEC-only branches

If one or more branches have SPEC files but no PR, for each branch (current branch first, then others) use the `AskUserQuestion` tool to ask:

```
─────────────────────────────────────────
  🔧 MISSING PR: **<feature name>**

  This branch has a spec but no GitHub PR.
  Progress: <list completed steps e.g. "Spec created, Plan generated">

  Create a PR for this feature? (yes / no)
```

Based on the answer:

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

If the check runs, invoke `/product-flow:context`.
