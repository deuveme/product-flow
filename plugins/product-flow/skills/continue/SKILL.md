---
description: "STEP 2 — Advances to the next step in the workflow. Reads the current state and executes the corresponding transition. Only one state is active at a time — invalid transitions are blocked."
model: sonnet
effort: low
---

## Composability Rule

**Every state transition MUST delegate to a named sub-skill. Never perform work inline.**

### Feature flow transitions

| Condition | Sub-skill invoked |
|-----------|-------------------|
| `SPEC_CREATED` ✓, `SPLIT_PREPLAN_ANALIZED` ✗, `PLAN_GENERATED` ✗, `has_comments` true | `/product-flow:consolidate-spec` |
| `SPEC_CREATED` ✓, `SPLIT_PREPLAN_ANALIZED` ✗, `PLAN_GENERATED` ✗, `has_comments` false | `/product-flow:speckit.split` |
| `SPEC_CREATED` ✓, `SPLIT_PREPLAN_ANALIZED` ✓, `PLAN_GENERATED` ✗ | `/product-flow:plan` |
| `PLAN_GENERATED` ✓, `SPLIT_POSTPLAN_ANALIZED` ✗, `has_comments` true | `/product-flow:consolidate-plan` → then `/product-flow:speckit.split` |
| `PLAN_GENERATED` ✓, `SPLIT_POSTPLAN_ANALIZED` ✗, `has_comments` false | `/product-flow:speckit.split` |
| `PLAN_GENERATED` ✓, `SPLIT_POSTPLAN_ANALIZED` ✓, `TASKS_GENERATED` ✗, `has_comments` true | `/product-flow:consolidate-plan` |
| `PLAN_GENERATED` ✓, `SPLIT_POSTPLAN_ANALIZED` ✓, `TASKS_GENERATED` ✗, `has_comments` false | `/product-flow:tasks` |
| `TASKS_GENERATED` ✓, `CHECKLIST_DONE` ✗, `has_comments` true | `/product-flow:consolidate-plan` |
| `TASKS_GENERATED` ✓, `CHECKLIST_DONE` ✗, `has_comments` false | `/product-flow:checklist` |
| `CHECKLIST_DONE` ✓, `CODE_WRITTEN` ✗, `has_comments` true | `/product-flow:consolidate-plan` (clears `CHECKLIST_DONE`) |
| `CHECKLIST_DONE` ✓, `CODE_WRITTEN` ✗, `has_comments` false | → ready for `/product-flow:build` |
| `CODE_WRITTEN` ✓, `CODE_VERIFIED` ✗ | → re-entry for `/product-flow:build` |

### Improvement flow transitions

| Condition | Sub-skill invoked |
|-----------|-------------------|
| `SPEC_CREATED` ✓, `PLAN_GENERATED` ✗, `has_comments` true | `/product-flow:consolidate-spec` |
| `SPEC_CREATED` ✓, `PLAN_GENERATED` ✗, `has_comments` false | `/product-flow:speckit.plan.improvement` |
| `PLAN_GENERATED` ✓, `TASKS_GENERATED` ✗, `has_comments` true | `/product-flow:consolidate-plan` |
| `PLAN_GENERATED` ✓, `TASKS_GENERATED` ✗, `has_comments` false | `/product-flow:tasks` |
| `TASKS_GENERATED` ✓, `CODE_WRITTEN` ✗, `has_comments` true | `/product-flow:consolidate-plan` |
| `TASKS_GENERATED` ✓, `CODE_WRITTEN` ✗, `has_comments` false | → ready for `/product-flow:build` |
| `CODE_WRITTEN` ✓, `CODE_VERIFIED` ✗ | → re-entry for `/product-flow:build` |

If a transition requires work that has no dedicated sub-skill, stop and surface the gap — do not implement it inline.

## State Machine

The workflow state is determined entirely by the flags present in `specs/<branch>/status.json` plus the dynamic `has_comments` check. There are no named virtual states — the flag combination IS the state.

**Read `flow` from `status.json` first** — this determines which routing table to apply:
- `"flow": "improvement"` → use the improvement routing table
- `"flow": "feature"` OR field absent → use the feature routing table (backward-compatible default)

**Feature flow — lifecycle order of flags:**

