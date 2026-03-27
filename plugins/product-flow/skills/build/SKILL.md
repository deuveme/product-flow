---
description: "STEP 5 — Generates the feature code. Run when the plan is ready."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "There is no active feature. Use /product-flow:start to start a new one."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 2. Gate: plan generated

Verify in the PR body:
- `- [x] Plan generated` ✓

If not marked:

```
🚫 The plan has not been generated yet.

Run /product-flow:continue to generate the plan first.
```

**STOP.**

### 3. Detect progress and decide entry point

Check the PR body and feature directory:
- Tasks done? → `- [x] Tasks generated` is marked
- Checklist done? → `specs/<feature-dir>/checklists/` directory exists and is non-empty
- Code done? → `- [x] Code generated` is marked
- Verify-tasks done? → `specs/<feature-dir>/verify-tasks-report.md` exists

**Re-entry shortcut**: If code is already generated (`- [x] Code generated`)
but `verify-tasks-report.md` does NOT exist in FEATURE_DIR, the user chose
option B ("open a new session") from the verify-tasks proposal. In this case:
**skip directly to step 6b (verify-tasks)** without re-running tasks, checklist,
or implement.

Otherwise, build the pending steps list based on what is NOT yet done and show:

```
📍 Current status: Plan generated · Ready to build

🔜 I'm going to:
   [only list pending steps, e.g.:]
   1. Break down the plan into development tasks   ← skip if already done
   2. Validate requirements quality                ← skip if already done
   3. Generate the feature code                    ← skip if already done

This may take several minutes.

Starting...
```

If all steps (including verify-tasks) are already done, skip to the final report.

### 4. Generate tasks

Skip this step if `- [x] Tasks generated` is already marked in the PR body.

Otherwise, invoke `/product-flow:tasks`.

`/product-flow:tasks` takes care of:
- Generating `tasks.md` with tasks ordered by dependencies
- Creating the issues on GitHub
- Recording technical decisions in the PR

**Wait for `/product-flow:tasks` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 5. Validate requirements quality

Skip this step if `specs/<feature-dir>/checklists/` already exists and contains at least one file.

Otherwise, invoke `/product-flow:checklist`.

`/product-flow:checklist` takes care of:
- Validating that spec, plan and tasks are complete, unambiguous and consistent
- Generating `specs/<dir>/checklists/<domain>.md`

**Wait for `/product-flow:checklist` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

If the checklist reveals CRITICAL issues (gaps, conflicts, or ambiguities that would break implementation), stop and inform the PM:

```
🚫 The checklist found critical issues that must be resolved before implementing.

Review: specs/<dir>/checklists/<domain>.md

Fix the issues and run /product-flow:build again.
```

**STOP.**

### 6. Implement

Skip this step if `- [x] Code generated` is already marked in the PR body.

Otherwise, invoke `/product-flow:implement`.

`/product-flow:implement` takes care of:
- Reading spec, plan, data-model, contracts and tasks
- Implementing the tasks in the correct order
- Respecting the dependencies defined in tasks.md
- Proposing `speckit.verify-tasks` at the end (step 10 of implement)

**Wait for `/product-flow:implement` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 6b. Verify-tasks (re-entry from new session)

This step runs only when the re-entry shortcut was triggered in step 3:
code is already generated AND `verify-tasks-report.md` does NOT exist.

The user opened a new session specifically to run verify-tasks with a clean
context — execute it directly without re-proposing.

Invoke `/product-flow:speckit.verify-tasks`.

**Wait for `speckit.verify-tasks` to finish before continuing.**

- If it flags **NOT_FOUND** or **PARTIAL** tasks: surface the interactive
  walkthrough and wait for the user to resolve each item.
- When the walkthrough finishes (or if no items are flagged): continue to
  step 7.

### 7. Final report

```
✅ Feature built

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /product-flow:submit

It will save the code and leave it ready
for the development team's review.
─────────────────────────────────────────
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
