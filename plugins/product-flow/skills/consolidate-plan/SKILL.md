---
description: "Integrates team feedback into the technical plan."
user-invocable: false
---

## Execution

### 1. Verify state

```bash
git branch --show-current
gh pr view --json number,state,url,body,comments -q '{body: .body, comments: [.comments[].body]}'
```

- If branch is `main` or `master`: ERROR "Not on a feature branch."
- Verify `- [x] Plan generated` is marked. If not: ERROR "Plan has not been generated yet. Run /product-flow:continue first."

### 2. Collect pending comments

Invoke `/product-flow:pr-comments pending` and `/product-flow:pr-comments read-answers`.

If both return empty: show a warning and stop:

```
⚠️  No pending plan feedback found in the PR comments.
    Nothing to consolidate.
```

From the returned comments and answers, classify each one before acting on it:

- **Non-technical** (product feedback): scope changes, priority shifts, business rule clarifications, terminology. **NEVER resolve autonomously.**
- **Technical** (resolve autonomously): architecture corrections, data model adjustments, API changes, implementation decisions.

If any comment is non-technical, stop immediately and surface it to the PM:

```
🚫 Product feedback detected in the PR comments.

The following must be answered by the PM before the plan can be updated:

[list each non-technical comment]

Please reply on the PR with your answer. Then run /product-flow:continue again.
```

**STOP.**

If all comments are technical, group them by affected artifact:
- `research.md` — architecture decisions, approach changes, technology choices, constraint updates
- `data-model.md` — entity or relationship corrections
- `contracts/` — API or interface modifications

### 3. Apply corrections

For each piece of technical feedback, update the relevant artifact:

- **Corrections** (`Question <N>. Correction: ...`): Override the previous decision with the team's direction. Update the artifact and add a note: `<!-- Updated: <date> — team correction -->`. If multiple corrections exist for the same question number, use the last one.
- **Answers** (`Question <N>. Answer: ...`): Resolve the open question in research.md. Mark the question as resolved. If multiple answers exist for the same question number, use the last one.
- **General feedback**: Interpret intent, apply changes conservatively, and note what was changed.

Do NOT modify `tasks.md` here — if plan changes invalidate tasks, note it in the commit message so `/product-flow:tasks` can be re-run.

### 4. Validate consistency

After applying corrections, verify:
- `data-model.md` is consistent with updated `plan.md`
- `contracts/` reflect any entity or field changes
- No `[NEEDS CLARIFICATION]` markers remain in plan artifacts

If inconsistencies are found: resolve them before committing.

### 5. Commit and push

```bash
git add specs/<feature-dir>/plan.md specs/<feature-dir>/research.md specs/<feature-dir>/data-model.md specs/<feature-dir>/contracts/
git commit -m "plan: integrate team feedback"
git push origin HEAD
```

### 6. Resolve processed comments

Invoke `/product-flow:pr-comments resolve` passing the IDs of all bot comments that had `UNANSWERED` status and have now been addressed.

**Wait for `/product-flow:pr-comments resolve` to finish before continuing.**

### 7. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after consolidate-plan phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 8. Final report

```
✅ Plan feedback consolidated

Changes applied:
  <summary of what changed>
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
