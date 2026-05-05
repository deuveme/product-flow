---
description: "Starts a small improvement to an already-deployed feature. Lighter flow than start-feature: no split analysis, no event modeling, no checklist phase. Still creates a PR for team review."
model: haiku
effort: low
---

## User Input

```text
$ARGUMENTS
```

Improvement description in natural language. **Required.**
If empty: ERROR "Describe the improvement. Example: /product-flow:start-improvement The empty state on the dashboard needs better copy and a call-to-action button"

---

## Execution

### 1. Verify clean starting point

```bash
git status --porcelain
git branch --show-current
```

- If there are uncommitted changes: ERROR "There are unsaved changes. Save or discard them before starting a new improvement."
- If the current branch matches `^[0-9]{8}-[0-9]{4}-`: **RESUMPTION MODE** — the user is returning to an interrupted session. Set `BRANCH_NAME` from the current branch name and skip to step 3 (Information gathering). Read `improvement-context.md` to determine which steps are already done.
- If the current branch is not `main` or `master` (and not a feature branch):
  ```bash
  git checkout main
  git pull
  ```
  Show: `ℹ️  Switched to main to start the new improvement.` and continue normally.

---

### 2. Generate branch identity and open Draft PR

#### 2a. Generate short name

From `$ARGUMENTS`, generate a concise short name (2–4 words, kebab-case, action-noun format).
Examples: `empty-state-copy`, `fix-error-message`, `button-redesign`.
Preserve technical terms (OAuth2, API, JWT, etc.).

#### 2b. Create branch and initialize directory

Substitute the short name from step 2a for `<short-name>`, then run as a single Bash command:

```bash
SHORT_NAME="<short-name>"
BRANCH_NUMBER=$(date -u +%Y%m%d-%H%M)
BRANCH_NAME="${BRANCH_NUMBER}-improvement-${SHORT_NAME}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
git checkout -b "$BRANCH_NAME" || {
  echo "ERROR: Failed to create branch $BRANCH_NAME"; exit 1
}
FEATURE_DIR="$REPO_ROOT/specs/$BRANCH_NAME"
mkdir -p "$FEATURE_DIR/images"
echo "BRANCH_NAME=$BRANCH_NAME"
```

Read `BRANCH_NAME` and `BRANCH_NUMBER` from the command output. Set `SPEC_PATH = specs/$BRANCH_NAME/spec.md`.

Derive human-readable PR title:
```
BRANCH_SLUG=${BRANCH_NAME#${BRANCH_NUMBER}-}
BRANCH_SLUG_SPACES=${BRANCH_SLUG//-/ }
PR_TITLE="$BRANCH_NUMBER: <capitalize first letter of BRANCH_SLUG_SPACES>"
```
Example: `20260502-1430-improvement-empty-state-copy` → `20260502-1430: Improvement empty state copy`.

#### 2d. Initialize improvement-context.md

Create `specs/$BRANCH_NAME/improvement-context.md` immediately:

```markdown
# Improvement Context

> Collected during /product-flow:start-improvement. Use this as authoritative input — do not re-ask any question already answered here.

## What to improve

_pending_

## Location

_pending_

## What should change for the user

_pending_

## Out of scope

_pending_

## Known constraints

_pending_

## Visual Assets

### Uploaded Images
None provided.

### External Links
None provided.

### Descriptions
None provided.
```

#### 2e. Push branch and open Draft PR

```bash
git push -u origin HEAD
```

Run this Bash command and set `PR_DATE` to its exact output:

```bash
date -u +"%Y-%m-%d %H:%M:%S"
```

```bash
gh pr create \
  --title "$PR_TITLE" \
  --draft \
  --base main \
  --body "$(cat <<EOF
**Type:** 🔧 Improvement

## Improvement
Spec: $SPEC_PATH

## Status
- [ ] Spec created
- [ ] Plan generated
- [ ] Tasks generated
- [ ] Code generated
- [ ] In code review
- [ ] Published

## How to test

### For PM
*To be populated when the implementation is submitted for review.*

### For Devs
*To be populated when the implementation is submitted for review.*

## History

| Status | Date Time | GitHub User | Note |
|--------|-----------|-------------|------|
| PR created | $PR_DATE | @$(gh api user --jq '.login') | Improvement started |

## Notes

## For Developers
*PMs and designers can ignore this section.*

### Checklist

<!-- dev-checklist -->
- [ ] **Spec** — pending
- [ ] **Plan** — pending
- [ ] **Tasks** — pending
- [ ] **Implementation** — pending
<!-- /dev-checklist -->
EOF
)"
```

Save the returned PR URL as `PR_URL` and PR number as `PR_NUMBER`.

#### 2f. Record improvement started

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$EXISTING" | jq --arg ts "$NOW" '. + {"IMPROVEMENT_STARTED": $ts, "flow": "improvement"}' > "$STATUS_FILE"
git add "specs/$BRANCH_NAME/"
git commit -m "chore: initialize improvement branch and context"
```

If the commit fails with a GPG error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:start-improvement again.
```
**STOP.**

Invoke `/product-flow:safe-push`.

Show:
```
🌱 Improvement started. Let's capture what needs to change...
```

---

### 3. Information gathering

