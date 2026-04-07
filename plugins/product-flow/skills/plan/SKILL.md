---
description: "Generates the technical plan from the approved spec."
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

### 2. Gate: spec created and pending comments resolved

Read `specs/<branch>/status.json` and verify that `spec_created` is present:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null | jq -e '.spec_created' > /dev/null
```

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

Invoke `/product-flow:pr-comments pending`. If it returns pending comments that require a response:

```
🚫 BLOCKED — Pending comments

There are unanswered comments on the PR that must be resolved before generating the plan.

Address them and run /product-flow:continue again.
```

**STOP.**

### 3. Event modeling (conditional)

Read `specs/<feature-dir>/spec.md` and check for event-driven signals:
- Domain events, commands producing events
- Async operations, background processing
- Notifications, webhooks, pub/sub patterns
- Reactions to external triggers (e.g., "when X happens, do Y")

If event-driven signals are present: invoke `/product-flow:praxis.event-modeling`.

`praxis.event-modeling` takes care of:
- Decomposing the feature into STATE_CHANGE, STATE_VIEW, and AUTOMATION slices
- Defining commands, events, aggregates, and Given/When/Then specs
- Writing the model to `specs/<feature-dir>/event-model.md`

**Wait for `praxis.event-modeling` to finish before continuing.**
If it produces an ERROR: propagate and stop.

Pass `event-model.md` as additional context when delegating to `speckit.plan` in the next step — it directly informs `data-model.md` and `contracts/` generation.

If no event-driven signals: skip this step.

### 4. Delegate to speckit.plan

Invoke `/product-flow:speckit.plan`, applying the following technical decision management rules:

**Autonomous resolution of unknowns** — during Phase 0 (research) and Phase 1 (design), if questions or decisions arise that the research agents cannot resolve completely:

- **Do NOT ask the PM.** Make the most reasonable decision based on: existing code, detected project stack, `.agents/rules/base.md`, industry standards.
- Record each AI-made decision internally as **AI-proposed decision**.
- If an unknown cannot be resolved by research or best practices: record it internally as **Unresolved question** and document it in `research.md` as a pending decision rather than blocking.

Save the list of technical decisions (resolved and unresolved) for step 8.

`speckit.plan` takes care of:
- Running the plan setup scripts
- Generating `research.md` resolving technical unknowns
- Generating `data-model.md` with entities and relationships
- Generating `contracts/` with interface contracts
- Updating the agent context

**Wait for `speckit.plan` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 5. Verify generated artifacts

```bash
ls specs/<branch-directory>/
```

Confirm that these exist: `plan.md`, `research.md`, `data-model.md`.
If missing: ERROR "speckit.plan did not generate all artifacts. Check the previous errors."

### 6. Challenge plan complexity

Invoke `/product-flow:praxis.complexity-review` passing the contents of `research.md` and `data-model.md` as input.

`praxis.complexity-review` evaluates the proposal against 30 complexity dimensions and identifies over-engineering.

**Wait for `praxis.complexity-review` to finish before continuing.**

- If it surfaces **critical issues** (e.g., unnecessary microservices, premature event sourcing, unwarranted infrastructure): add one PR comment per issue via `/product-flow:pr-comments write`, surface them to the PM, and **STOP**. Do not proceed to step 8 until the PM acknowledges the issues (via a new run of `/product-flow:continue`).
- If there are no critical issues: continue silently to step 7.

### 7. Validate architecture

Read `research.md` and `data-model.md` to determine whether the plan involves backend work, frontend work, or both.

**If backend work is involved:**

Invoke `/product-flow:praxis.backend-architecture` with the plan as input. It validates that the design follows hexagonal architecture (domain ↔ ports ↔ adapters), dependencies flow inward, and no anti-patterns are present (anemic domain, domain scope pollution, use-case interdependencies).

**If frontend work is involved:**

Invoke `/product-flow:praxis.frontend-architecture` with the plan as input. It validates that the design follows feature-based architecture (colocation, separation of concerns, no cross-feature imports).

**Wait for each invoked skill to finish before continuing.**

- If either surfaces structural issues: add one PR comment per issue before proceeding.
- If no issues: continue silently.

### 8. Record technical decisions in the PR

For each technical decision made, invoke `/product-flow:pr-comments write`
following the technical decision format (ANSWERED/UNANSWERED).
Skip if no technical decisions were made.

### 9. Commit the plan

Write to `specs/<branch>/status.json` before committing:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"plan_generated": $ts}' > "$STATUS_FILE"
```

```bash
git add specs/
git commit -m "docs: add technical plan"
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

### 10. Update PR status

Mark: `- [x] Plan generated`

Add row:
```
| Plan generated | YYYY-MM-DD | research.md + data-model.md |
```

Update the checklist block: replace the `<!-- dev-checklist -->` ... `<!-- /dev-checklist -->` section with the Plan line filled in. Extract tech stack, main libraries, and architecture from `research.md`. List which artifacts were generated (research.md, data-model.md, contracts/ if present).

Example Plan line:
```
- [x] **Plan** — TypeScript · PostgreSQL · Hexagonal architecture · research.md · data-model.md · contracts/
```

```bash
gh pr edit --body "<updated-body>"
```

### 11. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after plan phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 12. Final report

```
✅ Technical plan ready

Run /product-flow:continue to move to the next step.
```

### Session close

Invoke `/product-flow:context`.
