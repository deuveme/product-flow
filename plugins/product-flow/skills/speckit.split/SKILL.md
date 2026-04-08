---
description: "Analyzes a spec for scope creep, proposes a split, and creates a new branch+PR for the extracted feature."
user-invocable: false
model: opus
effort: high
handoffs:
  - label: Continue Current Feature
    agent: continue
    prompt: Continue with the reduced spec
    send: true
  - label: Run Split Analysis Again
    agent: speckit.split
    prompt: ""
    send: true
---

## User Input

```text
$ARGUMENTS
```

Consider any user input above (e.g. a hint about where to split) before proceeding.

## Outline

### Step 1 — Setup

1. Run `git branch --show-current` to get BRANCH_NAME.
2. Derive FEATURE_DIR = `specs/$BRANCH_NAME`.
3. Read `$FEATURE_DIR/spec.md`. If the file does not exist: stop with `ERROR: No spec found on branch '$BRANCH_NAME'. Run /product-flow:speckit.specify first.`

### Step 2 — Split analysis

Carefully read the entire spec and evaluate it against the three signal groups below.

**Scope signals** — score 1 point if ANY of these fire:
- More than 4 user stories where at least 2 have no dependency on each other
- Two or more distinct user personas with completely different journeys (not just different permissions on the same journey)
- Requirements that could ship independently in separate releases and provide value on their own
- The spec spans multiple bounded contexts (e.g. "payments" alongside "notifications", or "user profile" alongside "audit log")
- The Overview section implies more than one standalone product decision

**Size signals** — score 1 point if ANY of these fire:
- Functional requirements section lists more than 8 distinct requirements
- Success criteria address more than 2 unrelated outcomes

**Language signals** — score 1 point if ANY of these fire in user stories or requirements:
- Coordinating conjunctions bundling distinct actions: *"and, or, but, yet"* (e.g. "User can create and manage and export reports")
- Catch-all verbs that hide multiple operations: *"manage, handle, support, administer"*
- Sequence words implying separate flows: *"before, after, then, once X is done"*
- Scope accretion words: *"including, additionally, plus, as well as"*
- Option indicators: *"either/or, optionally, if the user wants"*
- Exception carve-outs: *"except when, unless, however in the case of"*

**Split worthiness score (0–3):**
- Score 0 → no split needed
- Score 1 → optional split
- Score 2–3 → recommended split

If the user provided input (e.g. "split out the notifications part"), treat that as a strong override signal and proceed directly to proposing the split they described — skip the scoring.

### Step 2b — Vertical slice validation (only if score ≥ 1)

Before proposing the split, validate that each resulting feature would form a true vertical slice — end-to-end usable by someone, not a horizontal layer (e.g. "only the backend" or "only the admin screen").

For each proposed feature, ask:
- Does it deliver something a real user or stakeholder can use on day one?
- Does it work end-to-end without depending on the other feature being built first?
- Could it be deployed and provide value independently in production?

If a proposed Feature B fails these checks, reconsider the split boundary until both features pass. A horizontal split (e.g. "data layer now, UI later") is not a valid split — it's just deferred work.

### Step 2c — Expand-contract warning (only if score ≥ 1)

Check whether the two proposed features share entities from the spec's data model or key requirements. Shared entities create integration risk at the boundary.

Flag expand-contract needed if:
- Both features read or write the same core entity (e.g. both touch `Order`, `User`, `Payment`)
- One feature produces data the other consumes (producer/consumer relationship)
- A requirement in Feature B depends on state managed by Feature A

If any flag fires, note it — this will be surfaced in the report and in the PR comment so the team knows to apply the expand-contract pattern when implementing.

### Step 3 — Present analysis and ask the user

Print a structured report. Be specific: name the actual user stories, requirements, and language patterns found — don't use placeholders.

```
## Split Analysis: [Feature name from spec]

**Score: N/3** — [No split needed | Optional split | Recommended split]

### Signals detected
[List each fired signal concisely, referencing specific parts of the spec. If none: "None detected."]

### Proposed split   ← only show this section if score ≥ 1
**Feature A — [BRANCH_NAME] (keep)**
- Goal: [one sentence]
- User stories retained: [list]
- Key requirements kept: [2–4 bullet points]
- Vertical slice: [one sentence confirming it's end-to-end usable]

**Feature B — [proposed-slug] (extract)**
- Goal: [one sentence]
- User stories extracted: [list]
- Key requirements moved: [2–4 bullet points]
- Why independent: [one sentence confirming they can ship separately]
- Vertical slice: [one sentence confirming it's end-to-end usable]

⚠️ Expand-contract needed: [list shared entities, or omit this line if none]
```