If in RESUMPTION MODE: read `improvement-context.md` to determine which fields are already filled. Skip any dimension whose value is not `_pending_`. For Dimension 4 (Visual assets): skip it only if all three subsections (`Uploaded Images`, `External Links`, `Descriptions`) have been explicitly updated from `None provided.` — meaning the user was already asked. If all three still say `None provided.`, include Dimension 4 as pending.

Ask the 3 dimensions below **one at a time** using `AskUserQuestion`. For each:
- If clearly answered in `$ARGUMENTS`: infer the answer, update the file, write a PR comment. Do not ask.
- Otherwise: ask, wait for the answer, update `improvement-context.md`, write a PR comment.

**After each answer**, immediately update `specs/$BRANCH_NAME/improvement-context.md` — replace the `_pending_` value with the answer.

---

**Dimension 1 — What to improve + Location**

> "What specifically isn't working well, and where in the app does it happen? (Which screen, component, or flow?)"

- Answer goes to: `## What to improve` and `## Location` in `improvement-context.md`
- PR comment: `type: product, status: ANSWERED`

---

**Dimension 2 — What should change for the user**

> "What should be different after this improvement? Describe what the user will see or experience that they don't today."

After receiving the answer, push back once if it only describes what to build rather than the change:
> "That describes what to build. What will be different for the user once it's done — what can they do or see that they can't today?"

Accept whatever comes back. Do not push more than once.

- Answer goes to: `## What should change for the user` in `improvement-context.md`
- PR comment: `type: product, status: ANSWERED`

---

**Dimension 3 — Out of scope + Constraints**

> "What should we NOT change as part of this improvement? Any known constraints (deadlines, business rules, technical limits)?"

If the answer is empty or vague, push back once:
> "What might a developer assume is included that isn't? Anything related that we're intentionally leaving for later?"

Accept whatever comes back. "None" is a valid answer for constraints.

- Answer goes to: `## Out of scope` and `## Known constraints`
- PR comment: `type: product, status: ANSWERED`

---

**Dimension 4 — Visual assets**

Use `AskUserQuestion` to ask:

> "Do you have any screenshots, designs, Figma links, or visual references for this improvement? If so, share them now (images, links, or descriptions)."

If the user shares assets:
- **Uploaded image files**: save each file to `specs/$BRANCH_NAME/images/<descriptive-name>.<ext>` using the Write tool. Update `## Visual Assets > Uploaded Images` in `improvement-context.md` with a relative link to each file.
- **External links** (Figma, screenshots hosted elsewhere, etc.): create `specs/$BRANCH_NAME/images/sources.md` listing all links. Update `## Visual Assets > External Links` in `improvement-context.md`.
- **Text descriptions**: update `## Visual Assets > Descriptions` in `improvement-context.md` with the descriptions provided.

If the user shares one or more image files or links, immediately ask a follow-up via `AskUserQuestion`:

> "For each image or link you shared, tell me: (1) what screen or component it shows, and (2) what it represents — is it the current state, the target design, or a reference (style, color, layout, etc.)?"

Use the answers to generate `specs/$BRANCH_NAME/images/index.md`:

```markdown
# Visual Assets Index

| File / Link | What it shows | Screen / Component | Role |
|-------------|--------------|-------------------|------|
| <filename or URL> | <what the user said it shows> | <screen or component> | <current-state | target | reference | flow-diagram | other> |
```

Valid roles: `current-state` (existing UI), `target` (what to build), `reference` (style/color/layout guide), `flow-diagram` (user flow), `other`.

If the user shares nothing: leave all `## Visual Assets` subsections as `None provided.` and do not create `index.md`.

Do not write a PR comment for this dimension.

---

### 3b. Scope analysis

Evaluate the gathered context against these escalation triggers. If ANY apply, stop and ask the user:

**Escalation triggers:**
- The improvement introduces a completely new user flow (not modifying an existing one)
- The improvement requires new database tables or schema migrations
- The improvement requires a new external service or major dependency
- The "What should change" answer describes functionality that doesn't exist yet (not a modification)
- Three or more unrelated screens or subsystems need to change

If any trigger fires, use AskUserQuestion:

```
⚠️  This sounds like it may be a new feature rather than an improvement to an existing one.

[Describe the specific signal that fired]

/product-flow:start-improvement works best for modifying something that already exists.
/product-flow:start-feature is better suited for building something new.

How would you like to proceed?
```

Options: `Continue as improvement` / `Restart as a feature with /product-flow:start-feature`

If the user chooses to restart: clean up the branch and PR, then stop.

```bash
gh pr close $PR_NUMBER
git checkout main
git branch -D $BRANCH_NAME
git push origin --delete $BRANCH_NAME
```

Show: `Branch and PR cleaned up. Run /product-flow:start-feature with your description.`
**STOP.**

---

### 4. Write spec

Invoke `/product-flow:speckit.specify.improvement`.

**Wait for it to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

---

### 5. Final report

```
✅ Improvement started

📋 Spec:   $SPEC_PATH
🌿 Branch: $BRANCH_NAME
🔗 PR:     $PR_URL

─────────────────────────────────────────
➡️  NEXT STEP
─────────────────────────────────────────
Share the PR with the development team
so they can review the spec.

When they approve or comment, run:
/product-flow:continue
─────────────────────────────────────────
```

---

### Session close

Invoke `/product-flow:context`.
