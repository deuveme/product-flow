---
description: >
  Post-phase retrospective for SpecKit workflows. Run after any SpecKit phase
  (specify, plan, tasks, implement) or after completing a task group. Reviews
  learnings, simplifies generated code, and checks whether earlier artifacts
  need updating before proceeding.
user_invocable: false
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). If the user
provides context (e.g., "after plan phase" or "after task T012"), use it to scope
the review. Otherwise, infer the current phase from available artifacts.

## Outline

There are two retro modes. Run the appropriate one based on context:

- **Micro-retro** — after completing a single task (during `/product-flow:speckit.implement`)
- **Phase retro** — after completing a full SpecKit phase (specify, plan, tasks,
  implement, or a user story block)

If called standalone (no context), run the **Phase retro**.

---

## Micro-Retro (after a task)

Run this after each completed implementation task before moving to the next one.

### Step 1: Simplify

Re-read the code just written for this task.

- Does any function do more than one thing?
- Is there duplication that could be extracted?
- Are variable and function names self-documenting?
- Is there any dead code, leftover debug output, or commented-out blocks?

Apply fixes immediately if they are small. For larger simplifications, log them
as a follow-up item and continue (do not block progress).

If the `/product-flow:praxis.code-simplifier` skill is available, invoke it on the files touched by this task.

### Step 2: Quick Learning Check

Ask: *Did this task reveal anything unexpected?*

- A constraint not captured in the plan or spec
- A dependency that behaves differently than expected
- A simpler implementation path discovered mid-task
- A requirement that turned out to be ambiguous or wrong

If yes: Add a brief note to `specs/<feature>/lessons-learned.md` (create the file
if it does not exist). Format:

```markdown
## [Task ID] — [Short description]

**What happened**: [One sentence]
**Impact**: [Does this change the plan, spec, or tasks?]
**Proposed action**: [What should change, if anything]
```

If nothing unexpected: proceed immediately.

### Step 3: Iterate Check

Based on what was learned in Step 2, identify whether earlier artifacts need updating. Classify and handle each finding by type:

- **`tasks.md`** (internal): Apply changes directly. Log in `lessons-learned.md`.
- **`spec.md`** (product): Present a questionnaire to the PM listing the proposed changes. Wait for their answers before editing.
- **`plan.md`** / technical artifacts (technical): Post a PR comment with the proposed change and reasoning. Apply immediately; the team can correct via `Correction:` comment.

---

## Phase Retro (after a SpecKit phase)

Run this after completing a full command phase before handing off to the next.

### Step 1: Summarize What Was Produced

State clearly:
- Which phase just completed
- What artifacts were created or updated (file paths)
- Any open items or known gaps

### Step 2: Learning Review

Review `specs/<feature>/lessons-learned.md` (if it exists) and any notes
accumulated during this phase. Then ask:

- What assumptions made at the start of this phase turned out to be wrong?
- What was harder or simpler than expected?
- Did any external constraint (library behavior, API limitation, platform gap)
  surface that is not yet documented?

If there are significant learnings not yet captured, add them to
`specs/<feature>/lessons-learned.md` now.

### Step 3: Backwards Artifact Check

Review earlier artifacts against what was learned. For each artifact, ask the
key question:

| Artifact | Type | Key question |
|----------|------|-------------|
| `spec.md` | **Product** | Do any user stories, acceptance scenarios, or requirements need correction? Is the `Status` field current? |
| `plan.md` | **Technical** | Do any technical decisions, constraints, or the project structure need updating? |
| `tasks.md` | **Internal** | Are any tasks now unnecessary, missing, or mis-sequenced? Are all completed tasks marked `[x]`? |
| `constitution.md` | **Technical** | Did this phase reveal a principle violation or gap worth amending? |
| `data-model.md` | **Technical** | Do entities, relationships, or state transitions need correction? |
| `contracts/` | **Technical** | Do any interface contracts need updating? |

