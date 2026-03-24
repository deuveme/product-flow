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

### 2. Read pending feedback

```bash
gh pr view --json comments -q '.comments[].body'
```

Identify comments that:
- Are corrections or questions from the team about the plan (`Correction:`, `Answer:`, or general feedback on plan.md / data-model.md / contracts/)
- Have not yet been incorporated into the plan artifacts

Group feedback by affected artifact:
- `plan.md` — architecture decisions, approach changes
- `research.md` — technology choices, constraint updates
- `data-model.md` — entity or relationship corrections
- `contracts/` — API or interface modifications

If there is no actionable feedback on the plan: show a warning and stop:

```
⚠️  No pending plan feedback found in the PR comments.
    Nothing to consolidate.
```

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

### 5. Commit

```bash
git add specs/<feature-dir>/plan.md specs/<feature-dir>/research.md specs/<feature-dir>/data-model.md specs/<feature-dir>/contracts/
git commit -m "plan: integrate team feedback"
```

### 6. Record in PR

Add a PR comment summarizing what changed:

```bash
gh pr comment --body "Plan updated based on team feedback:
- [list of changes made, one per line]"
```

### 7. Final report

```
✅ Plan feedback consolidated

Changes applied:
  <summary of what changed>

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Share the updated plan with the team for approval.
When they approve, run: /continue
─────────────────────────────────────────
```
