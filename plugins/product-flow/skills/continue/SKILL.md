---
description: "STEP 2 — Advances to the next step in the workflow. Reads the current state and executes the corresponding transition. Only one state is active at a time — invalid transitions are blocked."
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
            │      BUILD_READY      │──── blocked: redirect to /product-flow:build
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
| ✓ | ✓ | ✗ | `BUILD_READY` |

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

Then continue automatically to `BUILD_READY`.

#### `BUILD_READY`

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
