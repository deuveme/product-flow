---
description: "Integrates team feedback into the technical plan."
user-invocable: false
---

## Execution

### 1. Verify state

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
Read `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
```

Verify that `plan_generated` is present. If missing: ERROR "Plan has not been generated yet. Run /product-flow:continue first."

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

> ℹ️  Any technical feedback in the same batch is not lost — it will be processed automatically on the next run once the product feedback is resolved.

**STOP.**

If all comments are technical, group them by affected artifact:
- `research.md` — architecture decisions, approach changes, technology choices, constraint updates
- `data-model.md` — entity or relationship corrections
- `contracts/` — API or interface modifications

### 3. Apply corrections

For each piece of technical feedback, update the relevant artifact:

- **Answers** (`Question <N>. Answer: ...`): Apply to the relevant artifact — override if the comment was an autonomous decision, resolve if it was an open question. Update the artifact and add a note: `<!-- Updated: <date> — team answer -->`. If multiple answers exist for the same question number, use the last one.
- **General feedback**: Interpret intent, apply changes conservatively, and note what was changed.

Do NOT modify `tasks.md` here — if plan changes invalidate tasks, note it in the commit message so `/product-flow:tasks` can be re-run.

### 4. Validate consistency

After applying corrections, verify:
- `data-model.md` is consistent with updated `plan.md`
- `contracts/` reflect any entity or field changes
- No `[NEEDS CLARIFICATION]` markers remain in plan artifacts

If inconsistencies are found, resolve them before committing using these rules:

| Inconsistency type | Resolution |
|--------------------|------------|
| Entity field in `data-model.md` not reflected in `contracts/` | Add or update the field in the affected contract file to match the data model |
| Contract endpoint references an entity not in `data-model.md` | Add the missing entity to `data-model.md`, or remove it from the contract if it was a mistake |
| `[NEEDS CLARIFICATION]` marker in `plan.md` or `research.md` | Apply the team's answer from the PR comment, or make the most reasonable technical decision and document it |
| Field renamed in one artifact but not in others | Apply the rename consistently across all affected artifacts (plan, data-model, contracts) |
| Conflicting cardinality (e.g., one-to-many vs many-to-many) | Use the team feedback's direction; if absent, use the data-model as the source of truth |

If an inconsistency cannot be resolved without PM input, stop and surface it as a non-technical question before committing.

### 5. Commit and push

```bash
git add specs/<feature-dir>/plan.md specs/<feature-dir>/research.md specs/<feature-dir>/data-model.md specs/<feature-dir>/contracts/
git commit -m "plan: integrate team feedback"
git push origin HEAD
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:continue again.
```
**STOP.**

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

Invoke `/product-flow:context`.
