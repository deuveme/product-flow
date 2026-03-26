---
description: "Internal — Called by /product-flow:build. Generates the feature code using TDD."
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

### 2. Gate: tasks generated and technical corrections applied

Verify in the PR body:
- `- [x] Spec created` ✓
- `- [x] Plan generated` ✓
- `- [x] Tasks generated` ✓

Invoke `/product-flow:pr-comments read-answers`. If it returns responses, apply them before delegating to `speckit.implement.withTDD`:
- `Question <N>. Correction:` responses → apply to `tasks.md` or affected artifacts. Use the last response per question number.
- `Question <N>. Answer:` responses → incorporate as additional context in the delegation. Use the last response per question number.

If the tasks have not been generated:

```
🚫 BLOCKED

The tasks have not been generated yet.
Run /product-flow:tasks first.
```

**STOP.**

Invoke `/product-flow:pr-comments pending`. If it returns any `UNANSWERED` comments with no corresponding `Question <N>. Answer:` response from the user:

```
🚫 BLOCKED — Unanswered technical decisions

The following technical questions must be answered before implementing:

[list the unanswered questions with their Question number]

Add a new comment to the PR for each:
  Question <N>. Answer: [letter or answer]
```

**STOP.**

### 3. Verify clean repo state

```bash
git status --porcelain
```

If there are uncommitted changes: ERROR "There are unsaved changes. Commit them before implementing."

### 4. Sync with main

```bash
git fetch origin
git rebase origin/main
```

If there are conflicts: ERROR "There are conflicts with main. The development team must resolve them before continuing."

### 5. Generate BDD approval fixtures

Invoke `/product-flow:praxis.bdd-with-approvals` passing the contents of `spec.md` and `contracts/` as input.

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

### 8. Update PR status

Mark: `- [x] Code generated`

Add row:
```
| Code generated | YYYY-MM-DD | speckit.implement.withTDD + praxis.test-desiderata completed |
```

```bash
gh pr edit --body "<updated-body>"
```

### 9. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after implement phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 10. Final report

```
✅ Code generated
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
