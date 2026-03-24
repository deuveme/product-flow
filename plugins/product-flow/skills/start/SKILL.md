---
description: "STEP 1 — Starts a new feature. Creates the draft PR and kicks off the specification process."
---

## User Input

```text
$ARGUMENTS
```

Feature description in natural language. **Required.**
If empty: ERROR "Describe the feature. Example: /start I want users to be able to reset their password"

---

## Execution

### 1. Verify clean starting point

```bash
git status --porcelain
git branch --show-current
```

- If there are uncommitted changes: ERROR "There are unsaved changes. Save or discard them before starting a new feature."
- If the current branch is not `main` or `master`: ERROR "You must be on the main branch. Run /status to see where you are."

### 2. Delegate to speckit.specify

Invoke `/speckit.specify` passing `$ARGUMENTS` as the feature description, applying the following question management rules:

**Question classification** — when `speckit.specify` identifies `[NEEDS CLARIFICATION]` markers, classify each one before presenting it:

- **Non-technical** (ask the PM): business intent, priorities, functional scope, user flows, terminology.
- **Technical** (resolve autonomously): authentication, authorisation, security, compliance, data retention, integration patterns, infrastructure constraints.

**For technical questions**, do NOT ask the PM. Instead:
1. Answer them using project context: existing code, `.agents/rules/base.md`, project stack (Python/FastAPI + TypeScript/Node 22), industry standards.
2. If there is sufficient information: make the decision and record it internally as **AI-proposed decision**.
3. If there is not sufficient information: record it internally as **Unresolved question** and continue.

Save the list of technical decisions (resolved and unresolved) internally for step 6.

`speckit.specify` takes care of:
- Generating the short name and branch number (`NNN-short-name`)
- Creating and checking out the branch
- Writing `specs/NNN-short-name/spec.md`
- Generating the quality checklist
- Asking clarification questions if there are any

**Wait for `speckit.specify` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 3. Read created branch and spec

```bash
git branch --show-current
```

```bash
ls specs/ | sort | tail -1
```

`BRANCH_NAME` = active branch
`SPEC_PATH` = `specs/<last-directory>/spec.md`

### 4. Push the branch

```bash
git push -u origin HEAD
```

### 5. Open draft PR

```bash
gh pr create \
  --title "$BRANCH_NAME" \
  --draft \
  --base main \
  --body "$(cat <<EOF
## Feature
Spec: $SPEC_PATH

## Status
- [x] Spec created
- [ ] Spec approved by the development team
- [ ] Plan generated
- [ ] Plan approved by the development team
- [ ] Tasks generated
- [ ] Code generated
- [ ] In code review
- [ ] Published

## History

| Status | Date | Note |
|--------|-------|------|
| Spec created | $(date +%Y-%m-%d) | Feature started |

## Notes
EOF
)"
```

### 6. Record technical decisions in the PR

If during step 2 there were technical questions, add **one individual comment per question** to the newly created PR.

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

### 7. Phase retro

Invoke `/speckit.retro` with context: "after specify phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 8. Final report

```
✅ Feature started

📋 Spec:  <SPEC_PATH>
🌿 Branch:  <BRANCH_NAME>
🔗 PR:    <PR_URL>

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Share the PR with the development team
so they can review the spec.

When they have commented, run:
/continue
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