For each artifact that needs a change, classify the decision type and handle accordingly:

#### Product decisions (`spec.md` — requirements, user stories, acceptance criteria)

Use the **AskUserQuestion** tool to present all product findings to the PM before making any changes. Batch up to 4 questions per call (make multiple calls if there are more than 4 items). For each finding:

- `question`: describe the issue and ask what to do, ending with "?"
- `header`: short topic label max 12 chars (e.g. "Spec scope", "User flow")
- `options`: 2–4 choices. First option = "Accept proposed change" (with the proposed text as description). Last option = "Leave as is". Add alternatives in between if relevant.
- `multiSelect`: false

The tool adds "Other" automatically for custom input.

Wait for the PM's answers before proceeding. Once all answers are received:

1. Update `spec.md` with the agreed changes.
2. Post **one individual comment** per item to the PR using `/product-flow:pr-comments write` with:
   - `type`: `product`
   - `status`: `ANSWERED`
   - `body`:
     ```
     **Retro finding:** "[description of issue]"

     **Question asked to PM:** [what was asked]

     **PM answer:** [the answer received]

     **Change applied:** [what was updated in spec.md, or "no change" if left as is]
     ```

#### Technical decisions (`plan.md`, `data-model.md`, `contracts/`, `constitution.md`)

For each item, attempt to resolve it autonomously using project context, existing code, `.agents/rules/base.md`, and industry standards. Then post **one individual comment** to the PR:

If the AI can resolve it, invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `ANSWERED`
- `body`:
  ```
  **Retro finding:** "[description of issue]"

  **Proposed change:** [concrete proposed update]

  **Reasoning:** [brief explanation]
  ```

If the AI cannot resolve it, invoke `/product-flow:pr-comments write` with:
- `type`: `technical`
- `status`: `UNANSWERED`
- `body`:
  ```
  **Retro finding:** "[description of issue]"

  **Possible approaches:** A. "[option A]" B. "[option B]"

  ⚠️ **Unresolved — requires input from the development team.**
  ```

After posting, apply the proposed changes to the technical artifacts immediately (do not wait for team response — corrections from the team will be applied in the next `/product-flow:continue` or `/product-flow:plan` run).

#### Internal decisions (`tasks.md`)

Apply directly without asking. Log the change in `lessons-learned.md`.

### Step 4: Propose Constitution or Rules Updates

If this phase revealed a pattern worth enshrining as a project-wide rule
(in `.agents/rules/base.md`), propose it via a PR comment (same format as a
technical decision above). Never self-apply — wait for human approval.

### Step 5: Readiness Gate

Confirm before proceeding:

- [ ] lessons-learned.md is up to date (or nothing to add)
- [ ] All earlier artifacts that need updating have been reviewed with the user
- [ ] No open blockers that should prevent the next phase from starting
- [ ] Code simplification applied or deferred with a logged note

If all items are clear, state: "Retro complete — ready for [next phase]."
If any item is blocked, do not proceed until the user resolves it.

### Step 6: Session Hygiene Suggestion

Once the readiness gate is green, suggest a context reset:

> **Good moment to run `/clear`.**
> All state is captured in files — `lessons-learned.md` is up to date, all artifacts
> are current. Starting the next phase with a clean context window will reduce noise
> and keep the agent focused.
>
> When you restart, re-read:
> - `specs/<feature>/plan.md` (or `tasks.md` if moving to implementation)
> - `.agents/rules/base.md`
> - Any artifact updated during this retro

This is a suggestion, not a requirement. If the user prefers to continue without
clearing, proceed. The goal is always the smallest possible context window — suggest
after every task and every phase, regardless of session length.

---

## Output Format

Always produce:

1. A brief **Retro Summary** (3-5 bullet points: what happened, what was learned,
   what changes are proposed)
2. A clear **Ready / Blocked** status
3. If blocked: a numbered list of specific actions the user needs to take
4. If ready: the session hygiene suggestion (Step 6)
