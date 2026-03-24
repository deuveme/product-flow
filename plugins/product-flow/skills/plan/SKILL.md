---
description: "STEP 3 — Generates the technical plan. Run when the team has approved the spec."
---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "You are not on a feature branch. Run /status."
- If there is no PR: ERROR "There is no open PR. Did you run /start?"

### 2. Gate: spec approved and technical corrections applied

Verify in the PR body:
- `- [x] Spec created` ✓
- `- [x] Spec approved by the development team` ✓

Also, read the PR comments looking for corrections or team responses to previous technical decisions (comments starting with `Correction:` or `Answer:`):

```bash
gh pr view --json comments -q '.comments[].body'
```

If there are corrections: apply them in `spec.md` before delegating to `speckit.plan`. If there are responses to unresolved questions: incorporate them as additional context in the delegation.

If the approval is not marked:

```
🚫 BLOCKED

The spec has not been approved yet.

The development team must approve the spec
in the PR before generating the plan.

If they have already commented but not approved:
  Run /consolidate-spec first.
```

**STOP.**

Verify that there are no unanswered technical decisions: among the PR comments, identify all those containing "Unresolved — requires input from the development team" and check that for each one there is a subsequent comment starting with `Answer:`.

If any technical decision has no team response:

```
🚫 BLOCKED — Unanswered technical decisions

The following technical questions must be answered before generating the plan:

[list the unanswered questions]

The team must answer in the PR with:
  Answer: [letter or answer]
```

**STOP.**

### 3. Delegate to speckit.plan

Invoke `/speckit.plan`, applying the following technical decision management rules:

**Autonomous resolution of unknowns** — during Phase 0 (research) and Phase 1 (design), if questions or decisions arise that the research agents cannot resolve completely:

- **Do NOT ask the PM.** Make the most reasonable decision based on: existing code, project stack (Python/FastAPI + TypeScript/Node 22), `.agents/rules/base.md`, industry standards.
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

Confirm that these exist: `research.md`, `data-model.md`.
If missing: ERROR "speckit.plan did not generate all artifacts. Check the previous errors."

### 5. Challenge plan complexity

Invoke `/praxis.complexity-review` passing the contents of `research.md` and `data-model.md` as input.

`praxis.complexity-review` evaluates the proposal against 30 complexity dimensions and identifies over-engineering.

**Wait for `praxis.complexity-review` to finish before continuing.**

- If it surfaces **critical issues** (e.g., unnecessary microservices, premature event sourcing, unwarranted infrastructure): add one PR comment per issue and surface them to the PM before proceeding.
- If there are no critical issues: continue silently.

### 6. Record technical decisions in the PR

If during step 3 there were technical decisions, add **one individual comment per decision** to the PR.

For each decision the AI was able to make:

```bash
gh pr comment --body "**Technical question detected:** \"[identified question]\"

**Proposed answers:** A. \"[option A]\" B. \"[option B]\" C. \"[option C]\"

**Autonomously chosen answer:** We chose \"[chosen option]\" because \"[brief reasoning]\"

> 💬 If you want to change this decision, reply with: \`Correction: [letter or answer]\`"
```

For each decision the AI was unable to resolve (also documented in `research.md`):

```bash
gh pr comment --body "**Technical question detected:** \"[identified question]\"

**Possible answers:** A. \"[option A]\" B. \"[option B]\" C. \"[option C]\"

⚠️ **Unresolved — requires input from the development team.**

> 💬 To answer, comment with: \`Answer: [letter or answer]\`"
```

If there were no relevant technical decisions, skip this step entirely.

### 7. Commit the plan

```bash
git add specs/
git commit -m "docs: add technical plan"
git push origin HEAD
```

### 8. Update PR status

Mark: `- [x] Plan generated`

Add row:
```
| Plan generated | YYYY-MM-DD | research.md + data-model.md |
```

```bash
gh pr edit --body "<updated-body>"
```

### 9. Phase retro

Invoke `/speckit.retro` with context: "after plan phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 10. Final report

```
✅ Technical plan generated

📁 Artifacts:
   specs/<directory>/research.md
   specs/<directory>/data-model.md
   specs/<directory>/contracts/  (if applicable)

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Share the PR with the team so they can
review the technical plan.

When the team approves the plan, run:
/tasks
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
