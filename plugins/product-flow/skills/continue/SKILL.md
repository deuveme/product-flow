---
description: "Advances to the next step in the workflow. Reads the current state and executes the corresponding transition. Only one state is active at a time — invalid transitions are blocked."
---

## Composability Rule

**Every state transition MUST delegate to a named sub-skill. Never perform work inline.**

| State | Sub-skill invoked |
|-------|-------------------|
| `SPEC_REVIEW` | `/consolidate-spec` |
| `PLAN_PENDING` | `/plan` |
| `PLAN_REVIEW` | `/consolidate-plan` |

If a transition requires work that has no dedicated sub-skill, stop and surface the gap — do not implement it inline.

## State Machine

```
                     /start
                       │
                       ▼
               ┌──────────────┐
               │ SPEC_CREATED │◄─── after consolidating feedback
               └──────┬───────┘
                       │ team adds comments
                       ▼
               ┌──────────────┐
               │ SPEC_REVIEW  │──── /consolidate-spec ──►  SPEC_CREATED
               └──────────────┘
                       │ team approves spec
                       ▼
               ┌──────────────┐
               │ PLAN_PENDING │◄─── auto: /plan runs here
               └──────┬───────┘
                       │ /plan finishes
                       ▼
               ┌──────────────┐
               │ PLAN_WAITING │◄─── waiting for team approval
               └──────┬───────┘
                       │ team adds comments on plan
                       ▼
               ┌──────────────┐
               │ PLAN_REVIEW  │──── consolidate plan feedback ──►  PLAN_WAITING
               └──────────────┘
                       │ team approves plan
                       ▼
               ┌──────────────┐
               │ BUILD_READY  │──── blocked: redirect to /build
               └──────────────┘
```

**Waiting states** (no action possible — team must act first):
- `SPEC_CREATED` with no comments and no approval → waiting for team review
- `PLAN_WAITING` with no comments and no approval → waiting for team review

**Blocked states** (invalid transitions):
- Any state where required preconditions are not met → ERROR with explanation

---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "There is no active feature. Use /start to start a new one."
- If there is no PR: ERROR "There is no open PR. Did you run /start?"

### 2. Determine current state

Read PR body to check which boxes are marked (`- [x]`):

```bash
gh pr view --json body -q '.body'
gh pr view --json comments -q '.comments[].body'
```

Map to state:

| spec_created | spec_approved | plan_generated | plan_approved | has_comments | → State |
|:---:|:---:|:---:|:---:|:---:|:---|
| ✓ | ✗ | ✗ | ✗ | ✗ | `SPEC_CREATED` (waiting) |
| ✓ | ✗ | ✗ | ✗ | ✓ | `SPEC_REVIEW` |
| ✓ | ✓ | ✗ | ✗ | any | `PLAN_PENDING` → auto-generate plan |
| ✓ | ✓ | ✓ | ✗ | ✗ | `PLAN_WAITING` |
| ✓ | ✓ | ✓ | ✗ | ✓ | `PLAN_REVIEW` |
| ✓ | ✓ | ✓ | ✓ | any | `BUILD_READY` |

For `has_comments`: invoke `/pr-comments pending`. If it returns `NO_PENDING_COMMENTS`, `has_comments = false`. Otherwise `has_comments = true`.

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
📍 State: SPEC_CREATED — waiting
   The spec is ready. Waiting for team approval in the PR.
   No action available until the team approves or adds comments.

🔗 PR: <url>
```

```
📍 State: BUILD_READY
   The plan has been approved. /continue cannot proceed further.
```

### 4. Execute state transition

#### `SPEC_CREATED` (waiting)

```
⏳ Nothing to do yet.
   The development team must review and approve the spec in the PR.
   When they do, run /continue again.

🔗 PR: <url>
```

**STOP.**

#### `SPEC_REVIEW`

```
🔜 Transition: SPEC_REVIEW → SPEC_CREATED
   Integrating team feedback into the spec.

Starting...
```

Invoke `/consolidate-spec`.
Wait for it to finish. If ERROR: propagate and stop.

After consolidating, check if spec is now approved:
- If approved → continue to `PLAN_PENDING` transition below.
- If not approved → show SPEC_CREATED waiting message and stop.

#### `PLAN_PENDING` (auto-generate)

```
🔜 Transition: PLAN_PENDING → PLAN_WAITING
   Generating technical plan from the approved spec.

Starting...
```

Invoke `/plan`.
Wait for it to finish. If ERROR: propagate and stop.

After generating, show:

```
✅ Plan generated.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Share the PR with the team so they can review the plan.
When they approve it, run: /continue
─────────────────────────────────────────
```

#### `PLAN_WAITING`

```
⏳ Nothing to do yet.
   The plan has been generated. Waiting for team approval in the PR.
   When they approve or add comments, run /continue again.

🔗 PR: <url>
```

**STOP.**

#### `PLAN_REVIEW`

```
🔜 Transition: PLAN_REVIEW → PLAN_WAITING
   Integrating team feedback into the plan and related artifacts.

Starting...
```

Invoke `/consolidate-plan`.
Wait for it to finish. If ERROR: propagate and stop.

#### `BUILD_READY`

```
📍 State: BUILD_READY
   The plan has been approved. /continue has no further transitions.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /build
─────────────────────────────────────────
```

**STOP.**

### 5. Session close

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
