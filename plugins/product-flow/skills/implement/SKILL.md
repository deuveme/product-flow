---
description: "Generates the feature code using TDD."
user-invocable: false
model: sonnet
context: fork
effort: medium
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start-feature or /product-flow:start-improvement?"

### 2. Gate: tasks generated and technical corrections applied

Read `specs/<branch>/status.json` and verify that `SPEC_CREATED` and `PLAN_GENERATED` are present. For `TASKS_GENERATED`, accept either the flag in status.json OR the existence of `specs/<branch>/tasks.md` on disk (handles the case where tasks.md was committed but the status flag was not yet written):

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null | jq -e '.SPEC_CREATED, .PLAN_GENERATED' > /dev/null
TASKS_DONE=$(cat "specs/$BRANCH/status.json" 2>/dev/null | jq -e '.TASKS_GENERATED' > /dev/null && echo "true" || ([ -f "specs/$BRANCH/tasks.md" ] && echo "true" || echo "false"))
```

If `TASKS_DONE` is `false`:

```
🚫 BLOCKED

The tasks have not been generated yet.
Run /product-flow:continue first.
```

**STOP.**

Invoke `/product-flow:pr-comments pending`. If it returns any `UNANSWERED` comments:

```
🚫 There are unanswered questions on the PR that must be resolved before implementing.

Please reply on the PR (not in the chat) for each open question:

[list each question with its number, type, and a one-line summary]

  Question <N>. Answer: [letter or text]

Once all questions are answered, run /product-flow:build again.
```

**STOP.**

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

### 3. Verify clean repo state

```bash
git status --porcelain
```

If there are uncommitted changes:
```
⚠️  There are uncommitted changes.

These may be from a previous interrupted implementation run.
Run /product-flow:build — it will detect them and offer recovery options.
```
**STOP.**

### 4. Sync with main

```bash
git fetch origin
git rebase origin/main
```

If there are conflicts: ERROR "There are conflicts with main. The development team must resolve them before continuing."

### 5. Generate BDD approval fixtures

Read `research.md` to detect the project tech stack. If the stack is TypeScript or JavaScript, invoke `/product-flow:praxis.bdd-with-approvals` passing the contents of `spec.md` and `contracts/` as input. For other stacks (Python, Go, Java, etc.), skip this step — `speckit.implement.withTDD` will handle test scaffolding directly.

`praxis.bdd-with-approvals` writes approval fixture files before any implementation begins — each fixture is an executable specification in domain language that drives and validates the implementation.

**Wait for `praxis.bdd-with-approvals` to finish before continuing.**
If it produces an ERROR: propagate and stop.

### 6. Delegate to speckit.implement.withTDD

Invoke `/product-flow:speckit.implement.withTDD`.

`speckit.implement.withTDD` takes care of:
- Reading spec, plan, data-model, contracts and tasks
- Implementing the tasks in the correct order following Red-Green-Refactor TDD cycles
- Respecting the dependencies defined in tasks.md
- Making the approval fixtures from step 5 pass

**Wait for `speckit.implement.withTDD` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 7. Validate test quality

Invoke `/product-flow:praxis.test-desiderata` pointing to the test files generated in step 6.

`praxis.test-desiderata` evaluates the test suite against Kent Beck's 12 Test Desiderata properties and surfaces quality issues.

**Wait for `praxis.test-desiderata` to finish before continuing.**

- If it finds **critical issues** (e.g., tests that don't isolate behavior, brittle assertions, missing coverage of boundary cases): fix them before proceeding.
- If there are no critical issues: continue silently.

### 7b. Adversarial coverage pass

Invoke `/product-flow:bugmagnet`.

`bugmagnet` applies exploratory testing heuristics (boundaries, error conditions, state transitions, authorization, CRUD matrix, data quality, concurrency) to find test cases not covered by the existing suite.

**Wait for `bugmagnet` to finish before continuing.**

- HIGH priority cases: written automatically as new tests — commit them alongside the implementation.
- MEDIUM / LOW cases: reported for the developer to decide in code review. No action required before continuing.

### 8. Update status.json

Write `CODE_WRITTEN` to `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"CODE_WRITTEN": $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record code_written in status.json"
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:build again.
```
**STOP.**

Invoke `/product-flow:safe-push`.

Do **not** check `- [x] Code generated` in the PR body — that is set by `/product-flow:build` after verify-tasks passes.

Read the current PR body first (`gh pr view --json body -q '.body'`). If the output is empty, stop with ERROR "Could not read PR body — check GitHub access and try again." Then add only this row to `## History` — preserve all other sections intact:

```
| Code written | YYYY-MM-DD HH:MM:SS | @github-user | speckit.implement.withTDD + praxis.test-desiderata completed |
```

```bash
gh pr edit --body "<updated-body>"
```

### 9. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after implement phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 10. Transition to verify-tasks

> **Entry condition for this step**: runs after `speckit.implement.withTDD` completes normally (not skipped).

After the retro completes, continue to step 11.

### 11. Final report

```
✅ Code generated
```

### Session close

Invoke `/product-flow:context`.