Then, depending on the score:

- **Score 0**: Tell the user the spec looks well-scoped and stop. No further action.
- **Score 1**: Ask via AskUserQuestion — "Optional split detected. Want to proceed?"
  - Options: `Yes, split it` / `No, keep as-is` (Recommended)
- **Score 2–3**: Ask via AskUserQuestion — "Split recommended. Proceed?"
  - Options: `Yes, split it` (Recommended) / `No, keep as-is` / `Adjust the split boundary`

If the user selects **Adjust the split boundary**: ask a free-text follow-up question asking how they want to redraw the split (e.g. "Which user stories or requirements should move to the new feature?"). Then re-run Steps 2–2c with their guidance and loop back to Step 3.

If the user selects **No** (or score was 0): confirm the spec stays intact and stop.

### Step 3b — Record the analysis and decision as a PR comment

After receiving the user's answer (including the score-0 case), post a comment on the current PR via `/product-flow:pr-comments write` so the decision is traceable.

If no PR exists yet for this branch, skip this step silently (check with `gh pr view --json number` first).

Invoke `/product-flow:pr-comments write` with:
- `type: product`
- `status: ANSWERED`
- `body`:

```
**Split analysis — Score: N/3** — [No split needed | Optional split | Recommended split]

**Signals detected:**
[same list as shown to the user, or "None — spec is well-scoped."]

**Proposed split:**
Feature A — [BRANCH_NAME] (keep): [one-line goal] · Vertical slice: ✅
Feature B — [proposed-slug] (extract): [one-line goal] — [why independent] · Vertical slice: ✅
⚠️ Expand-contract needed: [list shared entities, or omit if none]
[Omit the "Proposed split" block entirely if score was 0]

**Decision: [User's answer verbatim — e.g. "Yes, split it" / "No, keep as-is" / "Adjust the split boundary" / "No split proposed"]**
```

### Step 4 — Execute split (only if user confirmed Yes)

Run steps 4a through 4g in order. Do not skip any.

**Important sequencing rule**: create and populate the new branch first (4a–4d), then return to the original branch to trim it (4e–4g). This avoids uncommitted changes being lost during branch switches.

#### 4a. Determine the new branch identity

- Derive a 2–4 word short name from the extracted feature (kebab-case, action-noun format, e.g. `notifications-engine`, `audit-log`). Set SHORT_NAME.
- Run `git fetch --all --prune`
- Find the highest feature number across all three sources:
  - Remote branches: `git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-'`
  - Local branches: `git branch | grep -E '^[* ]*[0-9]+-'`
  - Specs directories: `ls specs/ 2>/dev/null | grep -E '^[0-9]+-'`
- Compute next number: highest N + 1, zero-padded to 3 digits (`printf "%03d" $((N+1))`). If nothing found, use `001`. Set BRANCH_NUMBER.
- Set NEW_BRANCH = `BRANCH_NUMBER-SHORT_NAME` (e.g. `004-notifications-engine`)
- Derive human-readable PR title (capitalize the first word after the colon):
  ```bash
  SLUG_WORDS="${SHORT_NAME//-/ }"
  PR_TITLE="$BRANCH_NUMBER: ${SLUG_WORDS^}"
  ```
  Example: `004-notifications-engine` → `004: Notifications engine`
- Set NEW_SPEC_PATH = `specs/$NEW_BRANCH/spec.md`

#### 4b. Create the new branch

Switch to main, pull, then create the branch and feature directory directly:

```bash
git checkout main
git pull
git checkout -b "$NEW_BRANCH" || {
  echo "ERROR: Failed to create branch $NEW_BRANCH"; exit 1
}
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
NEW_FEATURE_DIR="$REPO_ROOT/specs/$NEW_BRANCH"
mkdir -p "$NEW_FEATURE_DIR"
NEW_SPEC_PATH="$NEW_FEATURE_DIR/spec.md"
```

`NEW_BRANCH` and `NEW_SPEC_PATH` are now confirmed from the steps above.

#### 4c. Write the extracted spec on the new branch

Still on `NEW_BRANCH`, write `NEW_SPEC_PATH` with the extracted content. Use the same spec template structure as the original (same section headings). Populate it with:
- Overview focused on the extracted goal
- The extracted user stories and their acceptance criteria
- The extracted requirements
- Relevant success criteria
- A `## Related Features` section pointing back to the original branch:

  ```markdown
  ## Related Features
  - **[BRANCH_NAME]**: [one-line description of the parent feature]
  ```

