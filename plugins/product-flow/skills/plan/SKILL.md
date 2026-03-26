---
description: "Internal — Called by /product-flow:continue. Generates the technical plan from the approved spec."
user_invocable: false
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

Verify in the PR body:
- `- [x] Spec created` ✓

Invoke `/product-flow:pr-comments read-answers`. If it returns responses, apply them before delegating to `speckit.plan`:
- `Question <N>. Correction:` responses → apply to `spec.md`. Use the last response per question number.
- `Question <N>. Answer:` responses → incorporate as additional context in the delegation. Use the last response per question number.

Invoke `/product-flow:pr-comments pending`. If it returns pending comments that require a response:

```
🚫 BLOCKED — Pending comments

There are unanswered comments on the PR that must be resolved before generating the plan.

Address them and run /product-flow:continue again.
```

**STOP.**

### 3. Delegate to speckit.plan

Invoke `/product-flow:speckit.plan`, applying the following technical decision management rules:

**Autonomous resolution of unknowns** — during Phase 0 (research) and Phase 1 (design), if questions or decisions arise that the research agents cannot resolve completely:

- **Do NOT ask the PM.** Make the most reasonable decision based on: existing code, detected project stack, `.agents/rules/base.md`, industry standards.
- Record each AI-made decision internally as **AI-proposed decision**.
- If an unknown cannot be resolved by research or best practices: record it internally as **Unresolved question** and document it in `research.md` as a pending decision rather than blocking.

Save the list of technical decisions (resolved and unresolved) for step 6.

`speckit.plan` takes care of:
- Running the plan setup scripts
- Generating `research.md` resolving technical unknowns
- Generating `data-model.md` with entities and relationships
- Generating `contracts/` with interface contracts
- Updating the agent context

**Wait for `speckit.plan` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 4. Verify generated artifacts

```bash
ls specs/<branch-directory>/
```

Confirm that these exist: `plan.md`, `research.md`, `data-model.md`.
If missing: ERROR "speckit.plan did not generate all artifacts. Check the previous errors."

### 5. Challenge plan complexity

Invoke `/product-flow:praxis.complexity-review` passing the contents of `research.md` and `data-model.md` as input.

`praxis.complexity-review` evaluates the proposal against 30 complexity dimensions and identifies over-engineering.

**Wait for `praxis.complexity-review` to finish before continuing.**

- If it surfaces **critical issues** (e.g., unnecessary microservices, premature event sourcing, unwarranted infrastructure): add one PR comment per issue and surface them to the PM before proceeding.
- If there are no critical issues: continue silently.

### 6. Validate architecture

Read `research.md` and `data-model.md` to determine whether the plan involves backend work, frontend work, or both.

**If backend work is involved:**

Invoke `/product-flow:praxis.backend-architecture` with the plan as input. It validates that the design follows hexagonal architecture (domain ↔ ports ↔ adapters), dependencies flow inward, and no anti-patterns are present (anemic domain, domain scope pollution, use-case interdependencies).

**If frontend work is involved:**

Invoke `/product-flow:praxis.frontend-architecture` with the plan as input. It validates that the design follows feature-based architecture (colocation, separation of concerns, no cross-feature imports).

**Wait for each invoked skill to finish before continuing.**

- If either surfaces structural issues: add one PR comment per issue before proceeding.
- If no issues: continue silently.

### 7. Record technical decisions in the PR

If during step 3 there were technical decisions, add **one individual comment per decision** to the PR.

For each decision the AI was able to make, invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `ANSWERED`
- `body`:
  ```
  **Technical question detected:** "[identified question]"

  **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
  ```

For each decision the AI was unable to resolve (also documented in `research.md`), invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `UNANSWERED`
- `body`:
  ```
  **Technical question detected:** "[identified question]"

  **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  ⚠️ **Unresolved — requires input from the development team.**
  ```

If there were no relevant technical decisions, skip this step entirely.

### 8. Commit the plan

```bash
git add specs/
git commit -m "docs: add technical plan"
git push origin HEAD
```

### 9. Update PR status

Mark: `- [x] Plan generated`

Add row:
```
| Plan generated | YYYY-MM-DD | research.md + data-model.md |
```

```bash
gh pr edit --body "<updated-body>"
```

### 10. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after plan phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 11. Final report

```
✅ Technical plan generated

📁 Artifacts:
   specs/<directory>/plan.md
   specs/<directory>/research.md
   specs/<directory>/data-model.md
   specs/<directory>/contracts/  (if applicable)
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
