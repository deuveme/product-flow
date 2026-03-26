---
description: "Internal — Called by /product-flow:build. Breaks the plan down into tasks and creates GitHub issues."
user_invocable: false
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 2. Gate: plan generated and pending comments resolved

Verify in the PR body:
- `- [x] Spec created` ✓
- `- [x] Plan generated` ✓

Invoke `/product-flow:pr-comments read-answers`. If it returns responses, apply them before delegating to `speckit.tasks`:
- `Question <N>. Correction:` responses → apply to `research.md` or `data-model.md`. Use the last response per question number.
- `Question <N>. Answer:` responses → incorporate as additional context in the delegation. Use the last response per question number.

Invoke `/product-flow:pr-comments pending`. If it returns pending comments:

```
🚫 BLOCKED — Pending comments

There are unanswered comments on the PR that must be resolved before generating the tasks.

Address them and run /product-flow:build again.
```

**STOP.**

### 3. Delegate to speckit.tasks

Invoke `/product-flow:speckit.tasks`, applying the following technical decision management rules:

**Autonomous resolution of ambiguities** — if during task generation questions arise about technical prioritisation, phase structure, task dependencies, or gaps in the available artifacts:

- **Do NOT ask the PM.** Make the most reasonable decision based on existing artifacts, the detected project stack and task organisation best practices.
- Record each AI-made decision internally as **AI-proposed decision**.
- If an ambiguity cannot be resolved: document it in `tasks.md` as a note and record it internally as **Unresolved question**.

`speckit.tasks` takes care of:
- Reading `spec.md`, `plan.md`, `data-model.md`, `contracts/`
- Generating `tasks.md` with tasks ordered by dependencies
- Organising by phases and user stories
- Marking parallelisable ones with `[P]`

**Wait for `speckit.tasks` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 4. Delegate to speckit.taskstoissues

Invoke `/product-flow:speckit.taskstoissues`.

`speckit.taskstoissues` takes care of:
- Reading `tasks.md`
- Creating one GitHub issue per task
- Linking the issues to the PR

**Wait for `speckit.taskstoissues` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 5. Record technical decisions in the PR

If during steps 3 or 4 there were technical decisions, add **one individual comment per decision** to the PR.

For each decision the AI was able to make, invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `ANSWERED`
- `body`:
  ```
  **Technical question detected:** "[identified question]"

  **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
  ```

For each decision the AI was unable to resolve (also documented in `tasks.md`), invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `UNANSWERED`
- `body`:
  ```
  **Technical question detected:** "[identified question]"

  **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  ⚠️ **Unresolved — requires input from the development team.**
  ```

If there were no relevant technical decisions, skip this step entirely.

### 6. Commit the tasks

```bash
git add specs/
git commit -m "docs: add tasks.md"
git push origin HEAD
```

### 7. Update PR status

Mark: `- [x] Tasks generated`

Add row:
```
| Tasks generated | YYYY-MM-DD | tasks.md + issues created |
```

```bash
gh pr edit --body "<updated-body>"
```

### 8. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after tasks phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 9. Final report

```
✅ Tasks generated

📋 tasks.md created
🎫 Issues created on GitHub
```

### Session close

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
