---
description: "Integrates team feedback into the spec."
user-invocable: false
model: sonnet
effort: medium
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

Also invoke `/product-flow:pr-comments read-answers`.

Show: `📬 Reading PR answers...`

For each new answer found, show:
```
  ⏳ Question <N> — <one-line summary of the question>
```

After all are loaded, show: `✅ <N> answer(s) found — evaluating before applying.` (or `No new answers found.` if none).

**Evaluate each answer for clarity before passing to step 4:**

For each answer, assess whether it is actionable as-is:

- **Clear**: pass directly to step 4.
- **Ambiguous or incomplete**:
  - If the original question was `type: technical`: note the ambiguity internally and pass to `speckit.clarify` with a flag to resolve it autonomously using project context.
  - If the original question was `type: product`: use **AskUserQuestion** (one entry per ambiguous answer) to ask the PM for clarification before continuing. Replace the ambiguous answer with the PM's clarified response before passing to step 4.

**Also handle incomprehensible freeform comments from `pending`:**

For each UNANSWERED comment in `pending` that is a freeform user comment (not a bot question — i.e., its body does not contain `<!-- id:q`):

- **Incomprehensible** (no discernible actionable intent: `"???"`, stray emoji, link without context): invoke `/product-flow:pr-comments write` with `type: product`, `status: UNANSWERED`, body:
  ```
  **Unrecognised comment:** "[original comment text]"

  ⚠️ This comment could not be interpreted. Please clarify what change (if any) you'd like.
  ```
  Mark it as processed and skip.
- **Ambiguous type** (could be product or technical): default to **product** and include it in the `AskUserQuestion` call below.

Record all clarified responses together with the remaining pending comments internally — they will be used as context in step 4. For each question, only the last response counts.

After applying in step 4, for each answer applied show:
```
  ✅ Question <N> — applied to <artifact>.
```

Then invoke `/product-flow:pr-comments mark-processed` with the question numbers of all applied answers (e.g. `1 3`).

### 3b. Detect conflicting comments

Before delegating to `speckit.clarify`, scan all collected comments and answers for contradictions: two or more items that affect the same spec section or requirement with incompatible intent (e.g. "add OAuth login" vs "remove all auth from scope", or two answers to the same question pointing in opposite directions).

For each conflict found:
- Do **not** apply either side autonomously.
- Use **AskUserQuestion** (one entry per conflict) to ask the PM which direction takes precedence. Frame the question with both sides clearly stated and a "Recommended" option if one side clearly aligns with the existing spec intent.

Only after all conflicts are resolved, proceed to step 4 with the reconciled set of comments.

If no conflicts are detected: continue silently.

### 4. Delegate to speckit.clarify

Invoke `/product-flow:speckit.clarify` with the context of the PR comments, applying the following question management rules:

**Question classification** — before presenting each question, classify it:

- **Product** (ask the PM): business intent, priorities, user flow, terminology, functional scope. **NEVER resolve autonomously. Always surface to the PM via AskUserQuestion.**
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

For each technical decision made, invoke `/product-flow:pr-comments write`:

- If resolved:
  - `type`: `technical`, `status`: `ANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
    ```
- If unresolved:
  - `type`: `technical`, `status`: `UNANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    ⚠️ **Unresolved — requires input from the development team.**
    ```

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

Read the current PR body first (`gh pr view --json body -q '.body'`), then add only this row to the `## History` table — preserve all other sections intact:

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
