---
description: "Breaks the plan into tasks."
user-invocable: false
model: sonnet
effort: medium
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

Read `specs/<branch>/status.json` and verify that `SPEC_CREATED` and `PLAN_GENERATED` are present:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null | jq -e '.SPEC_CREATED, .PLAN_GENERATED' > /dev/null
```

Invoke `/product-flow:pr-comments read-answers`.

Show: `📬 Reading PR answers...`

For each new answer found, show before applying:
```
  ⏳ Question <N> — <one-line summary of the question> → applying to <artifact>...
```
Apply it, then show:
```
  ✅ Question <N> — applied.
```

After all answers are processed, show: `✅ <N> answer(s) applied.` (or `No new answers found.` if none).

After applying, invoke `/product-flow:pr-comments mark-processed` with the question numbers of all applied answers (e.g. `1 3`).

Invoke `/product-flow:pr-comments pending`. If it returns pending comments, resolve them before continuing:

- For `type: technical` comments: attempt autonomous resolution using project context and industry standards. Invoke `/product-flow:pr-comments write` with `status: ANSWERED` and mark as resolved via `/product-flow:pr-comments resolve`.
- For `type: product` comments: use **AskUserQuestion** to ask the PM in a single call (one entry per comment). After receiving the PM's answers, post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`.

Only after all pending comments are resolved, continue.

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

After `speckit.tasks` completes, verify that `tasks.md` was actually written to disk:

```bash
BRANCH=$(git branch --show-current)
ls "specs/$BRANCH/tasks.md"
```

If the file does not exist: ERROR "tasks.md was not created by speckit.tasks. Re-run /product-flow:build to try again." **STOP.**

### 4. Record technical decisions in the PR

For each technical decision made, invoke `/product-flow:pr-comments write`:

- If resolved:
  - `type`: `technical`, `status`: `ANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
    ```
- If unresolved:
  - `type`: `technical`, `status`: `UNANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    ⚠️ **Unresolved — requires input from the development team.**
    ```

Skip if no technical decisions were made.

### 5. Commit the tasks

Write `TASKS_GENERATED` to `specs/<branch>/status.json` before committing:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"TASKS_GENERATED": $ts}' > "$STATUS_FILE"
```

Then commit tasks and the updated status in a single commit:

```bash
git add specs/
git commit -m "docs: add tasks.md"
git push origin HEAD
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:build again.
```
**STOP.**

### 6. Update PR status

Mark: `- [x] Tasks generated`

Add row:
```
| Tasks generated | YYYY-MM-DD HH:MM:SS | @github-user | tasks.md created |
```

Read the current PR body first (`gh pr view --json body -q '.body'`), then apply these changes to it:
- Mark `- [x] Tasks generated` in `## Status`
- Add the history row to `## History`
- Inside `<!-- dev-checklist -->` ... `<!-- /dev-checklist -->`: replace **only** the `- [ ] **Tasks** — pending` line with the filled-in Tasks line followed by the full task table grouped by phase. Do not touch the Spec or Plan lines already in the block.
- Preserve all other sections intact

Example (only the Tasks line and what follows it changes — Spec and Plan lines above remain as-is):
```
<!-- dev-checklist -->
- [x] **Spec** — <already filled in, do not modify>
- [x] **Plan** — <already filled in, do not modify>
- [x] **Tasks** — <N> tasks · <M> phases

  **Phase 1 — Setup**
  | Task | Description | Status |
  |------|-------------|--------|
  | T001 | <description> | TO DO |

  **Phase 2 — Foundational**
  | Task | Description | Status |
  |------|-------------|--------|
  | T002 | <description> | TO DO |
- [ ] **Implementation** — pending
<!-- /dev-checklist -->
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
