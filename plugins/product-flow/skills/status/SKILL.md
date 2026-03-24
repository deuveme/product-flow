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

Then run /status again.
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

Then run /status again.
```

### 1. Gather status

```bash
git branch --show-current
git status --porcelain
gh pr view --json number,title,state,isDraft,url,body,reviewDecision 2>/dev/null || echo "NO_PR"
```

### 2. Interpret and display

**Case: on main with no active feature**
```
📍 You are on the main branch, with no active feature.

To start a feature:
  /start <description>
```

**Case: on a feature branch with PR**

Read the PR checkboxes and determine the last completed step.
For each step, determine its status according to this logic:
- ✅ if the checkbox is marked
- ▶️  if it is the next one executable right now (previous steps complete)
- ⏳ if it is pending an external action (team approval)
- 🔒 if it is blocked because previous steps are not complete

```
📍 Active feature: <BRANCH_NAME>
🔗 PR: <PR_URL>

PROGRESS:
  ✅ Spec created
  ✅ Spec approved
  ✅ Plan generated
  ⏳ Plan approved by the team      ← team must approve on GitHub
  🔒 Tasks generated
  🔒 Code generated
  🔒 In code review
  🔒 Published

➡️  NEXT
    When the team approves the plan on GitHub, run:
    /build
```

### 3. Unsaved changes

If `git status --porcelain` returns changes:
```
⚠️  There are unsaved changes on your branch.
    They will be saved on the next /submit.
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