```
FEATURE_STARTED → DESIGN_DONE → SPEC_CREATED → SPLIT_PREPLAN_ANALIZED → PLAN_GENERATED
→ SPLIT_POSTPLAN_ANALIZED → TASKS_GENERATED → CHECKLIST_DONE → CODE_WRITTEN → VERIFY_TASKS_DONE
→ CODE_VERIFIED → IN_REVIEW → PUBLISHED
```

**Feature routing table** (evaluated top-to-bottom, first match wins):

| SPEC_CREATED | SPLIT_PREPLAN_ANALIZED | PLAN_GENERATED | SPLIT_POSTPLAN_ANALIZED | TASKS_GENERATED | CHECKLIST_DONE | CODE_WRITTEN | has_comments | → Action |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| ✓ | ✗ | ✗ | - | - | - | - | ✓ | `consolidate-spec` |
| ✓ | ✗ | ✗ | - | - | - | - | ✗ | `speckit.split` |
| ✓ | ✓ | ✗ | - | - | - | - | ✗ | `plan` |
| ✓ | ✓ | ✓ | ✗ | - | - | - | ✓ | `consolidate-plan` → then `speckit.split` |
| ✓ | ✓ | ✓ | ✗ | - | - | - | ✗ | `speckit.split` |
| ✓ | ✓ | ✓ | ✓ | ✗ | - | - | ✓ | `consolidate-plan` |
| ✓ | ✓ | ✓ | ✓ | ✗ | - | - | ✗ | `tasks` |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | - | ✓ | `consolidate-plan` |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | - | ✗ | `checklist` |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | `consolidate-plan` (clears `CHECKLIST_DONE`) |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ready for `/build` |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - | ready for `/build` (re-entry — `CODE_VERIFIED` not recorded) |

**Improvement flow — lifecycle order of flags:**

```
IMPROVEMENT_STARTED → SPEC_CREATED → PLAN_GENERATED → TASKS_GENERATED
→ CODE_WRITTEN → VERIFY_TASKS_DONE → CODE_VERIFIED → IN_REVIEW → PUBLISHED
```

**Improvement routing table** (evaluated top-to-bottom, first match wins):

| SPEC_CREATED | PLAN_GENERATED | TASKS_GENERATED | CODE_WRITTEN | has_comments | → Action |
|:---:|:---:|:---:|:---:|:---:|:---|
| ✓ | ✗ | - | - | ✓ | `consolidate-spec` |
| ✓ | ✗ | - | - | ✗ | `speckit.plan.improvement` |
| ✓ | ✓ | ✗ | - | ✓ | `consolidate-plan` |
| ✓ | ✓ | ✗ | - | ✗ | `tasks` |
| ✓ | ✓ | ✓ | ✗ | ✓ | `consolidate-plan` |
| ✓ | ✓ | ✓ | ✗ | ✗ | ready for `/build` |
| ✓ | ✓ | ✓ | ✓ | - | ready for `/build` (re-entry — `CODE_VERIFIED` not recorded) |

**Backward-compatibility note:** Branches created before the new split flags existed may have `SPLIT_DONE` (old flag) instead of `SPLIT_PREPLAN_ANALIZED`, or may have `PLAN_GENERATED` set but no `SPLIT_PREPLAN_ANALIZED` or `SPLIT_POSTPLAN_ANALIZED`. Apply these rules:
- If `SPLIT_DONE` is present: treat it as `SPLIT_PREPLAN_ANALIZED` for routing purposes.
- If `PLAN_GENERATED` is present but `SPLIT_PREPLAN_ANALIZED` is absent: treat `SPLIT_PREPLAN_ANALIZED` as implicitly set (feature predates the pre-plan split step).
- If `PLAN_GENERATED` is present but `SPLIT_POSTPLAN_ANALIZED` is absent and `TASKS_GENERATED` is also present: treat `SPLIT_POSTPLAN_ANALIZED` as implicitly set (feature predates the post-plan split step).
- If `flow` field is absent: treat as `"flow": "feature"` (branches created before improvement flow existed).

---

## Execution

### 1. Verify branch and PR

```bash
git branch --show-current
gh pr view --json number,state,url,body
```

- If the branch is `main` or `master`: ERROR "There is no active feature. Use /product-flow:start-feature to start a new feature, or /product-flow:start-improvement for a small change to something already live."
- If there is no PR: ERROR "There is no open PR. Did you run /product-flow:start-feature or /product-flow:start-improvement?"

### 1a. Sync with remote

```bash
git pull origin HEAD
```

If the pull fails (conflicts or network error): ERROR "Could not sync with remote. Resolve any conflicts and try again."

