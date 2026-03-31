---
description: "STEP 1 — Starts a new feature. Creates the draft PR and kicks off the specification process."
---

## User Input

```text
$ARGUMENTS
```

Feature description in natural language. **Required.**
If empty: ERROR "Describe the feature. Example: /product-flow:start I want users to be able to reset their password"

---

## Execution

### 1. Verify clean starting point

```bash
git status --porcelain
git branch --show-current
```

- If there are uncommitted changes: ERROR "There are unsaved changes. Save or discard them before starting a new feature."
- If the current branch is not `main` or `master`:
  Run:
  ```bash
  git checkout main
  git pull
  ```
  Then show: `ℹ️  Switched to main to start the new feature.` and continue normally.

### 2. Generate branch identity and open Draft PR

This step establishes the branch and creates the Draft PR **before** writing the spec.

#### 2a. Generate short name

From `$ARGUMENTS`, generate a concise short name (2–4 words, kebab-case, action-noun format).
Examples: `user-auth`, `fix-payment-timeout`, `analytics-dashboard`.
Preserve technical terms (OAuth2, API, JWT, etc.).

#### 2b. Find next branch number

```bash
git fetch --all --prune
git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-'
git branch | grep -E '^[* ]*[0-9]+-'
ls specs/ 2>/dev/null | grep -E '^[0-9]+-'
```

Extract all numbers found across the three sources. If none, use `1`. Otherwise use highest + 1.
Zero-pad the number to 3 digits: `printf "%03d" $N`.

Set:
- `BRANCH_NUMBER = <NNN>`
- `BRANCH_NAME = <NNN>-<short-name>` (e.g., `001-user-auth`)
- `SPEC_PATH = specs/$BRANCH_NAME/spec.md`

#### 2c. Create the branch

```bash
.specify/scripts/bash/create-new-feature.sh --json "$ARGUMENTS" --number <N> --short-name "<short-name>"
```

The script output (JSON) is the **authoritative source** for `BRANCH_NAME` and `SPEC_FILE`. Always read these values from the JSON output and update `BRANCH_NAME` and `SPEC_PATH` accordingly.

> **Invariant**: `BRANCH_NAME` and the spec folder name (`specs/$BRANCH_NAME/`) must always be identical. Never create the PR (step 2e) until `BRANCH_NAME` is confirmed from the script output.

Derive the human-readable PR title from `BRANCH_NAME`:
```
BRANCH_NUMBER=${BRANCH_NAME%%-*}
BRANCH_SLUG=${BRANCH_NAME#*-}
PR_TITLE="$BRANCH_NUMBER: ${BRANCH_SLUG//-/ }"
```
Example: `001-user-auth` → `001: User auth`.

#### 2d. Push the branch

```bash
git push -u origin HEAD
```

#### 2e. Open Draft PR

```bash
gh pr create \
  --title "$PR_TITLE" \
  --draft \
  --base main \
  --body "$(cat <<EOF
## Feature
Spec: $SPEC_PATH

## Status
- [ ] Spec created
- [ ] Plan generated
- [ ] Tasks generated
- [ ] Code generated
- [ ] In code review
- [ ] Published

## History

| Status | Date | Note |
|--------|-------|------|
| PR created | $(date +%Y-%m-%d) | Feature started |

## Notes
EOF
)"
```

Save the returned PR URL as `PR_URL` and PR number as `PR_NUMBER`.

### 3. Write spec (delegate to speckit.specify)

Invoke `/product-flow:speckit.specify` passing `$ARGUMENTS` as the feature description, applying the following question management rules:

**Note**: The branch `$BRANCH_NAME` has already been created and pushed. When `speckit.specify` runs, it will detect the existing feature branch and skip branch creation, proceeding directly to writing the spec.

**Question classification** — when `speckit.specify` identifies `[NEEDS CLARIFICATION]` markers, classify each one before presenting it:

- **Non-technical** (ask the PM): business intent, priorities, functional scope, user flows, terminology. **NEVER resolve autonomously. Always surface to the PM and wait for their answer.**
- **Technical** (resolve autonomously): authentication, authorisation, security, compliance, data retention, integration patterns, infrastructure constraints.

**For technical questions**, do NOT ask the PM. Instead:
1. Answer them using project context: existing code, `.agents/rules/base.md`, detected project stack, industry standards.
2. If there is sufficient information: make the decision and record it internally as **AI-proposed decision**.
3. If there is not sufficient information: record it internally as **Unresolved question** and continue.

Save the list of technical decisions (resolved and unresolved) internally for step 5.

`speckit.specify` will:
- Detect the existing branch and skip branch creation
- Write `$SPEC_PATH`
- Generate the quality checklist
- Ask clarification questions if there are any

**Wait for `speckit.specify` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 4. Update PR — mark spec created

Update the PR body to reflect spec completion:

```bash
gh pr edit $PR_NUMBER --body "$(cat <<EOF
## Feature
Spec: $SPEC_PATH

## Status
- [x] Spec created
- [ ] Plan generated
- [ ] Tasks generated
- [ ] Code generated
- [ ] In code review
- [ ] Published

## History

| Status | Date | Note |
|--------|-------|------|
| PR created | $(date +%Y-%m-%d) | Feature started |
| Spec created | $(date +%Y-%m-%d) | Spec written |

## Notes
EOF
)"
```

### 5. Record technical decisions in the PR

For each technical decision made, invoke `/product-flow:pr-comments write`
following the technical decision format (ANSWERED/UNANSWERED).
Skip if no technical decisions were made.

### 6. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after specify phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 7. Final report

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

When they approve or comment, run:
/product-flow:continue
─────────────────────────────────────────
```

### Session close

Invoke `/product-flow:context`.