- If expand-contract was flagged, add to the Assumptions section:

  ```markdown
  - Shared entities with [BRANCH_NAME] ([entity names]) require expand-contract coordination during implementation. See /product-flow:praxis.expand-contract.
  ```

#### 4d. Commit, push, and open a draft PR for the new feature

Write `status.json` for the new feature before committing:

```bash
STATUS_FILE="specs/$NEW_BRANCH/status.json"
echo "{}" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"spec_created": $ts}' > "$STATUS_FILE"
```

```bash
git add specs/$NEW_BRANCH/
git commit -m "feat: extract $SHORT_NAME spec from $BRANCH_NAME"
git push -u origin HEAD
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:speckit.split again.
```
**STOP.**

Then open the draft PR. Because the spec is already written at this point, mark it as done immediately:

```bash
gh pr create \
  --title "$PR_TITLE" \
  --draft \
  --base main \
  --body "$(cat <<EOF
## Feature
Spec: $NEW_SPEC_PATH

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
| PR created | $(date +%Y-%m-%d) | Extracted from $BRANCH_NAME |
| Spec created | $(date +%Y-%m-%d) | Spec written during split |

## Notes
EOF
)"
```

Save the returned URL as `NEW_PR_URL`.

#### 4e. Return to the original branch and trim the spec

Now that the new branch is fully set up, go back and remove the extracted content from the original spec:

```bash
git checkout $BRANCH_NAME
```

Edit `$FEATURE_DIR/spec.md`:
- Remove the extracted user stories and their acceptance criteria
- Remove the requirements that belong exclusively to the extracted feature
- Remove success criteria that address only the extracted feature
- Preserve everything else: the Overview, all retained user stories, retained requirements, Assumptions
- Append (or create) a `## Related Features` section at the bottom:

  ```markdown
  ## Related Features
  - **[NEW_BRANCH]**: [one-line description of what was extracted]
  ```

- If expand-contract was flagged, add to the Assumptions section:

  ```markdown
  - Shared entities with [NEW_BRANCH] ([entity names]) require expand-contract coordination during implementation. See /product-flow:praxis.expand-contract.
  ```

#### 4f. Commit and push the trimmed spec

```bash
git add specs/$BRANCH_NAME/
git commit -m "feat: remove extracted scope ($NEW_BRANCH) from spec"
git push
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:speckit.split again.
```
**STOP.**

#### 4g. Update the current PR body to record the split in History

If no PR exists for the current branch, skip this step silently.

Get the current PR number and body:

```bash
ORIG_PR_NUMBER=$(gh pr view --json number -q '.number')
ORIG_PR_BODY=$(gh pr view --json body -q '.body')
```

Reconstruct the body by appending a new row to the History table. Take `ORIG_PR_BODY` as the base, find the History table, and add after the last existing row:

```
| Scope extracted | $(date +%Y-%m-%d) | $SHORT_NAME split to $NEW_BRANCH — $NEW_PR_URL |
```

Then update the PR:

```bash
gh pr edit $ORIG_PR_NUMBER --body "<reconstructed body>"
```

### Step 5 — Report

Print a clean summary:

```
## Split Complete

**$BRANCH_NAME** — spec trimmed, extracted stories removed
  Spec: specs/$BRANCH_NAME/spec.md

**$NEW_BRANCH** — new branch created with draft PR
  Spec: $NEW_SPEC_PATH
  PR: $NEW_PR_URL

[If expand-contract was flagged:]
⚠️  Shared entities detected: [list]. Apply /product-flow:praxis.expand-contract when implementing both features in parallel.

Next steps:
- Continue current feature:  /product-flow:continue
- Start extracted feature:   /product-flow:status  (switch to $NEW_BRANCH)
```

## Key rules

- Never delete content without the user's confirmation — the ask in Step 3 is the gate.
- Every proposed split must pass vertical slice validation (Step 2b) before being shown to the user — never propose a horizontal cut.
- The split must be clean: no requirement should appear in both specs after the split.
- If a requirement is shared (both features need it), keep it in Feature A and reference it from Feature B's spec under a "Dependencies" or "Assumptions" section.
- Never commit to the original branch until the new branch is fully set up and pushed (steps 4a–4d complete first).
- Use absolute paths when reading or writing files.
