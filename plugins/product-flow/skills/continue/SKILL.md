---
description: "Advances to the next step in the workflow. Reads the current state and executes the corresponding transition. Only one state is active at a time — invalid transitions are blocked."
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

Use the PR body already fetched in step 1 to check which boxes are marked (`- [x]`).

Map to state:

| spec_created | plan_generated | has_comments | → State |
|:---:|:---:|:---:|:---|
| ✓ | ✗ | ✓ | `SPEC_REVIEW` |
| ✓ | ✗ | ✗ | `PLAN_PENDING` → auto-generate plan |
| ✓ | ✓ | ✓ | `PLAN_REVIEW` |
| ✓ | ✓ | ✗ | `BUILD_READY` |

For `has_comments`: invoke `/product-flow:pr-comments pending`. If it returns `NO_PENDING_COMMENTS`, `has_comments = false`. Otherwise `has_comments = true`.

### 3. Display current state

Always show the active state before doing anything:

```
📍 State: <STATE_NAME>
   <one-line description of what this means>
```

Examples:

```
📍 State: SPEC_REVIEW
   The team has left feedback on the spec. Consolidating before proceeding.
```

```
📍 State: PLAN_PENDING
   Spec is ready. Generating the technical plan.
```

```
📍 State: BUILD_READY
   The plan is ready. /product-flow:continue has no further transitions.
```

### 4. Execute state transition

#### `SPEC_REVIEW`

```
🔜 Transition: SPEC_REVIEW → PLAN_PENDING
   Integrating team feedback into the spec.

Starting...
```

Invoke `/product-flow:consolidate-spec`.
Wait for it to finish. If ERROR: propagate and stop.

Then continue automatically to `PLAN_PENDING` transition below.

#### `PLAN_PENDING` (auto-generate)

```
🔜 Transition: PLAN_PENDING → BUILD_READY
   Generating technical plan from the spec.

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
🔜 Transition: PLAN_REVIEW → BUILD_READY
   Integrating team feedback into the plan and related artifacts.

Starting...
```

Invoke `/product-flow:consolidate-plan`.
Wait for it to finish. If ERROR: propagate and stop.

Then continue automatically to `BUILD_READY`.

#### `BUILD_READY`

```
📍 State: BUILD_READY
   The plan is ready. /product-flow:continue has no further transitions.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /product-flow:build
─────────────────────────────────────────
```

**STOP.**

### 5. Session close

Invoke `/product-flow:context`.
