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
- If the current branch matches `^[0-9]{3}-`: **RESUMPTION MODE** — the user is returning to an interrupted session. Set `BRANCH_NAME` from the current branch name, derive `SPEC_PATH = specs/$BRANCH_NAME/spec.md`, and skip to step 3 (Information gathering). The skill will read `gathered-context.md` to determine which steps have already been completed.
- If the current branch is not `main` or `master` (and not a feature branch):
  Run:
  ```bash
  git checkout main
  git pull
  ```
  Then show: `ℹ️  Switched to main to start the new feature.` and continue normally.

---

### 2. Generate branch identity and open Draft PR

**Goal: NOT to write the spec. NOT to gather all context yet. Goal: establish the branch and PR so everything that follows is tracked from the start.**

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

#### 2c. Create the branch and initialize spec directory

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
git checkout -b "$BRANCH_NAME" || {
  echo "ERROR: Failed to create branch $BRANCH_NAME"; exit 1
}
FEATURE_DIR="$REPO_ROOT/specs/$BRANCH_NAME"
mkdir -p "$FEATURE_DIR/images"
mkdir -p "$FEATURE_DIR/docs"
SPEC_FILE="$FEATURE_DIR/spec.md"
```

Derive the human-readable PR title from `BRANCH_NAME`:
```
BRANCH_NUMBER=${BRANCH_NAME%%-*}
BRANCH_SLUG=${BRANCH_NAME#*-}
BRANCH_SLUG_SPACES=${BRANCH_SLUG//-/ }
PR_TITLE="$BRANCH_NUMBER: <capitalize first letter of BRANCH_SLUG_SPACES>"
```
Example: `001-user-auth` → `001: User auth`. Capitalize only the first letter of the slug; leave all other words as-is.

#### 2d. Initialize gathered-context.md

Create `specs/$BRANCH_NAME/gathered-context.md` immediately so facilitation answers can be persisted incrementally:

```markdown
# Gathered Context

> Collected during /product-flow:start before spec writing. Use this as authoritative input — do not re-ask any question already answered here.

## Product Framing

**Outcome:** _pending_
**Actor + Main Scenario:** _pending_
**Out of Scope:** _pending_
**Known Constraints:** _pending_

## Full Description

_pending_

## Visual Assets

### Uploaded Images
None provided.

### External Links
None provided.

### Descriptions
None provided.

## External Documentation

### Uploaded Documents
None provided.

### External Links
None provided.

### Pasted Content
None provided.

## Product Clarifications

None.

## Technical Decisions (pre-spec)

None.
```

#### 2e. Push the branch

```bash
git push -u origin HEAD
```

#### 2f. Open Draft PR

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

## How to test

### For PM
*To be populated when the implementation is submitted for review.*

### For Devs
*To be populated when the implementation is submitted for review.*

## History

| Status | Date Time | GitHub User | Note |
|--------|-----------|-------------|------|
| PR created | $(date -u +%Y-%m-%d\ %H:%M:%S) | @$(gh api user --jq '.login') | Feature started |

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

#### 2g. Record feature started

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"FEATURE_STARTED": $ts}' > "$STATUS_FILE"
```

Commit and push the initial files:

```bash
git add "specs/$BRANCH_NAME/"
git commit -m "chore: initialize feature branch and gathered context"
git push origin HEAD
```

Show:
```
🌱 Feature started. Let's shape the spec before writing it...
```

---

### 3. Information gathering

**Goal: NOT to write the spec. Goal: make the thinking solid before generating anything.**

If in RESUMPTION MODE: read `specs/$BRANCH_NAME/gathered-context.md` to determine which steps have already been completed. Skip any sub-step whose data is already present (not `_pending_`).

#### 3a. Structured facilitation — Product Framing

Probe the 4 key dimensions below. For each one:

1. Check `gathered-context.md` — if the field is not `_pending_`, skip it (already answered in a previous session).
2. If the dimension is clearly answered in `$ARGUMENTS`: infer the answer, update the file, write a PR comment. Do not ask.
3. Otherwise: ask via `AskUserQuestion`, wait for the answer, update the file, write a PR comment.
4. If a **technical question** arises while exploring any dimension (e.g., "does this imply a new auth mechanism?"): resolve it autonomously using project context (codebase, `.agents/rules/base.md`, stack, standards). Write a PR comment with `type: technical`. Do not ask the PM.

**After each answer**, immediately update `specs/$BRANCH_NAME/gathered-context.md` — replace the `_pending_` value for that dimension with the answer. This persists progress incrementally so the session can be resumed if interrupted.

---

**Dimension 1 — Outcome**

> "What changes for the user when this is done? How will we know it actually worked — is there a specific metric, behavior change, or observable outcome we can point to?"

After receiving the answer, evaluate concreteness: an outcome describes a **result** (behavioral change, measurable indicator, decision unlocked), not a feature ("users can export data" is a feature, not an outcome). If the answer only describes what the feature does:

> Push back once: "That describes what the feature does, not what changes. Imagine it's been live for 3 months — how do you know if it worked? What's different for the user or the business?"

Accept whatever comes back from the push-back. Do not push more than once.

- Answer goes to: `**Outcome:**` in `## Product Framing`
- PR comment: `type: product, status: ANSWERED`
  ```
  **Facilitation — Outcome**
  
  **Question:** What changes for the user when this is done? How will we know it worked?
  **Answer:** [final answer after push-back if applicable]
  ```
- If inferred (not asked): same PR comment format, note it was inferred from the description.

---

**Dimension 2 — Actor + Main Scenario**

> "Who uses this and in what concrete situation? Walk me through the main flow from start to finish — what does the user do, and what happens?"

After receiving the answer, evaluate concreteness: look for a specific user type, a concrete triggering situation, and a step-by-step flow. If the answer is "all users" or describes the feature without a real scenario:

> Push back once: "Walk me through the most important case step by step — who exactly, doing what, in what situation, and what do they get at the end?"

Accept whatever comes back. Do not push more than once.

- Answer goes to: `**Actor + Main Scenario:**` in `## Product Framing`
- PR comment: `type: product, status: ANSWERED`
  ```
  **Facilitation — Actor + Main Scenario**
  
  **Question:** Who uses this and in what concrete situation?
  **Answer:** [final answer after push-back if applicable]
  ```

---

**Dimension 3 — Out of Scope**

> "What is explicitly out of scope for this feature? What are we intentionally NOT building right now?"

After receiving the answer, evaluate concreteness: "nothing" or "the usual" are not valid exclusions. If the answer is empty or vague:

> Push back once: "What might the dev team assume is included that isn't? Any related functionality that's tempting to add but shouldn't be part of this?"

Accept whatever comes back. Do not push more than once.

- Answer goes to: `**Out of Scope:**` in `## Product Framing`
- PR comment: `type: product, status: ANSWERED`
  ```
  **Facilitation — Out of Scope**
  
  **Question:** What is explicitly out of scope for this feature?
  **Answer:** [final answer after push-back if applicable]
  ```

---

**Dimension 4 — Known Constraints**

> "Are there any known constraints we must respect — business rules, technical limitations, deadlines, compliance requirements, or dependencies on other teams or systems?"

After receiving the answer, evaluate concreteness: "the usual ones" or "standard constraints" are not actionable. If the answer is generic:

> Push back once: "What are the usual ones in this context? Any deadlines, team dependencies, or technical limitations we need to respect from the start?"

Accept whatever comes back. Do not push more than once. If the user genuinely has no constraints, "None identified." is a valid answer.

- Answer goes to: `**Known Constraints:**` in `## Product Framing`
- PR comment: `type: product, status: ANSWERED`
  ```
  **Facilitation — Known Constraints**
  
  **Question:** Are there any known constraints we must respect?
  **Answer:** [final answer after push-back if applicable]
  ```

---

**Facilitation rules (apply throughout 3a):**

- Ask dimensions one at a time. Do not batch all 4 in a single question.
- After each answer, evaluate concreteness before accepting. If vague: push back once with a specific, sharp question targeted at what is missing — not a generic "can you be more specific?".
- **One push-back maximum per dimension.** Accept whatever comes back after the push-back, even if still imprecise. Flag it internally and continue.
- Do not jump to the next dimension until the current one has been answered (and pushed back if needed).
- If a technical implication surfaces (auth, data model, integration, security): resolve it autonomously and write a `type: technical` PR comment. Never ask the PM about technical decisions.

#### 3b. Ask about visual assets

Use `AskUserQuestion` to ask:

> "Do you have any designs, wireframes, screenshots, Figma links, or similar visual references for this feature? If so, please share them now (links, images, or descriptions)."

If the user shares assets, record them as `VISUAL_ASSETS` object with:
- `files`: list of uploaded image files (PNG, SVG, JPG, GIF, etc.) with descriptive, URL-safe names — these will be saved to `specs/$BRANCH_NAME/images/`
- `links`: list of external URLs (Figma, Storybook, design systems, etc.)
- `descriptions`: list of text descriptions provided by the user

If not, record `VISUAL_ASSETS = none`.

#### 3c. Ask about external documentation

Use `AskUserQuestion` to ask:

> "Is there any external documentation I should use as reference? This could include PDFs, slide decks, API docs, existing code outside this repo, requirement documents, or anything else I can't directly access. If so, paste or link them now."

If the user shares materials, record them as `EXTERNAL_DOCS` object with:
- `files`: list of uploaded document files (PDF, slides, etc.) with descriptive, URL-safe names — these will be saved to `specs/$BRANCH_NAME/docs/`
- `links`: list of external URLs (API docs, Confluence, Google Docs, etc.)
- `pasted`: list of text/code pasted directly — each will be saved as `docs/pasted-doc-{N}.txt`

If not, record `EXTERNAL_DOCS = none`.

#### 3d. Identify and resolve remaining ambiguities

Carefully read `$ARGUMENTS`, the completed `## Product Framing`, `VISUAL_ASSETS`, and `EXTERNAL_DOCS`. Internally produce two lists:

**Product ambiguities list**: anything that is vague, underspecified, contradictory, or missing that a PM or product owner must answer — beyond what was already covered in step 3a. Examples: unclear user roles, undefined acceptance criteria, missing edge cases, ambiguous scope ("all users" — which users?).

**Technical ambiguities list**: architecture, authentication, data model, performance constraints, integration patterns, security, compliance. These must be resolved autonomously (see below).

For each item in the **product ambiguities list**, ask the user one question at a time using `AskUserQuestion`. Do **not** batch questions. Do **not** assume or infer the answer — wait for explicit confirmation before moving on. Present the question clearly, and if relevant, offer concrete options to make it easier to answer.

> ⚠️ **Rule**: Do NOT assume anything in this phase. Every product ambiguity must be asked and answered before continuing.

For each item in the **technical ambiguities list**, resolve it autonomously using existing project context (codebase, `.agents/rules/base.md`, detected stack, industry standards). Record each decision internally as a **technical-decision** with:
- The question identified
- The options considered
- The chosen option and brief reasoning

These will be published as PR comments in step 8b.

#### 3e. Notify if no product ambiguities

If the **product ambiguities list** from step 3d was empty (zero questions asked), output this message to the user:

> "I have no doubts about the product requirements. I'll proceed directly to writing the spec."

#### 3f. Consolidate gathered context

Produce a single internal object `GATHERED_CONTEXT` containing:
- `full_description`: `$ARGUMENTS` plus any significant enrichment from the facilitation conversation
- `product_framing`: the 4 completed dimensions from step 3a
- `visual_assets`: object with `files` (list with paths), `links` (list), `descriptions` (list), or "none"
- `external_docs`: object with `files` (list with paths), `links` (list), `pasted` (list), or "none"
- `product_clarifications`: list of question → answer pairs from step 3d
- `technical_decisions`: list of resolved technical decisions from step 3d

Persist assets to disk:

- **Uploaded image files** (`VISUAL_ASSETS.files`): write each file to `specs/$BRANCH_NAME/images/<descriptive-name>.<ext>` using the Write tool
- **Uploaded document files** (`EXTERNAL_DOCS.files`): write each file to `specs/$BRANCH_NAME/docs/<descriptive-name>.<ext>` using the Write tool
- **Pasted content** (`EXTERNAL_DOCS.pasted`): write each entry to `specs/$BRANCH_NAME/docs/pasted-doc-{N}.txt`
- **External image links** (`VISUAL_ASSETS.links`): create `specs/$BRANCH_NAME/images/sources.md` listing all links
- **External doc links** (`EXTERNAL_DOCS.links`): create `specs/$BRANCH_NAME/docs/sources.md` listing all links

Only create `images/sources.md` and `docs/sources.md` if there are actual links to record. Skip if the respective list is empty.

Write the final `specs/$BRANCH_NAME/gathered-context.md` with all sections complete:

```markdown
# Gathered Context

> Collected during /product-flow:start before spec writing. Use this as authoritative input — do not re-ask any question already answered here.

## Product Framing

**Outcome:** <outcome answer>
**Actor + Main Scenario:** <actor + scenario answer>
**Out of Scope:** <out of scope answer>
**Known Constraints:** <constraints answer>

## Full Description

<full_description>

## Visual Assets

### Uploaded Images
- [image1.png](images/image1.png)

<or "None provided." if no files>

### External Links
- [Figma Design](https://figma.com/...)

<or "None provided." if no links>

### Descriptions
- Description of asset 1

<or "None provided." if no descriptions>

## External Documentation

### Uploaded Documents
- [requirements.pdf](docs/requirements.pdf)

<or "None provided." if no files>

### External Links
- [API Documentation](https://api.example.com/docs)

<or "None provided." if no links>

### Pasted Content
- [pasted-requirements.txt](docs/pasted-requirements.txt)

<or "None provided." if no pasted content>

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

Commit the final gathered-context.md and any persisted assets:

```bash
git add "specs/$BRANCH_NAME/"
git commit -m "chore: persist gathered context and assets"
git push origin HEAD
```

---

### 4. Design exploration (conditional)

First, check if design exploration was already completed in a previous run:

```bash
ls "specs/$BRANCH_NAME/collaborative-design.md" 2>/dev/null
```

If the file exists, load it as `collaborative-design.md` and skip the rest of this step — use its contents as context in step 6.

Otherwise, assess the feature description using `GATHERED_CONTEXT.full_description`. Also check `GATHERED_CONTEXT.visual_assets` — if the user provided designs or Figma links, factor them into the assessment:

- **Always run this step** if the description contains visual or UX redesign intent (keywords: "redesign", "rediseño", "new look", "new design", "visual overhaul", "UI revamp", "rework the UI/UX", "visual refresh", "new interface", "change the look", "new layout") — regardless of description length. Redesigns need visual scenario exploration even when described in detail.
- **Skip this step** if the description is detailed and clear (clear actor, action, and expected outcome, typically 15+ words) and no redesign intent is detected.
- **Run this step** if the description is vague, very short (< 15 words), or lacks a clear user action or expected outcome.

If running: invoke `/product-flow:praxis.collaborative-design` passing `GATHERED_CONTEXT.full_description` as input, and attach any visual assets from `GATHERED_CONTEXT.visual_assets` as additional context.

`praxis.collaborative-design` will guide through visual scenario exploration and write its findings to `specs/$BRANCH_NAME/collaborative-design.md`.

**Wait for `praxis.collaborative-design` to finish before continuing.**
If it produces an ERROR: propagate and stop.

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"DESIGN_DONE": $ts}' > "$STATUS_FILE"
```

Show:
```
🎨 Design exploration complete. Running quality check before writing the spec...
```

Use `collaborative-design.md` as additional context in the next step.

---

### 5. Quality gate

Before invoking `speckit.specify`, verify internally that the gathered context is solid enough to produce a good spec. Check all of the following:

- [ ] **Outcome is concrete** — not just "users can do X". There is an observable result, a behavioral change, or a measurable indicator.
- [ ] **At least one end-to-end scenario is clear** — we know who does what, and what happens.
- [ ] **Scope has at least one explicit exclusion** — "Out of Scope" is not empty or "nothing".
- [ ] **No unanswered product ambiguity** — every question raised in step 3d has been answered.

If any check fails: go back to step 3a for the failing dimension. Ask a targeted follow-up using `AskUserQuestion`, update `gathered-context.md`, write the corresponding PR comment, and re-run the gate.

If all checks pass: continue.

---

### 5b. Epic scope check

Evaluate `GATHERED_CONTEXT` for signals that the description covers more than one independent deployable feature.

**Epic signals — score 1 point if ANY of these fire:**

- Two or more distinct actors with completely independent journeys (not just different permissions on the same journey)
- Two or more outcomes that are unrelated and could each provide standalone value
- The `full_description` uses conjunctions bundling distinct product lines: "and also", "as well as", "plus", "additionally" linking separate user-facing capabilities
- The Out of Scope answer defers a feature that is clearly part of the same product initiative ("we'll do X later") — suggesting X is a sibling feature, not a future iteration
- The Actor + Main Scenario dimension describes multiple scenarios with no dependency between them

**Score 0** — no epic signals. Continue silently to step 6.

**Score ≥ 1** — ask the PM via `AskUserQuestion`:

> "This looks like it may cover more than one independent feature: [name the identified sub-features in one sentence each]. Should we keep this as a single feature or split it into separate ones now?"

Options: `Keep as a single feature` (Recommended if uncertain) / `Split into separate features`

If the PM selects **Keep as a single feature**: continue to step 6 without changes.

If the PM selects **Split into separate features**: execute the split below, then continue to step 6 with the trimmed scope on the current branch.

---

#### 5b-i. Determine split boundaries

Based on the gathered context, identify:

- **Feature A** (current branch `BRANCH_NAME`): the primary sub-feature — the one most directly described in `$ARGUMENTS`. Define its trimmed scope: which outcome, which actor+scenario, which constraints apply.
- **Feature B, C…** (new branches): each remaining sub-feature. Define each one's scope in the same terms.

For each new feature, determine its short name (2–4 words, kebab-case, action-noun).

Ask the PM to confirm the split boundaries via `AskUserQuestion` if any boundary is ambiguous. Show the proposed split clearly:

```
Feature A — [BRANCH_NAME] (keep)
  Outcome: [trimmed outcome]
  Actor + Scenario: [trimmed scenario]

Feature B — [proposed-slug] (new)
  Outcome: [extracted outcome]
  Actor + Scenario: [extracted scenario]

[repeat for C, D…]
```

Accept confirmation before executing.

---

#### 5b-ii. Create new branches and Draft PRs

For each new sub-feature (Feature B, C…):

**Find next branch number:**

```bash
git fetch --all --prune
git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-'
git branch | grep -E '^[* ]*[0-9]+-'
ls specs/ 2>/dev/null | grep -E '^[0-9]+-'
```

Compute next number: highest N + 1, zero-padded to 3 digits. Set `NEW_BRANCH = NNN-<short-name>`.

**Create branch from main:**

```bash
git checkout main
git pull
git checkout -b "$NEW_BRANCH"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
NEW_FEATURE_DIR="$REPO_ROOT/specs/$NEW_BRANCH"
mkdir -p "$NEW_FEATURE_DIR/images"
mkdir -p "$NEW_FEATURE_DIR/docs"
```

**Write `gathered-context.md` for the new branch** — populate it with:
- The sub-feature's trimmed scope (outcome, actor+scenario, out of scope, constraints)
- All shared context that applies to both features: visual assets, external documentation, shared technical decisions
- A `## Related Features` section:
  ```markdown
  ## Related Features
  - **[BRANCH_NAME]**: [one-line description of the sibling feature]
  ```

**Write `status.json`:**

```bash
echo "{}" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"FEATURE_STARTED": $ts}' > "$NEW_FEATURE_DIR/status.json"
```

**Commit and push:**

```bash
git add "specs/$NEW_BRANCH/"
git commit -m "chore: initialize feature branch and gathered context"
git push -u origin HEAD
```

**Open Draft PR:**

```bash
NEW_SLUG_WORDS="${NEW_BRANCH#*-}"
NEW_PR_TITLE="${NEW_BRANCH%%\-*}: ${NEW_SLUG_WORDS^}"

gh pr create \
  --title "$NEW_PR_TITLE" \
  --draft \
  --base main \
  --body "$(cat <<EOF
## Feature
Spec: specs/$NEW_BRANCH/spec.md

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
| PR created | $(date -u +%Y-%m-%d\ %H:%M:%S) | @$(gh api user --jq '.login') | Extracted from $BRANCH_NAME during epic split |

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

Save the returned URL as `NEW_PR_URL`.

Repeat for each additional new branch. Compute a fresh branch number for each one after the previous branch has been created.

---

#### 5b-iii. Return to current branch and trim its gathered context

```bash
git checkout $BRANCH_NAME
```

Edit `specs/$BRANCH_NAME/gathered-context.md`:
- Replace the Outcome, Actor + Main Scenario, Out of Scope, and Full Description with Feature A's trimmed scope
- Keep all shared context (visual assets, external docs, shared technical decisions)
- Append a `## Related Features` section:
  ```markdown
  ## Related Features
  - **[NEW_BRANCH]**: [one-line description of what was extracted]
  [repeat for each new branch]
  ```

Commit:

```bash
git add "specs/$BRANCH_NAME/gathered-context.md"
git commit -m "chore: trim gathered context to feature A scope after epic split"
git push origin HEAD
```

Also update the current PR body History table — add a row:

```
| Epic split | YYYY-MM-DD HH:MM:SS | @github-user | Split into [BRANCH_NAME] + [NEW_BRANCH(ES)] |
```

---

#### 5b-iv. Report to PM

```
✂️  Epic split complete

[BRANCH_NAME] — current branch, gathered context trimmed to: [one-line scope]
[NEW_BRANCH]  — new branch created · PR: [NEW_PR_URL]
[repeat for each new branch]

Continuing with [BRANCH_NAME]. Run /product-flow:start on each new branch when ready.
```

Then update `GATHERED_CONTEXT` in memory to reflect the trimmed scope before continuing to step 6.

---

### 6. Write spec (delegate to speckit.specify)

Show:
```
📋 Writing feature spec...
```

Invoke `/product-flow:speckit.specify` passing `GATHERED_CONTEXT.full_description` as the feature description. Also inject `GATHERED_CONTEXT` (product framing, visual assets, external docs, product clarifications) as additional context so the spec is written with the full picture gathered in step 3.

**Asset availability**: All downstream skills can access persisted assets:
- **Images**: `specs/$BRANCH_NAME/images/` — read and reference these in specs and implementations
- **Documents**: `specs/$BRANCH_NAME/docs/` — PDFs, API docs, requirements, etc.
- **External links**: `specs/$BRANCH_NAME/images/sources.md` and `specs/$BRANCH_NAME/docs/sources.md`
- **Full context**: `specs/$BRANCH_NAME/gathered-context.md` — complete reference for all gathered information

**Important — skip redundant clarification steps in `speckit.specify`:** since step 3 already asked the user for context, visual assets, external docs, and all product ambiguities, instruct `speckit.specify` to:
- Skip its step 3.6b (business terminology clarification) for any term already defined in `GATHERED_CONTEXT.product_clarifications`.
- Skip its step 3.7 (fill gaps and confirm understanding) entirely — the understanding was already validated in step 3.
- Use `GATHERED_CONTEXT.visual_assets` and `GATHERED_CONTEXT.external_docs` as primary references alongside `collaborative-design.md`.
- Read `specs/$BRANCH_NAME/gathered-context.md` as the authoritative source for all context.

**Question classification** — when `speckit.specify` identifies `[NEEDS CLARIFICATION]` markers, classify each one before presenting it:

- **Product** (ask the PM): business intent, priorities, functional scope, user flows, terminology. **NEVER resolve autonomously. Always surface to the PM via AskUserQuestion.**
- **Technical** (resolve autonomously): authentication, authorisation, security, compliance, data retention, integration patterns, infrastructure constraints, performance targets, architecture, data model, implementation patterns.

**For technical questions**, do NOT ask the PM. Instead:
1. Answer them using project context: existing code, `.agents/rules/base.md`, detected project stack, industry standards.
2. If there is sufficient information: make the decision and record it internally as **AI-proposed decision**.
3. If there is not sufficient information: record it internally as **Unresolved question** and continue.

Merge any new technical decisions with those already captured in `GATHERED_CONTEXT.technical_decisions`. Save the combined list internally for step 8.

`speckit.specify` will:
- Detect the existing branch and skip branch creation
- Write `$SPEC_PATH`
- Generate the quality checklist
- Ask clarification questions if there are any

**Wait for `speckit.specify` to finish completely before continuing.**
If it produces an ERROR: propagate and stop.

---

### 7. Update PR — mark spec created

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

| Status | Date Time | GitHub User | Note |
|--------|-----------|-------------|------|
| PR created | $(date -u +%Y-%m-%d\ %H:%M:%S) | @$(gh api user --jq '.login') | Feature started |
| Spec created | $(date -u +%Y-%m-%d\ %H:%M:%S) | @$(gh api user --jq '.login') | Spec written |

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

### 7b. Update status.json

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"SPEC_CREATED": $ts}' > "$STATUS_FILE"
git add "specs/$BRANCH/"
git commit -m "chore: record spec_created and persist gathered context"
git push origin HEAD
```

Show:
```
📄 Spec created. Share the PR with the team for review. Run /product-flow:continue when ready.
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:start again.
```
**STOP.**

---

### 8. Record decisions in the PR

#### 8a. Product clarifications (from step 3d)

For each question → answer pair in `GATHERED_CONTEXT.product_clarifications`, invoke `/product-flow:pr-comments write`:

- `type`: `product`, `status`: `ANSWERED`
- `body`:
  ```
  **Product question asked:** "[the question asked to the user]"

  **User answer:** "[the answer provided by the user]"
  ```

Skip if `GATHERED_CONTEXT.product_clarifications` is empty.

> Note: PR comments for the Product Framing dimensions (step 3a) were already written inline during facilitation. This step only covers additional clarifications from step 3d.

#### 8b. Technical decisions (from step 3d and step 6)

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

---

### 9. Phase retro

Invoke `/product-flow:speckit.retro` with context: "after specify phase".

**Wait for `speckit.retro` to finish before continuing.**
If it returns a **Blocked** status: do not show the final report until the user resolves the blockers.

---

### 10. Final report

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

---

## Asset & Context Reference for Downstream Skills

All downstream skills can access persisted assets and context created in this phase:

**📚 Read the Skill Data Access Guide**: `docs/skill-data-access.md` in the plugin docs — it explains:
- How to access gathered context (`gathered-context.md`)
- Where to find images and PDFs (`images/` and `docs/` folders)
- How to reference external links (`sources.md`)
- Code examples for accessing assets in bash/scripts

**Quick reference:**
```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/gathered-context.md"        # Read all gathered context
ls "specs/$BRANCH/images/"                     # List visual assets
cat "specs/$BRANCH/images/sources.md"          # View external visual links
cat "specs/$BRANCH/docs/sources.md"            # View external doc links
```

**For skill developers**: Every skill should verify assets are available before depending on them. See the Skill Data Access Guide for patterns and examples.

---

### Session close

Invoke `/product-flow:context`.
