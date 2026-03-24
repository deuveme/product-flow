---
description: "STEP 4 — Breaks the plan down into tasks and creates the issues on GitHub. Run when the team has approved the plan."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /status."
- If there is no PR: ERROR "There is no open PR. Did you run /start?"

### 2. Gate: plan approved and technical corrections applied

Verify in the PR body:
- `- [x] Spec created` ✓
- `- [x] Spec approved by the development team` ✓
- `- [x] Plan generated` ✓
- `- [x] Plan approved by the development team` ✓

Also, read the PR comments looking for corrections or team responses to previous technical decisions (comments starting with `Correction:` or `Answer:`):

```bash
gh pr view --json comments -q '.comments[].body'
```

If there are corrections: apply them in `research.md` or `plan.md` before delegating to `speckit.tasks`. If there are responses to unresolved questions: incorporate them as additional context in the delegation.

If the plan approval is not marked:

```
🚫 BLOCKED

The plan has not been approved yet.

The development team must approve the plan
in the PR before generating the tasks.
```

**STOP.**

Verify that there are no unanswered technical decisions: among the PR comments, identify all those containing "Unresolved — requires input from the development team" and check that for each one there is a subsequent comment starting with `Answer:`.

If any technical decision has no team response:

```
🚫 BLOCKED — Unanswered technical decisions

The following technical questions must be answered before generating the tasks:

[list the unanswered questions]

The team must answer in the PR with:
  Answer: [letter or answer]
```

**STOP.**

### 3. Delegate to speckit.tasks

Invoke `/speckit.tasks`, applying the following technical decision management rules:

**Autonomous resolution of ambiguities** — if during task generation questions arise about technical prioritisation, phase structure, task dependencies, or gaps in the available artifacts:

- **Do NOT ask the PM.** Make the most reasonable decision based on existing artifacts, the project stack (Python/FastAPI + TypeScript/Node 22) and task organisation best practices.
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

Invoke `/speckit.taskstoissues`.

`speckit.taskstoissues` takes care of:
- Reading `tasks.md`
- Creating one GitHub issue per task
- Linking the issues to the PR

**Wait for `speckit.taskstoissues` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 5. Record technical decisions in the PR

If during steps 3 or 4 there were technical decisions, add **one individual comment per decision** to the PR.

For each decision the AI was able to make:

```bash
gh pr comment --body "**Technical question detected:** \"[identified question]\"

**Proposed answers:** A. \"[option A]\" B. \"[option B]\" C. \"[option C]\"

**Autonomously chosen answer:** We chose \"[chosen option]\" because \"[brief reasoning]\"

> 💬 If you want to change this decision, reply with: \`Correction: [letter or answer]\`"
```

For each decision the AI was unable to resolve (also documented in `tasks.md`):

```bash
gh pr comment --body "**Technical question detected:** \"[identified question]\"

**Possible answers:** A. \"[option A]\" B. \"[option B]\" C. \"[option C]\"

⚠️ **Unresolved — requires input from the development team.**

> 💬 To answer, comment with: \`Answer: [letter or answer]\`"
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

Invoke `/speckit.retro` with context: "after tasks phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 9. Final report

```
✅ Tasks generated

📋 tasks.md created
🎫 Issues created on GitHub

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /build

It will validate requirements quality and
generate the feature code.
─────────────────────────────────────────
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