### 1c. Load gathered context

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/gathered-context.md" 2>/dev/null
```

If the file exists, load it silently as background context. It contains the full feature description, visual assets, external docs, and product clarifications collected at feature start. Use it to inform any decisions or clarifications that arise during this session — do not re-ask questions already answered there.

### 1b. Inbox

Invoke `/product-flow:inbox-sync`.

### 2. Determine current state

Read `specs/<branch>/status.json`:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null || echo "{}"
```

Extract `flow` field first — this determines which routing table to apply:
- `"flow": "improvement"` → use the improvement routing table
- `"flow": "feature"` OR field absent → use the feature routing table

For **feature flow**, extract flags: `SPEC_CREATED`, `SPLIT_PREPLAN_ANALIZED`, `PLAN_GENERATED`, `SPLIT_POSTPLAN_ANALIZED`, `TASKS_GENERATED`, `CHECKLIST_DONE`, `CODE_WRITTEN`, `CODE_VERIFIED`.

For **improvement flow**, extract flags: `SPEC_CREATED`, `PLAN_GENERATED`, `TASKS_GENERATED`, `CODE_WRITTEN`, `CODE_VERIFIED`.

For `has_comments`: invoke `/product-flow:pr-comments pending` and `/product-flow:pr-comments read-answers` in parallel.
- If `pending` returns non-empty UNANSWERED comments → `has_comments = true`.
- If `read-answers` returns any new unprocessed answers → `has_comments = true`.
- If both return empty/`NO_USER_RESPONSES` → `has_comments = false`.

**Backward-compatibility normalization** — run before routing:

```bash
# Rule 1: SPLIT_DONE (old flag) → SPLIT_PREPLAN_ANALIZED
if echo "$EXISTING" | jq -e '.SPLIT_DONE' > /dev/null 2>&1 && \
   ! echo "$EXISTING" | jq -e '.SPLIT_PREPLAN_ANALIZED' > /dev/null 2>&1; then
  EXISTING=$(echo "$EXISTING" | jq '.SPLIT_PREPLAN_ANALIZED = .SPLIT_DONE | del(.SPLIT_DONE)')
fi

# Rule 2: PLAN_GENERATED present but SPLIT_PREPLAN_ANALIZED absent → treat as implicitly set
if echo "$EXISTING" | jq -e '.PLAN_GENERATED' > /dev/null 2>&1 && \
   ! echo "$EXISTING" | jq -e '.SPLIT_PREPLAN_ANALIZED' > /dev/null 2>&1; then
  EXISTING=$(echo "$EXISTING" | jq '.SPLIT_PREPLAN_ANALIZED = "implicit"')
fi

# Rule 3: PLAN_GENERATED + TASKS_GENERATED present but SPLIT_POSTPLAN_ANALIZED absent → treat as implicitly set
if echo "$EXISTING" | jq -e '.PLAN_GENERATED' > /dev/null 2>&1 && \
   echo "$EXISTING" | jq -e '.TASKS_GENERATED' > /dev/null 2>&1 && \
   ! echo "$EXISTING" | jq -e '.SPLIT_POSTPLAN_ANALIZED' > /dev/null 2>&1; then
  EXISTING=$(echo "$EXISTING" | jq '.SPLIT_POSTPLAN_ANALIZED = "implicit"')
fi
```

Apply the routing table from the State Machine section above. Evaluate rows top-to-bottom — first match wins.

### 3. Display current state

Show the active action before doing anything:

| Action | Message |
|--------|---------|
| `consolidate-spec` | `📝 Integrating spec feedback from the team...` |
| `speckit.split` (pre-plan) | `✂️ Checking spec scope before planning...` |
| `speckit.split` (post-plan) | `✂️ Checking plan scope before breaking into tasks...` |
| `plan` | `🗺️ Spec ready. Generating the technical plan...` |
| `speckit.plan.improvement` | `🗺️ Spec ready. Generating the improvement plan...` |
| `consolidate-plan` | `📋 Integrating plan feedback from the team...` |
| `tasks` | `✂️ Plan ready. Breaking down into development tasks...` |
| `checklist` | `✅ Tasks ready. Validating requirements...` |
| ready for `/build` | `🚀 Everything is ready. Run /product-flow:build to start building.` |
| ready for `/build` (re-entry) | `⚠️ Code was written but verification was not completed. Running /product-flow:build to verify.` |

