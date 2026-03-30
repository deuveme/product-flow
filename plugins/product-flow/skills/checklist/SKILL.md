---
description: "Validates requirements quality before implementation starts."
user-invocable: false
---

## Purpose

Generates a checklist that validates that the spec, plan and tasks are well written, complete and free of ambiguities. If critical issues are found (gaps, conflicts, or ambiguities that would break implementation), `/product-flow:build` will stop and ask the PM to resolve them before continuing.

Remember: the checklist validates the **requirements**, not the code. It is a "unit test of the spec written in English".

---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 2. Verify there is something to review

Confirm that at least `spec.md` exists in the feature directory.

```bash
ls specs/<branch-directory>/
```

If there is no spec: ERROR "There is no spec to review. Run /product-flow:start first."

### 3. Delegate to speckit.checklist

Invoke `/product-flow:speckit.checklist` with the context of the current phase.

`speckit.checklist` takes care of:
- Detecting which artifacts are available (spec, plan, tasks)
- Asking clarification questions about the checklist approach
- Generating the file in `specs/<directory>/checklists/<domain>.md`
- Validating completeness, clarity, consistency, measurability, coverage

**Wait for `speckit.checklist` to finish completely before continuing.**

### 4. Commit the checklist

```bash
git add specs/
git commit -m "docs: add requirements checklist"
git push origin HEAD
```

### 5. Final report

```
✅ Checklist generated

📋 <path-to-checklist>

Review items marked as [Gap], [Ambiguity]
or [Conflict] before continuing.
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
