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
| `TASKS_PENDING` | `/product-flow:tasks` |
| `LATE_REVIEW` | `/product-flow:consolidate-plan` |
| `CHECKLIST_PENDING` | `/product-flow:checklist` |

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
            │     TASKS_PENDING     │◄── auto: /product-flow:tasks runs here
            └───────────┬───────────┘
                        │
              has comments?  no comments?
                  │                  │
                  ▼                  │
       ┌──────────────────┐          │
       │   LATE_REVIEW    │          │
       │  apply answers   │          │
       └────────┬─────────┘          │
                └──────────────┬─────┘
                               │ (auto-proceed)
                               ▼
            ┌───────────────────────┐
            │   CHECKLIST_PENDING   │◄── auto: /product-flow:checklist runs here
            └───────────┬───────────┘
                        │ (auto-proceed)
                        ▼
            ┌───────────────────────┐
            │    READY_TO_BE_BUILT  │──── blocked: redirect to /product-flow:build
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

### 1c. Load gathered context

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/gathered-context.md" 2>/dev/null
```

If the file exists, load it silently as background context. It contains the full feature description, visual assets, external docs, and product clarifications collected at feature start. Use it to inform any decisions or clarifications that arise during this session — do not re-ask questions already answered there.

### 1b. Inbox

Invoke `/product-flow:inbox-sync`.

### 2. Determine current state

Read `specs/<branch>/status.json` to check which steps are completed:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null || echo "{}"
```

Map to state using `SPEC_CREATED`, `PLAN_GENERATED`, and `TASKS_GENERATED` fields:

| SPEC_CREATED | PLAN_GENERATED | TASKS_GENERATED | CHECKLIST_DONE | has_comments | → State |
|:---:|:---:|:---:|:---:|:---:|:---|
| ✓ | ✗ | - | - | ✓ | `SPEC_REVIEW` |
| ✓ | ✗ | - | - | ✗ | `PLAN_PENDING` → auto-generate plan |
| ✓ | ✓ | - | - | ✓ | `PLAN_REVIEW` |
| ✓ | ✓ | ✗ | - | ✗ | `TASKS_PENDING` → auto-generate tasks |
| ✓ | ✓ | ✓ | ✗ | ✓ | `LATE_REVIEW` → process pending answers then run checklist |
| ✓ | ✓ | ✓ | ✗ | ✗ | `CHECKLIST_PENDING` → auto-validate requirements |
| ✓ | ✓ | ✓ | ✓ | ✗ | `READY_TO_BE_BUILT` |

For `has_comments`: invoke `/product-flow:pr-comments pending` and `/product-flow:pr-comments read-answers` in parallel.
- If `pending` returns non-empty UNANSWERED comments → `has_comments = true`.
- If `read-answers` returns any new unprocessed answers → `has_comments = true`.
- If both return empty/`NO_USER_RESPONSES` → `has_comments = false`.

### 3. Display current state

Always show the active state before doing anything, using the exact message for each state:

| State | Message |
|-------|---------|
| `SPEC_REVIEW` | `📝 Integrating spec feedback from the team...` |
| `PLAN_PENDING` | `🗺️ Spec ready. Generating the technical plan...` |
| `PLAN_REVIEW` | `📋 Integrating plan feedback from the team...` |
| `TASKS_PENDING` | `✂️ Plan ready. Breaking down into development tasks...` |
| `LATE_REVIEW` | `📋 Processing pending answers before running the checklist...` |
| `CHECKLIST_PENDING` | `✅ Tasks ready. Validating requirements...` |
| `READY_TO_BE_BUILT` | `🚀 Everything is ready. Run /product-flow:build to start building.` |

### 4. Execute state transition

#### `SPEC_REVIEW`

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

Invoke `/product-flow:consolidate-plan`.
Wait for it to finish. If ERROR: propagate and stop.

Then **within this same invocation**, proceed immediately to the `TASKS_PENDING` transition below — do not stop and wait for a new user command.

#### `TASKS_PENDING` (auto-generate)

Invoke `/product-flow:tasks`.

**Wait for `/product-flow:tasks` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

Then **within this same invocation**, proceed immediately to the `CHECKLIST_PENDING` transition below.

#### `LATE_REVIEW` (process answers posted after tasks were generated)

This state is reached when `TASKS_GENERATED=✓` but there are still UNANSWERED bot comments on the PR.

1. **Verify tasks actually exist:**

```bash
BRANCH=$(git branch --show-current)
ls "specs/$BRANCH/tasks.md" 2>/dev/null
```

   - If `tasks.md` **does not exist**: `TASKS_GENERATED` is stale (e.g. a manual rollback was done without cleaning `status.json`). Remove it:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE")
echo "$EXISTING" | jq 'del(.TASKS_GENERATED)' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: remove stale TASKS_GENERATED flag"
git push origin HEAD
```

Then re-evaluate state from step 2 with the corrected `status.json`.

   - If `tasks.md` **exists**: invoke `/product-flow:inbox-sync` to get the latest state from the PR before evaluating answers. Then proceed to step 2 below.

2. Re-run `/product-flow:pr-comments pending` and `/product-flow:pr-comments read-answers` in parallel with fresh data:
   - If it returned **new unprocessed answers**: invoke `/product-flow:consolidate-plan` to apply them and resolve the comments. Wait for it to finish. If ERROR: propagate and stop. Then proceed immediately to the `CHECKLIST_PENDING` transition below.
   - If it returned **`NO_USER_RESPONSES`** (UNANSWERED comments exist but no user answers found): list the pending questions and STOP:

```
🚫 There are unanswered questions on the PR that must be resolved before running the checklist.

**Pending questions:**

<list each UNANSWERED comment with its question number, type, and content>

Please reply on the PR for each open question, then run `/product-flow:continue` again.

Link: <PR_URL>
```

#### `CHECKLIST_PENDING` (auto-validate)

Invoke `/product-flow:checklist`.

**Wait for `/product-flow:checklist` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

After it finishes, check for unresolved items:

```bash
BRANCH=$(git branch --show-current)
grep -r "^- \[ \]" "specs/$BRANCH/checklists/" 2>/dev/null
```

If any `- [ ]` lines are found, **STOP**:

```
🚫 Requirements validation blocked — <N> unresolved item(s):

  · [CHK###] <item description>
  · [CHK###] <item description>
  ...

These items could not be resolved automatically and require input
before implementation can begin. Review the checklist at:
specs/<branch>/checklists/<filename>

Reply with your answers and run /product-flow:continue again.
```

If no unresolved items remain, show:

```
✅ Requirements validated.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run /product-flow:continue to proceed to build,
or add comments on the PR first if changes are needed.
─────────────────────────────────────────
```

#### `READY_TO_BE_BUILT`

Show reminder about AI-answered comments:

```
💬 REMINDER — Before building, review the decisions recorded on the PR.
   · Technical decisions: answered autonomously by the AI on your behalf.
   · Product decisions: taken together with you during spec and planning.
   If anything looks wrong, reply with: Question <N>. Answer: [your preference]
   Link: <PR_URL>
```

Output:

```
📋 Plan ready. You can review it at your own pace in the PR:
<GitHub URL to specs/<feature-dir>/plan.md on the current branch>

Do you want to start building, or would you like to make adjustments first?
```

Use the `AskUserQuestion` tool to ask this.

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
