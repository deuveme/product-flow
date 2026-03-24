---
description: "STEP 2 — Integrates team feedback into the spec. Run after they have commented on the PR. Repeatable."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /status."
- If there is no PR: ERROR "There is no open PR. Did you run /start?"

### 2. Gate: spec created

Verify in the PR body: `- [x] Spec created`

If not marked: ERROR "The spec does not exist yet. Run /start first."

### 3. Verify comments and collect team corrections

```bash
gh pr view --json comments -q '.comments[].body'
```

If there are no comments: ERROR "There are no comments on the PR yet. Share the PR with the team and wait for their feedback."

Also look for team comments that are corrections or responses to previous technical decisions (comments starting with `Correction:` or `Answer:`). If there are any, record them internally — they will be incorporated as additional context in step 4 when invoking `speckit.clarify`.

### 4. Delegate to speckit.clarify

Invoke `/speckit.clarify` with the context of the PR comments, applying the following question management rules:

**Question classification** — before presenting each question, classify it:

- **Non-technical** (ask the PM): business intent, priorities, user flow, terminology, functional scope.
- **Technical** (resolve autonomously): architecture, performance, security, integrations, data model, infrastructure constraints, implementation patterns.

**For technical questions**, do NOT ask the PM. Instead:
1. Try to answer them using project context: existing code, `.agents/rules/base.md`, project stack (Python/FastAPI + TypeScript/Node 22), detected architecture patterns.
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

If during the previous step there were technical questions, add **one individual comment per question** to the PR.

For each question the AI was able to answer:

```bash
gh pr comment --body "**Technical question detected:** \"[identified question]\"

**Proposed answers:** A. \"[option A]\" B. \"[option B]\" C. \"[option C]\"

**Autonomously chosen answer:** We chose \"[chosen option]\" because \"[brief reasoning]\"

> 💬 If you want to change this decision, reply with: \`Correction: [letter or answer]\`"
```

For each question the AI was unable to resolve:

```bash
gh pr comment --body "**Technical question detected:** \"[identified question]\"

**Possible answers:** A. \"[option A]\" B. \"[option B]\" C. \"[option C]\"

⚠️ **Unresolved — requires input from the development team.**

> 💬 To answer, comment with: \`Answer: [letter or answer]\`"
```

If there were no technical questions at all, skip this step entirely.

### 6. Commit the updated spec

```bash
git add specs/
git commit -m "docs: update spec with team feedback"
git push origin HEAD
```

### 7. Update PR history

Add row to the table:
```
| Spec revised | YYYY-MM-DD | Feedback integrated via speckit.clarify |
```

```bash
gh pr edit --body "<updated-body>"
```

### 8. Phase retro

Invoke `/speckit.retro` with context: "after clarify phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 9. Final report

```
✅ Spec updated

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
If there are more feedback rounds:
  Run /consolidate-spec again

If the spec is ready for approval:
  Ask the team to approve the spec in the PR.
  When they do, run: /plan
─────────────────────────────────────────
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
