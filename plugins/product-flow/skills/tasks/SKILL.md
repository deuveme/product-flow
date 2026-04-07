---
description: "Breaks the plan into tasks."
user-invocable: false
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

### 4. Record technical decisions in the PR

For each technical decision made, invoke `/product-flow:pr-comments write`
following the technical decision format (ANSWERED/UNANSWERED).
Skip if no technical decisions were made.

### 5. Commit the tasks

```bash
git add specs/
git commit -m "docs: add tasks.md"
git push origin HEAD
```

### 6. Update PR status

Mark: `- [x] Tasks generated`

Add row:
```
| Tasks generated | YYYY-MM-DD | tasks.md created |
```

Update the Dev Checklist block: replace the `<!-- dev-checklist -->` ... `<!-- /dev-checklist -->` section with the Tasks line filled in, followed by the full task table grouped by phase. Each task starts with status `TO DO`.

Example:
```
- [x] **Tasks** — <N> tasks · <M> phases

  **Phase 1 — Setup**
  | Task | Description | Status |
  |------|-------------|--------|
  | T001 | <description> | TO DO |

  **Phase 2 — Foundational**
  | Task | Description | Status |
  |------|-------------|--------|
  | T002 | <description> | TO DO |

  **Phase 3 — <US label>: <story name>**
  | Task | Description | Status |
  |------|-------------|--------|
  | T003 | <description> | TO DO |
```

```bash
gh pr edit --body "<updated-body>"
```

### 7. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after tasks phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 8. Final report

```
✅ Feature broken down into tasks

The work has been organized and is ready to be built.
Run /product-flow:build to start the implementation.
```

### 9. Session close

Invoke `/product-flow:context`.
