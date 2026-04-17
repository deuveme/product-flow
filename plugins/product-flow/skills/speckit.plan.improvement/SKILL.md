---
description: "Generates a lean technical plan for a start-improvement branch. Max 1 page: which files to touch and why. No event modeling, no architecture validation, no contracts."
user-invocable: false
model: sonnet
effort: low
---

## Scope Discipline

- **Design only what the spec requires.** Every file listed must trace to an acceptance criterion in `spec.md`.
- **The simplest change that satisfies the spec is the correct change.** Do not add abstractions, refactors, or new patterns not required by this improvement.
- **No new subsystems.** If this improvement would require introducing a new service, queue, cache, or major dependency — stop and surface this to the user. This improvement may need to be promoted to a full feature.

## Execution

### 1. Setup

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
BRANCH=$(git branch --show-current)
FEATURE_DIR="$REPO_ROOT/specs/$BRANCH"
SPEC_FILE="$FEATURE_DIR/spec.md"
PLAN_FILE="$FEATURE_DIR/plan.md"
```

If `SPEC_FILE` does not exist: ERROR "spec.md not found. Run /product-flow:continue to generate the spec first."

Read the spec and improvement context:

```bash
cat "$SPEC_FILE"
cat "$FEATURE_DIR/improvement-context.md" 2>/dev/null
```

Explore the codebase to understand where the relevant code lives:

```bash
git ls-files | head -100
```

Read the relevant source files identified from the spec — focus on files most likely to change.

### 2. Complexity check

Before writing the plan, assess whether the improvement is truly small:

**Escalation triggers** — if ANY of these apply, stop and ask the user:
- The change requires introducing a new database table or schema migration
- The change requires a new external service or major dependency
- The change touches more than ~8 unrelated files
- The change requires coordinating changes across multiple independent subsystems
- The spec acceptance criteria reveal this is actually a new feature, not a modification of existing behavior

If an escalation trigger fires, use AskUserQuestion:

```
⚠️  This improvement may be larger than expected.

[Describe the specific trigger that fired]

This might be better handled as a full feature with /product-flow:start-feature, which includes
proper planning phases (architecture review, event modeling, etc.).

How would you like to proceed?
```

Options: `Continue as improvement` / `Restart as a full feature with start-feature`

If the user chooses to restart: close the PR, delete the improvement branch, and tell the user to run `start-feature` fresh.

```bash
BRANCH=$(git branch --show-current)
PR_NUMBER=$(gh pr view "$BRANCH" --json number --jq '.number' 2>/dev/null || echo "")

# Close the draft PR if it exists
[ -n "$PR_NUMBER" ] && gh pr close "$PR_NUMBER" --comment "Closing — scope escalated to a full feature." 2>/dev/null || true

# Return to main and remove the improvement branch
git checkout main
git branch -D "$BRANCH" 2>/dev/null || true
git push origin --delete "$BRANCH" 2>/dev/null || true
```

Show:
```
Improvement branch removed.
Run /product-flow:start-feature with your feature description to begin a full feature flow.
```
**STOP.**

### 3. Write plan.md

Write `$PLAN_FILE` with this structure — keep it short:

```markdown
# Plan: [Short title]

## Approach

[2–4 sentences describing the technical approach. Focus on what changes and why. No implementation details beyond file/module level.]

## Files to change

| File | What changes | Why |
|------|-------------|-----|
| `path/to/file.tsx` | [brief description] | [maps to acceptance criterion X] |
| `path/to/other.ts` | [brief description] | [maps to acceptance criterion Y] |

## Files to add (if any)

| File | Purpose |
|------|---------|
| `path/to/new.tsx` | [why a new file is needed] |

## Technical decisions

[Any non-obvious technical decision made autonomously. If none, write "None."]

## Constraints respected

[List any constraints from improvement-context.md that affect the plan. If none, write "None."]
```

**Rules:**
- No research.md, no data-model.md, no contracts/.
- No architecture diagrams, no event modeling.
- The "Files to change" table must be exhaustive — every file that will need a code change.
- If a file path is uncertain, note it with `(approximate)` and explain why.

### 4. Technical decisions as PR comments

For each technical decision made in step 3, record it as a PR comment:

Invoke `/product-flow:pr-comments write`:
- `type`: `technical`, `status`: `ANSWERED`
- `body`:
  ```
  **Technical decision:** "[what was decided]"

  **Reasoning:** "[brief explanation]"
  ```

Skip if no technical decisions were made.

### 5. Persist and update PR

```bash
git add "$PLAN_FILE"
git commit -m "docs: write improvement plan"
git push origin HEAD
```

If the commit fails with a GPG error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:continue again.
```
**STOP.**

Write `PLAN_GENERATED` to `specs/$BRANCH/status.json`:

```bash
STATUS_FILE="$FEATURE_DIR/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"PLAN_GENERATED": $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record plan_generated"
git push origin HEAD
```

Update the PR body — mark plan generated:
- Mark `- [x] Plan generated` in `## Status`
- Replace `- [ ] **Plan** — pending` with `- [x] **Plan** — complete · $PLAN_FILE` inside `<!-- dev-checklist -->`
- Add row to `## History`: `| Plan generated | YYYY-MM-DD HH:MM:SS | @github-user | Improvement plan written |`

```bash
gh pr edit --body "<updated-body>"
```

### 6. Report

```
🗺️ Plan written: specs/<branch>/plan.md

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Run /product-flow:continue to proceed to build,
or add comments on the PR first if changes are needed.
─────────────────────────────────────────
```
