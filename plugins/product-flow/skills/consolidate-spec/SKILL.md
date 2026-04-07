---
description: "Integrates team feedback into the spec."
user-invocable: false
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /product-flow:status."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 2. Gate: spec created

Read `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
```

Verify that `spec_created` is present. If missing: ERROR "The spec does not exist yet. Run /product-flow:start first."

### 3. Collect pending comments

Invoke `/product-flow:pr-comments pending`.

If it returns `NO_PENDING_COMMENTS`: ERROR "There are no pending comments on the PR. Share the PR with the team and wait for their feedback."

Also invoke `/product-flow:pr-comments read-answers`. Record both the pending comments and the user responses internally — they will be used as context in step 4. User responses follow the format `Question <N>. Answer:` — for each question, only the last response counts.

After applying in step 4, invoke `/product-flow:pr-comments mark-processed` with the commentIds of all applied answers.

### 4. Delegate to speckit.clarify

Invoke `/product-flow:speckit.clarify` with the context of the PR comments, applying the following question management rules:

**Question classification** — before presenting each question, classify it:

- **Non-technical** (ask the PM): business intent, priorities, user flow, terminology, functional scope. **NEVER resolve autonomously. Always surface to the PM and wait for their answer.**
- **Technical** (resolve autonomously): architecture, performance, security, integrations, data model, infrastructure constraints, implementation patterns.

**For technical questions**, do NOT ask the PM. Instead:
1. Try to answer them using project context: existing code, `.agents/rules/base.md`, detected project stack, detected architecture patterns.
2. If there is sufficient information to answer with confidence: make the decision and record it internally as **AI-proposed decision**.
3. If there is not sufficient information: record it internally as **Unresolved question** and continue.

Save the list of all technical decisions (resolved and unresolved) internally for the next step.

`speckit.clarify` takes care of:
- Reading the current spec
- Processing the necessary clarifications
- Updating `spec.md` with the decisions made

**Wait for `speckit.clarify` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 5. Record technical decisions in the PR

For each technical decision made, invoke `/product-flow:pr-comments write`
following the technical decision format (ANSWERED/UNANSWERED).
Skip if no technical decisions were made.

### 6. Commit the updated spec

```bash
git add specs/
git commit -m "docs: update spec with team feedback"
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

### 7. Resolve processed comments

Invoke `/product-flow:pr-comments resolve` passing the IDs of all bot comments that had `UNANSWERED` status and have now been addressed.

**Wait for `/product-flow:pr-comments resolve` to finish before continuing.**

### 8. Update PR history

Add row to the table:
```
| Spec revised | YYYY-MM-DD | Feedback integrated via speckit.clarify |
```

```bash
gh pr edit --body "<updated-body>"
```

### 9. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after clarify phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 10. Final report

```
✅ Spec updated
```

### Session close

Invoke `/product-flow:context`.
