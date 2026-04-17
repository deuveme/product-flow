---
description: "Validates requirements quality before implementation starts."
user-invocable: false
model: haiku
effort: medium
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
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start-feature or /product-flow:start-improvement?"

### 2. Verify there is something to review

Confirm that at least `spec.md` exists in the feature directory.

```bash
ls specs/<branch-directory>/
```

If there is no spec: ERROR "There is no spec to review. Run /product-flow:start-feature or /product-flow:start-improvement first."

### 2b. Check for unanswered PR questions

Invoke `/product-flow:pr-comments pending`. If it returns any `UNANSWERED` comments:

```
🚫 There are unanswered questions on the PR that must be resolved before running the checklist.

Please reply on the PR for each open question, then run /product-flow:continue again.
```

**STOP.**

### 3. Delegate to speckit.checklist

Invoke `/product-flow:speckit.checklist` with the context of the current phase.

`speckit.checklist` takes care of:
- Detecting which artifacts are available (spec, plan, tasks)
- Asking clarification questions about the checklist approach
- Generating the file in `specs/<directory>/checklists/<domain>.md`
- Validating completeness, clarity, consistency, measurability, coverage

**Wait for `speckit.checklist` to finish completely before continuing.**

### 4. Commit the checklist

Write to `specs/<branch>/status.json` before committing:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"CHECKLIST_DONE": $ts}' > "$STATUS_FILE"
```

```bash
git add specs/
git commit -m "docs: add requirements checklist"
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

### 5. Final report

```
✅ Checklist generated

📋 <path-to-checklist>

Review items marked as [Gap], [Ambiguity]
or [Conflict] before continuing.
```

### 6. Session close

Invoke `/product-flow:context`.
