---
description: "STEP 1 — Starts a new feature. Creates the draft PR and kicks off the specification process."
model: sonnet
effort: low
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

### 2. Information gathering

This step is **mandatory** and runs every time, before any branch or spec is created. Its purpose is to collect all available context so that the spec can be written with full information and without assumptions.

#### 2a. Ask for more context

Use `AskUserQuestion` to ask:

> "Before I start writing the spec, I need a bit more context. Can you tell me more about what you have in mind? Feel free to share details about user flows, expected behaviour, constraints, business goals, or anything else that might be relevant."

Wait for the user's response. If they provide additional information, store it together with `$ARGUMENTS` as `FULL_DESCRIPTION`. If they reply with nothing new, `FULL_DESCRIPTION = $ARGUMENTS`.

#### 2b. Ask about visual assets

Use `AskUserQuestion` to ask:

> "Do you have any designs, wireframes, screenshots, Figma links, or similar visual references for this feature? If so, please share them now (links, images, or descriptions)."

If the user shares assets, record them as `VISUAL_ASSETS`. If not, record `VISUAL_ASSETS = none`.

#### 2c. Ask about external documentation

Use `AskUserQuestion` to ask:

> "Is there any external documentation I should use as reference? This could include PDFs, slide decks, API docs, existing code outside this repo, requirement documents, or anything else I can't directly access. If so, paste or link them now."

If the user shares materials, record them as `EXTERNAL_DOCS`. If not, record `EXTERNAL_DOCS = none`.

#### 2d. Identify and resolve ambiguities

Carefully read `FULL_DESCRIPTION`, `VISUAL_ASSETS`, and `EXTERNAL_DOCS`. Internally produce two lists:

**Product ambiguities list**: anything that is vague, underspecified, contradictory, or missing that a PM or product owner must answer. Examples: unclear user roles, undefined acceptance criteria, missing edge cases, ambiguous scope ("all users" — which users?).

**Technical ambiguities list**: architecture, authentication, data model, performance constraints, integration patterns, security, compliance. These must be resolved autonomously (see below).

For each item in the **product ambiguities list**, ask the user one question at a time using `AskUserQuestion`. Do **not** batch questions. Do **not** assume or infer the answer — wait for explicit confirmation before moving on. Present the question clearly, and if relevant, offer concrete options to make it easier to answer.

> ⚠️ **Rule**: Do NOT assume anything in this phase. Every product ambiguity must be asked and answered before continuing.

For each item in the **technical ambiguities list**, resolve it autonomously using existing project context (codebase, `.agents/rules/base.md`, detected stack, industry standards). Record each decision internally as a **technical-decision** with:
- The question identified
- The options considered
- The chosen option and brief reasoning

These will be published as PR comments in step 7b.

#### 2e. Notify if no product ambiguities

If the **product ambiguities list** from step 2d was empty (zero questions asked), output this message to the user:

> "I have no doubts about the product requirements. I'll proceed directly to writing the spec."

#### 2f. Consolidate gathered context

Produce a single internal object `GATHERED_CONTEXT` containing:
- `full_description`: expanded feature description after conversation
- `visual_assets`: list of provided assets or "none"
- `external_docs`: list of provided materials or "none"
- `product_clarifications`: list of question → answer pairs from step 2d
- `technical_decisions`: list of resolved technical decisions from step 2d

`GATHERED_CONTEXT` will be passed as additional context to all subsequent steps.

Also write `GATHERED_CONTEXT` to disk so it survives across sessions. Create the specs directory first if needed, then write `specs/$BRANCH_NAME/gathered-context.md` (using the branch name derived in step 3 — if the branch does not exist yet, write to a temporary path and move it after step 3c). Use this format:

```markdown
# Gathered Context

> Collected during /product-flow:start before spec writing. Use this as authoritative input — do not re-ask any question already answered here.

## Full Description

<full_description>

## Visual Assets

<visual_assets — or "None provided.">

## External Documentation

<external_docs — or "None provided.">

## Product Clarifications

<for each question → answer pair:>
**Q:** <question>
**A:** <answer>

<if none: "None.">

## Technical Decisions (pre-spec)

<for each technical decision:>
**Question:** <question>
**Chosen:** <chosen option> — <brief reasoning>

<if none: "None.">
```

This file will be included in the commit at step 6b together with the rest of `specs/$BRANCH_NAME/`.

---

### 3. Generate branch identity and open Draft PR

This step establishes the branch and creates the Draft PR **before** writing the spec.

#### 3a. Generate short name

From `GATHERED_CONTEXT.full_description`, generate a concise short name (2–4 words, kebab-case, action-noun format).
Examples: `user-auth`, `fix-payment-timeout`, `analytics-dashboard`.
Preserve technical terms (OAuth2, API, JWT, etc.).

#### 3b. Find next branch number

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

#### 3c. Create the branch

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
git checkout -b "$BRANCH_NAME" || {
  echo "ERROR: Failed to create branch $BRANCH_NAME"; exit 1
}
FEATURE_DIR="$REPO_ROOT/specs/$BRANCH_NAME"
mkdir -p "$FEATURE_DIR"
SPEC_FILE="$FEATURE_DIR/spec.md"
```

> **Invariant**: `BRANCH_NAME` and the spec folder name (`specs/$BRANCH_NAME/`) must always be identical. `BRANCH_NAME` is confirmed from steps 3a–3b above.

Derive the human-readable PR title from `BRANCH_NAME`:
```
BRANCH_NUMBER=${BRANCH_NAME%%-*}
BRANCH_SLUG=${BRANCH_NAME#*-}
BRANCH_SLUG_SPACES=${BRANCH_SLUG//-/ }
PR_TITLE="$BRANCH_NUMBER: <capitalize first letter of BRANCH_SLUG_SPACES>"
```
Example: `001-user-auth` → `001: User auth`. Capitalize only the first letter of the slug; leave all other words as-is (do not title-case every word).

#### 3d. Push the branch

```bash
git push -u origin HEAD
```

#### 3e. Open Draft PR

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

### 4. Design exploration (conditional)

First, check if design exploration was already completed in a previous run:

```bash
ls "specs/$BRANCH_NAME/collaborative-design.md" 2>/dev/null
```

If the file exists, load it as `collaborative-design.md` and skip the rest of this step — use its contents as context in step 5.

Otherwise, assess the feature description using `GATHERED_CONTEXT.full_description`. Also check `GATHERED_CONTEXT.visual_assets` — if the user provided designs or Figma links, factor them into the assessment:

- **Always run this step** if the description contains visual or UX redesign intent (keywords: "redesign", "rediseño", "new look", "new design", "visual overhaul", "UI revamp", "rework the UI/UX", "visual refresh", "new interface", "change the look", "new layout") — regardless of description length. Redesigns need visual scenario exploration even when described in detail.
- **Skip this step** if the description is detailed and clear (clear actor, action, and expected outcome, typically 15+ words) and no redesign intent is detected.
- **Run this step** if the description is vague, very short (< 15 words), or lacks a clear user action or expected outcome.

If running: invoke `/product-flow:praxis.collaborative-design` passing `GATHERED_CONTEXT.full_description` as input, and attach any visual assets from `GATHERED_CONTEXT.visual_assets` as additional context.

`praxis.collaborative-design` will guide through visual scenario exploration and write its findings to `specs/$BRANCH_NAME/collaborative-design.md`.

**Wait for `praxis.collaborative-design` to finish before continuing.**
If it produces an ERROR: propagate and stop.

Use `collaborative-design.md` as additional context in the next step.

### 5. Write spec (delegate to speckit.specify)

Invoke `/product-flow:speckit.specify` passing `GATHERED_CONTEXT.full_description` as the feature description. Also inject `GATHERED_CONTEXT` (visual assets, external docs, product clarifications) as additional context so the spec is written with the full picture gathered in step 2.

**Important — skip redundant clarification steps in `speckit.specify`:** since step 2 already asked the user for context, visual assets, external docs, and all product ambiguities, instruct `speckit.specify` to:
- Skip its step 3.6b (business terminology clarification) for any term already defined in `GATHERED_CONTEXT.product_clarifications`.
- Skip its step 3.7 (fill gaps and confirm understanding) entirely — the understanding was already validated in step 2.
- Use `GATHERED_CONTEXT.visual_assets` and `GATHERED_CONTEXT.external_docs` as primary references alongside `collaborative-design.md`.

**Note**: The branch `$BRANCH_NAME` has already been created and pushed. When `speckit.specify` runs, it will detect the existing feature branch and skip branch creation, proceeding directly to writing the spec.

**Question classification** — when `speckit.specify` identifies `[NEEDS CLARIFICATION]` markers, classify each one before presenting it:

- **Product** (ask the PM): business intent, priorities, functional scope, user flows, terminology. **NEVER resolve autonomously. Always surface to the PM via AskUserQuestion.**
- **Technical** (resolve autonomously): authentication, authorisation, security, compliance, data retention, integration patterns, infrastructure constraints, performance targets, architecture, data model, implementation patterns.

**For technical questions**, do NOT ask the PM. Instead:
1. Answer them using project context: existing code, `.agents/rules/base.md`, detected project stack, industry standards.
2. If there is sufficient information: make the decision and record it internally as **AI-proposed decision**.
3. If there is not sufficient information: record it internally as **Unresolved question** and continue.

Merge any new technical decisions with those already captured in `GATHERED_CONTEXT.technical_decisions`. Save the combined list internally for step 7.

`speckit.specify` will:
- Detect the existing branch and skip branch creation
- Write `$SPEC_PATH`
- Generate the quality checklist
- Ask clarification questions if there are any

**Wait for `speckit.specify` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

### 6. Update PR — mark spec created

Update the PR body to reflect spec completion:

Read the current PR body to extract the existing checklist block (between `<!-- dev-checklist -->` and `<!-- /dev-checklist -->`), then replace the Spec line with the actual spec details.

Count the number of user stories in `$SPEC_PATH` (lines matching `## User Story` or similar) to populate `<N> user stories`.

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

## For Developers
*PMs and designers can ignore this section.*

### Checklist

<!-- dev-checklist -->
- [x] **Spec** — <N> user stories (<US labels>) · $SPEC_PATH
- [ ] **Plan** — pending
- [ ] **Tasks** — pending
- [ ] **Implementation** — pending
<!-- /dev-checklist -->
EOF
)"
```

### 6b. Update status.json

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"spec_created": $ts}' > "$STATUS_FILE"
git add "specs/$BRANCH/"
git commit -m "chore: record spec_created and persist gathered context"
git push origin HEAD
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:start again.
```
**STOP.**

### 7. Record decisions and clarifications in the PR

#### 7a. Product clarifications (from step 2d)

For each question → answer pair in `GATHERED_CONTEXT.product_clarifications`, invoke `/product-flow:pr-comments write`:

- `type`: `product`, `status`: `ANSWERED`
- `body`:
  ```
  **Product question asked:** "[the question asked to the user]"

  **User answer:** "[the answer provided by the user]"
  ```

Skip if `GATHERED_CONTEXT.product_clarifications` is empty.

#### 7b. Technical decisions (from step 2d and step 5)

For each technical decision in the combined list, invoke `/product-flow:pr-comments write`:

- If resolved:
  - `type`: `technical`, `status`: `ANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
    ```
- If unresolved:
  - `type`: `technical`, `status`: `UNANSWERED`
  - `body`:
    ```
    **Technical question detected:** "[identified question]"

    **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

    ⚠️ **Unresolved — requires input from the development team.**
    ```

Skip if no technical decisions were made.

### 8. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after specify phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

### 9. Final report

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