### 4. Execute transition

#### → consolidate-spec

Invoke `/product-flow:consolidate-spec`.
Wait for it to finish. If ERROR: propagate and stop.

Then **within this same invocation**, re-evaluate the routing table from step 2 — `SPLIT_PREPLAN_ANALIZED` is still absent, so the next action is `speckit.split`. Proceed immediately to `→ speckit.split (pre-plan)` below.

#### → speckit.split (pre-plan)

Invoke `/product-flow:speckit.split`.
Wait for it to finish. If ERROR: propagate and stop.

Then **within this same invocation**, proceed immediately to `→ plan` below.

#### → speckit.split (post-plan)

Invoke `/product-flow:speckit.split`.
Wait for it to finish. If ERROR: propagate and stop.

If the split was executed (a new branch was created): the parent plan was reset. Show:

```
✂️ Post-plan split complete. Plan has been reset for the reduced scope.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run /product-flow:continue to regenerate the plan for the trimmed feature.
─────────────────────────────────────────
```

**STOP.** (Do not auto-proceed to tasks — the plan must be regenerated first.)

If no split was executed: proceed immediately to `→ tasks` below.

#### → speckit.plan.improvement

Invoke `/product-flow:speckit.plan.improvement`.
Wait for it to finish. If ERROR: propagate and stop.

After generating, show:

```
✅ Improvement plan generated.

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run /product-flow:continue to proceed to build,
or add comments on the PR first if changes are needed.
─────────────────────────────────────────
```

**STOP.**

#### → plan

Before generating the plan, check for unresolved spec ambiguities:

```
⏳ Checking spec for ambiguities before planning...
```

Invoke `/product-flow:speckit.clarify`.

**Wait for `speckit.clarify` to finish before continuing.**

- If it reports **no critical ambiguities**: continue silently.
- If it resolves ambiguities: continue after answers are applied.
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

**STOP.**

#### → consolidate-plan

Before invoking, check whether `TASKS_GENERATED` is set and `tasks.md` actually exists:

```bash
BRANCH=$(git branch --show-current)
ls "specs/$BRANCH/tasks.md" 2>/dev/null
```

If `TASKS_GENERATED` is set but `tasks.md` does **not** exist (stale flag from a manual rollback):

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE")
echo "$EXISTING" | jq 'del(.TASKS_GENERATED)' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: remove stale TASKS_GENERATED flag"
```

Invoke `/product-flow:safe-push`.

Then re-evaluate state from step 2 with the corrected `status.json`.

Otherwise, invoke `/product-flow:inbox-sync` to get the latest state from the PR before evaluating answers.

Re-run `/product-flow:pr-comments pending` and `/product-flow:pr-comments read-answers` in parallel:
- If new unprocessed answers found: invoke `/product-flow:consolidate-plan`. Wait for it to finish. If ERROR: propagate and stop.
- If `NO_USER_RESPONSES` (UNANSWERED comments exist but no user answers found): list the pending questions and STOP:

```
🚫 There are unanswered questions on the PR that must be resolved before continuing.

**Pending questions:**

<list each UNANSWERED comment with its question number, type, and content>

Please reply on the PR for each open question, then run `/product-flow:continue` again.

Link: <PR_URL>
```

Then **within this same invocation**, re-evaluate the routing table — `consolidate-plan` may have cleared `CHECKLIST_DONE` if it was set, or the routing may now point to `speckit.split` (post-plan) if `SPLIT_POSTPLAN_ANALIZED` is not yet set. Proceed to the next matching action.

#### → tasks

Invoke `/product-flow:tasks`.

**Wait for `/product-flow:tasks` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

Then **within this same invocation**, proceed immediately to `→ checklist` below.

#### → checklist

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

**STOP.**

#### → ready for /build (re-entry)

Show:

```
─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run: /product-flow:build
  → The code was written but verification was not completed.
    Build will run verification only — no re-implementation.
─────────────────────────────────────────
```

**STOP.**

#### → ready for /build

Show reminder about AI-answered comments:

```
💬 REMINDER — Before building, review the decisions recorded on the PR.
   · Technical decisions: answered autonomously by the AI on your behalf.
   · Product decisions: taken together with you during spec and planning.
   If anything looks wrong, reply with: Question <N>. Answer: [your preference]
   Link: <PR_URL>
```

Use the `AskUserQuestion` tool to ask:

```
Do you want to start building, or would you like to make adjustments first?
```

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
