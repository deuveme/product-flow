---
description: "Integrates team feedback on the technical plan. Reads PR comments, applies corrections to plan.md, research.md, data-model.md, and contracts/, then commits the updated artifacts."
---

## Execution

### 1. Verify state

```bash
git branch --show-current
gh pr view --json number,state,url,body,comments -q '{body: .body, comments: [.comments[].body]}'
```

- If branch is `main` or `master`: ERROR "Not on a feature branch."
- Verify `- [x] Plan generated` is marked. If not: ERROR "Plan has not been generated yet. Run /continue first."

### 2. Collect pending comments

Invoke `/pr-comments pending`.

If it returns `NO_PENDING_COMMENTS`: show a warning and stop:

```
⚠️  No pending plan feedback found in the PR comments.
    Nothing to consolidate.
```

From the returned comments, identify those related to the plan (`Correction:`, `Answer:`, or general feedback on plan.md / data-model.md / contracts/). Group them by affected artifact:
- `research.md` — architecture decisions, approach changes, technology choices, constraint updates
- `data-model.md` — entity or relationship corrections
- `contracts/` — API or interface modifications

### 3. Apply corrections

For each piece of feedback, update the relevant artifact:

- **Corrections** (`Correction: ...`): Override the previous decision with the team's direction. Update the artifact and add a note: `<!-- Updated: <date> — team correction -->`
- **Answers** (`Answer: ...`): Resolve the open question in research.md. Mark the question as resolved.
- **General feedback**: Interpret intent, apply changes conservatively, and note what was changed.

Do NOT modify `tasks.md` here — if plan changes invalidate tasks, note it in the commit message so `/tasks` can be re-run.

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

### 6. Acknowledge processed comments

Invoke `/pr-comments ack` passing for each comment what was done (change applied, artifact updated, or reason it was not applied).

**Wait for `/pr-comments ack` to finish before continuing.**

### 7. Phase retro

Invoke `/speckit.retro` with context: "after consolidate-plan phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 8. Final report

```
✅ Plan feedback consolidated

Changes applied:
  <summary of what changed>
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
