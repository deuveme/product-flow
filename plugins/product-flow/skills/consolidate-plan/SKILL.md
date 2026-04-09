---
description: "Integrates team feedback into the technical plan."
user-invocable: false
model: sonnet
effort: medium
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

- **Product** (scope changes, priority shifts, business rule clarifications, terminology): resolve via **AskUserQuestion** — never apply product changes autonomously.
- **Technical** (architecture corrections, data model adjustments, API changes, implementation decisions): resolve autonomously.

If there are product comments, use the **AskUserQuestion** tool to ask the PM in a **single call**:
- One entry per product comment:
  - `question`: describe the team's feedback and ask what to do, ending with "?"
  - `header`: short topic label max 12 chars
  - `options`: 2–4 choices with `description` explaining each. Place the recommended option first with `" (Recommended)"`. Include a "Leave as is" option.
  - `multiSelect`: false

Wait for all PM answers before proceeding. Then for each answered product item, post a PR comment via `/product-flow:pr-comments write` with:
- `type`: `product`, `status`: `ANSWERED`
- `body`:
  ```
  **Product feedback:** "[the team's original comment]"

  **Options:** A. "[option A]" B. "[option B]" (... etc)

  **PM answer:** "[the answer received]"

  **Change applied:** [what was updated in the plan, or "no change — decision recorded"]
  ```

**Detect conflicting comments before acting:**

Scan all collected comments for contradictions: two or more items that affect the same plan artifact or section with incompatible intent (e.g. "switch to event sourcing" vs "keep the current CRUD approach", or a product comment and a technical comment that imply opposite data model shapes).

For each conflict found:
- Do **not** apply either side autonomously.
- Include it in the **AskUserQuestion** call as an additional entry, presenting both sides and asking the PM which direction takes precedence.

If no conflicts are detected: continue silently.

Group all comments (technical and product) by affected artifact:
- `research.md` — architecture decisions, approach changes, technology choices, constraint updates
- `data-model.md` — entity or relationship corrections
- `contracts/` — API or interface modifications

### 3. Apply corrections

For each piece of technical feedback, show before applying:
```
  ⏳ Question <N> — <one-line summary> → applying to <artifact>...
```

Then update the relevant artifact:

- **Answers** (`Question <N>. Answer: ...`): Apply to the relevant artifact — override if the comment was an autonomous decision, resolve if it was an open question. Update the artifact and add a note: `<!-- Updated: <date> — team answer -->`. If multiple answers exist for the same question number, use the last one.
- **General feedback**: Interpret intent, apply changes conservatively, and note what was changed.

After applying each item, show:
```
  ✅ Question <N> — applied to <artifact>.
```

After all are processed, show: `✅ <N> item(s) applied.`

Do NOT modify `tasks.md` here — if plan changes invalidate tasks, note it in the commit message so `/product-flow:tasks` can be re-run.

After applying all answers, invoke `/product-flow:pr-comments mark-processed` with the question numbers of all applied answers (e.g. `1 3`).

### 3b. Record applied changes in the PR

For each technical change applied in step 3, invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `ANSWERED`
- `body`:
  ```
  **Technical question detected:** "[the team's feedback or question]"

  **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
  ```

Skip if no changes were applied (no feedback to process).

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
git add specs/<feature-dir>/
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

### 6b. Update PR history

Read the current PR body first (`gh pr view --json body -q '.body'`), then add only this row to the `## History` table — preserve all other sections intact:

```
| Plan revised | YYYY-MM-DD | Feedback integrated via consolidate-plan |
```

```bash
gh pr edit --body "<updated-body>"
```

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
