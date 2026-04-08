---
description: "STEP 2 — Advances to the next step in the workflow. Reads the current state and executes the corresponding transition. Only one state is active at a time — invalid transitions are blocked."
model: haiku
effort: medium
---

## Composability Rule

**Every state transition MUST delegate to a named sub-skill. Never perform work inline.**

| State | Sub-skill invoked |
|-------|-------------------|
| `SPEC_REVIEW` | `/product-flow:consolidate-spec` |
| `PLAN_PENDING` | `/product-flow:plan` |
| `PLAN_REVIEW` | `/product-flow:consolidate-plan` |

If a transition requires work that has no dedicated sub-skill, stop and surface the gap — do not implement it inline.

## State Machine

```
                /product-flow:start
                        │
                        ▼
            ┌───────────────────────┐
            │      SPEC_CREATED     │◄── after consolidating feedback
            └───────────┬───────────┘
                        │
              has comments?  no comments?
                  │                  │
                  ▼                  │
       ┌──────────────────┐          │
       │   SPEC_REVIEW    │          │
       │   consolidate    │          │
       └────────┬─────────┘          │
                └──────────────┬─────┘
                               │ (auto-proceed)
                               ▼
            ┌───────────────────────┐
            │     PLAN_PENDING      │◄── auto: /product-flow:plan runs here
            └───────────┬───────────┘
                        │
              has comments?  no comments?
                  │                  │
                  ▼                  │
       ┌──────────────────┐          │
       │   PLAN_REVIEW    │          │
       │   consolidate    │          │
       └────────┬─────────┘          │
                └──────────────┬─────┘
                               │ (auto-proceed)
                               ▼
            ┌───────────────────────┐
            │      READY_TO_BE_BUILT      │──── blocked: redirect to /product-flow:build
            └───────────────────────┘
```

**Blocked states** (invalid transitions):
- Any state where required preconditions are not met → ERROR with explanation

---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "There is no active feature. Use /product-flow:start to start a new one."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start?"

### 1b. Inbox

Show: `📬 Checking for new activity...`

**Part A — Answers to bot questions:**

Invoke `/product-flow:pr-comments read-answers`. For each new answer found:

1. Evaluate whether the answer is actionable as-is:
   - **Clear**: apply directly.
   - **Ambiguous or incomplete**: clarify before applying:
     - If the question was `type: technical`: resolve the ambiguity autonomously using project context. Do not ask the PM.
     - If the question was `type: product`: use **AskUserQuestion** (one entry for this question only) to ask the PM for clarification before applying.

2. Show before applying:
   ```
     ⏳ Question <N> — <one-line summary> → applying to <artifact>...
   ```
   Apply, then show:
   ```
     ✅ Question <N> — applied.
   ```

Invoke `/product-flow:pr-comments mark-processed` with the question numbers of all applied answers.

**Part B — New user comments:**

Invoke `/product-flow:pr-comments new-comments`. If `NO_NEW_COMMENTS`: continue silently.

For each new comment, classify and resolve:

- **Technical**: resolve autonomously using project context. Invoke `/product-flow:pr-comments write` with `type: technical`, `status: ANSWERED` (or `UNANSWERED` if unresolvable). Apply the decision to the relevant artifact.
- **Product**: use **AskUserQuestion** (single call, one entry per comment). After receiving the PM's answers, apply changes to the relevant artifact. Invoke `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`.

After processing all new comments, invoke `/product-flow:pr-comments mark-comments-processed` with the IDs of all processed comments.

Show: `✅ Inbox processed — <N> answer(s) applied, <M> comment(s) evaluated.`
(or `✅ Inbox clear.` if nothing to process)

### 2. Determine current state

Read `specs/<branch>/status.json` to check which steps are completed:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null || echo "{}"
```

Map to state using `spec_created` and `plan_generated` fields:

| spec_created | plan_generated | has_comments | → State |
|:---:|:---:|:---:|:---|
| ✓ | ✗ | ✓ | `SPEC_REVIEW` |
| ✓ | ✗ | ✗ | `PLAN_PENDING` → auto-generate plan |
| ✓ | ✓ | ✓ | `PLAN_REVIEW` |
| ✓ | ✓ | ✗ | `READY_TO_BE_BUILT` |

For `has_comments`: invoke `/product-flow:pr-comments pending` and `/product-flow:pr-comments read-answers` in parallel.
- If `pending` returns non-empty UNANSWERED comments → `has_comments = true`.
- If `read-answers` returns any new unprocessed answers → `has_comments = true`.
- If both return empty/`NO_USER_RESPONSES` → `has_comments = false`.

### 3. Display current state

Always show the active state before doing anything:

```
📍 State: <STATE_NAME>
   <one-line description of what this means>
