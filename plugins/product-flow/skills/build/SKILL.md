---
description: "Generates the feature code. Run when the team has approved the plan."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "There is no active feature. Use /start to start a new one."
- If there is no PR: ERROR "There is no open PR. Did you run /start?"

### 2. Gate: plan approved

Verify in the PR body:
- `- [x] Plan approved by the development team` ✓

If not marked:

```
🚫 The plan has not been approved by the team yet.

Share the PR with the team and wait for their approval.
When they approve it, run /build again.

🔗 PR: <url>
```

**STOP.**

Also verify that there are no unanswered technical decisions: read the PR comments looking for those containing "Unresolved — requires input from the development team" and check that for each one there is a subsequent comment starting with `Answer:`.

```bash
gh pr view --json comments -q '.comments[].body'
```

If any technical decision has no team response:

```
🚫 There are technical questions pending a response.

The development team must answer before building:

[list the unanswered questions]

To answer, the team must comment on the PR with:
  Answer: [letter or answer]
```

**STOP.**

### 3. Inform the PM

```
📍 Current status: Plan approved · Ready to build

🔜 I'm going to:
   1. Break down the plan into development tasks
   2. Validate requirements quality
   3. Generate the feature code

This may take several minutes.

Starting...
```

### 4. Generate tasks

Invoke `/tasks`.

`/tasks` takes care of:
- Generating `tasks.md` with tasks ordered by dependencies
- Creating the issues on GitHub
- Recording technical decisions in the PR

**Wait for `/tasks` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 5. Validate requirements quality

Invoke `/checklist`.

`/checklist` takes care of:
- Validating that spec, plan and tasks are complete, unambiguous and consistent
- Generating `specs/<dir>/checklists/<domain>.md`

**Wait for `/checklist` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

If the checklist reveals CRITICAL issues (gaps, conflicts, or ambiguities that would break implementation), stop and inform the PM:

```
🚫 The checklist found critical issues that must be resolved before implementing.

Review: specs/<dir>/checklists/<domain>.md

Fix the issues and run /build again.
```

**STOP.**

### 6. Implement

Invoke `/implement`.

`/implement` takes care of:
- Reading spec, plan, data-model, contracts and tasks
- Implementing the tasks in the correct order
- Respecting the dependencies defined in tasks.md

**Wait for `/implement` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 7. Final report

```
✅ Feature built

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /submit

It will save the code and leave it ready
for the development team's review.
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
