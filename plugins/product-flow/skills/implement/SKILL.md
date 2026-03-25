---
description: "Internal — Called by /build. Generates the feature code using TDD."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /status."
- If there is no PR: ERROR "There is no open PR. Did you run /start?"

### 2. Gate: tasks generated and technical corrections applied

Verify in the PR body:
- `- [x] Spec created` ✓
- `- [x] Spec approved by the development team` ✓
- `- [x] Plan generated` ✓
- `- [x] Plan approved by the development team` ✓
- `- [x] Tasks generated` ✓

Also, read the PR comments looking for corrections or team responses to previous technical decisions (comments starting with `Correction:` or `Answer:`):

```bash
gh pr view --json comments -q '.comments[].body'
```

If there are corrections: apply them in `tasks.md` or the affected artifacts before delegating to `speckit.implement.withTDD`. If there are responses to unresolved questions: incorporate them as additional context in the delegation.

If the tasks have not been generated:

```
🚫 BLOCKED

The tasks have not been generated yet.
Run /tasks first.
```

**STOP.**

Verify that there are no unanswered technical decisions: among the PR comments, identify all those containing "Unresolved — requires input from the development team" and check that for each one there is a subsequent comment starting with `Answer:`.

If any technical decision has no team response:

```
🚫 BLOCKED — Unanswered technical decisions

The following technical questions must be answered before implementing:

[list the unanswered questions]

The team must answer in the PR with:
  Answer: [letter or answer]
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

Invoke `/praxis.bdd-with-approvals` passing the contents of `spec.md` and `contracts/` as input.

`praxis.bdd-with-approvals` writes approval fixture files before any implementation begins — each fixture is an executable specification in domain language that drives and validates the implementation.

**Wait for `praxis.bdd-with-approvals` to finish before continuing.**
If it produces an ERROR: propagate and stop.

### 6. Delegate to speckit.implement.withTDD

Invoke `/speckit.implement.withTDD`.

`speckit.implement.withTDD` takes care of:
- Reading spec, plan, data-model, contracts and tasks
- Implementing the tasks in the correct order following Red-Green-Refactor TDD cycles
- Respecting the dependencies defined in tasks.md
- Making the approval fixtures from step 5 pass

**Wait for `speckit.implement.withTDD` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 7. Validate test quality

Invoke `/praxis.test-desiderata` pointing to the test files generated in step 6.

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

Invoke `/speckit.retro` with context: "after implement phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 10. Final report

```
✅ Code generated
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