```

Examples:

```
📍 The team has left feedback on the spec. Integrating before proceeding.
```

```
📍 Spec is ready. Generating the technical plan.
```

```
📍 The plan is ready.
```

### 4. Execute state transition

#### `SPEC_REVIEW`

```
🔜 Integrating team feedback into the spec.

Starting...
```

Invoke `/product-flow:consolidate-spec`.
Wait for it to finish. If ERROR: propagate and stop.

Then **within this same invocation**, proceed immediately to the `PLAN_PENDING` transition below — do not stop and wait for a new user command.

#### `PLAN_PENDING` (auto-generate)

Before generating the plan, check for unresolved spec ambiguities:

```
⏳ Checking spec for ambiguities before planning...
```

Invoke `/product-flow:speckit.clarify`.

**Wait for `speckit.clarify` to finish before continuing.**

- If it reports **no critical ambiguities** (all categories Clear or Deferred): continue silently.
- If it resolves ambiguities (technical via PR comments, product via PM questions): continue after answers are applied.
- If it produces an ERROR: propagate and stop.

```
🔜 Generating the technical plan.

Starting...
```

Invoke `/product-flow:plan`.
Wait for it to finish. If ERROR: propagate and stop.

After generating, show:

```
✅ Plan generated.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run /product-flow:continue to proceed to build,
or add comments on the PR first if changes are needed.
─────────────────────────────────────────
```

#### `PLAN_REVIEW`

```
🔜 Integrating team feedback into the plan.

Starting...
```

Invoke `/product-flow:consolidate-plan`.
Wait for it to finish. If ERROR: propagate and stop.

Then continue automatically to `READY_TO_BE_BUILT`.

#### `READY_TO_BE_BUILT`

Before showing the plan, run the pre-build comment review:

**1. Resolve unanswered comments:**

Invoke `/product-flow:pr-comments pending`. For each UNANSWERED comment:

- `type: technical`: attempt autonomous resolution using project context and industry standards. Invoke `/product-flow:pr-comments write` with `status: ANSWERED` and mark resolved via `/product-flow:pr-comments resolve`.
- `type: product`: use **AskUserQuestion** to ask the PM in a single call (one entry per comment). After receiving the PM's answers, post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`.

Only after all comments are resolved, continue.

**2. Check for unprocessed user answers:**

Invoke `/product-flow:pr-comments read-answers`. Show: `📬 Reading PR answers...`

For each new answer found, show before applying:
```
  ⏳ Question <N> — <one-line summary> → applying to <artifact>...
```
Apply it, then show:
```
  ✅ Question <N> — applied.
```

After all answers are processed, show: `✅ <N> answer(s) applied.` (or `No new answers found.` if none).

Invoke `/product-flow:pr-comments mark-processed` with the question numbers of all applied answers (e.g. `1 3`).

**3. Show reminder about AI-answered comments:**

```
💬 REMINDER — Before building, review the decisions recorded on the PR.
   · Technical decisions: answered autonomously by the AI on your behalf.
   · Product decisions: taken together with you during spec and planning.
   If anything looks wrong, reply with: Question <N>. Answer: [your preference]
   Link: <PR_URL>
```

Read `specs/<feature-dir>/plan.md` and output its full contents as markdown.

Then output:

```
📋 Plan ready. You can review it at your own pace in the PR:
<GitHub URL to specs/<feature-dir>/plan.md on the current branch>

Do you want to start building, or would you like to make adjustments first?
```

**STOP and wait for the user's response.**

- If the user wants adjustments: apply them to the relevant artifacts (`plan.md`, `research.md`, `data-model.md`), commit, push, and show the updated plan again repeating this block.
- If the user confirms they want to continue:

```
─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /product-flow:build
─────────────────────────────────────────
```

**STOP.**

### 5. Session close

Invoke `/product-flow:context`.
