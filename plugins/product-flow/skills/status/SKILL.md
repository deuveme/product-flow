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

```bash
git branch --show-current
git branch --format="%(refname:short)" | grep -v "^main$" | grep -v "^master$"
git status --porcelain
```

For the **current branch** (if not main/master):
```bash
gh pr view --json number,title,state,isDraft,url,body,reviewDecision 2>/dev/null || echo "NO_PR"
```

For **each other branch** (not current, not main/master):
```bash
gh pr list --head <branch_name> --json number,title,state,isDraft,url,body,reviewDecision --limit 1 2>/dev/null
```

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

If current feature branch has no PR yet:
```
   (No PR yet — has not been submitted for review)
   ➡️  NEXT: /product-flow:continue
```

Then for each other feature branch:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 OTHER FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [1] <feature name> — <last completed step or "Not started">
      🔗 <PR_URL if exists>

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
