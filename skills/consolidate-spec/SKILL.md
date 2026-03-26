---
description: "Internal — Called by /continue. Integrates team feedback into the spec. Repeatable."
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

### 3. Collect pending comments

Invoke `/pr-comments pending`.

If it returns `NO_PENDING_COMMENTS`: ERROR "There are no pending comments on the PR. Share the PR with the team and wait for their feedback."

Also invoke `/pr-comments read-answers`. Record both the pending comments and the user responses internally — they will be used as context in step 4. User responses follow the format `Question <N>. Correction:` or `Question <N>. Answer:` — for each question, only the last response counts.

### 4. Delegate to speckit.clarify

Invoke `/speckit.clarify` with the context of the PR comments, applying the following question management rules:

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

If during the previous step there were technical questions, add **one individual comment per question** to the PR.

For each question the AI was able to answer, invoke `/pr-comments write` with:
- `type`: `technical`
- `status`: `ANSWERED`
- `body`:
  ```
  **Technical question detected:** "[identified question]"

  **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
  ```

For each question the AI was unable to resolve, invoke `/pr-comments write` with:
- `type`: `technical`
- `status`: `UNANSWERED`
- `body`:
  ```
  **Technical question detected:** "[identified question]"

  **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  ⚠️ **Unresolved — requires input from the development team.**
  ```

If there were no technical questions at all, skip this step entirely.

### 6. Commit the updated spec

```bash
git add specs/
git commit -m "docs: update spec with team feedback"
git push origin HEAD
```

### 7. Resolve processed comments

Invoke `/pr-comments resolve` passing the IDs of all bot comments that had `UNANSWERED` status and have now been addressed.

**Wait for `/pr-comments resolve` to finish before continuing.**

### 8. Update PR history

Add row to the table:
```
| Spec revised | YYYY-MM-DD | Feedback integrated via speckit.clarify |
```

```bash
gh pr edit --body "<updated-body>"
```

### 9. Phase retro

Invoke `/speckit.retro` with context: "after clarify phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 10. Final report

```
✅ Spec updated
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
