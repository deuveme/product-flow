---
description: "Writes a lean spec for a start-improvement branch. Max 1 page: what changes for the user + acceptance criteria. Includes integrated self-validation."
user-invocable: false
model: sonnet
context: fork
effort: low
---

## Scope Discipline

- **Write only what was asked.** Every requirement must trace directly to something in `improvement-context.md`.
- **No gold-plating.** Do not add flows or scenarios not requested. Flag anything uncertain as a question — never add it silently.
- **Keep it short.** This spec must fit in ~1 page. If it's growing larger, something is wrong with scope.

## Execution

### 1. Setup

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
BRANCH=$(git branch --show-current)
FEATURE_DIR="$REPO_ROOT/specs/$BRANCH"
SPEC_FILE="$FEATURE_DIR/spec.md"
```

If `FEATURE_DIR` does not exist: ERROR "Feature directory not found. Run /product-flow:start-improvement first."

Read the improvement context:

```bash
cat "$FEATURE_DIR/improvement-context.md"
ls "$FEATURE_DIR/images/" 2>/dev/null
cat "$FEATURE_DIR/images/index.md" 2>/dev/null
cat "$FEATURE_DIR/images/sources.md" 2>/dev/null
```

This is the authoritative input. Do not re-ask anything already answered there.

Any image files in `$FEATURE_DIR/images/` are available to read and reference directly in the spec. `images/index.md` — if present — maps each file and link to the screen/component it shows and its role (`current-state`, `target`, `reference`, etc.). Use the index to understand what each image represents before reading it. Do not invent UI details that contradict or are absent from these references.

### 1b. Detect visual improvement intent

Scan `improvement-context.md` fields ("What to improve", "What should change for the user") for visual signals. Keywords: "empty state", "estado vacío", "button", "icon", "card", "layout", "spacing", "color", "typography", "CTA", "call to action", "reposition", "move", "resize", "style", "design", "look", "appearance", "dark mode", "theme", "banner", "modal", "tooltip", "badge".

Also set `VISUAL_MODE = true` if `images/index.md` exists and contains at least one entry with role `target` or `current-state`.

If visual keywords are detected but NO images are present (no files in `images/` and no `images/index.md`), ask the user via `AskUserQuestion` before continuing:

> "This looks like a visual change, but I don't have any reference images. Do you have a screenshot of the current state or a design for the target? Adding one now will make the spec much more accurate."

Options: `Share an image now` / `Continue without images`

If the user shares an image, save it to `specs/$BRANCH/images/` and ask what it shows (same follow-up as Dimension 4 in start-improvement) to generate `images/index.md`. Then re-evaluate `VISUAL_MODE` triggers before continuing.

If the user continues without images: proceed, but note internally that visual acceptance criteria will be based on the text description only — flag any criterion that makes a specific visual claim as `[NEEDS VISUAL CONFIRMATION]`.

If any signal is found, set `VISUAL_MODE = true` and apply these additional rules when writing the spec:
- **"What changes for the user"** must describe the visual delta explicitly: what the user sees now vs what they will see after. If a `current-state` image exists, ground the "before" description in it. If a `target` image exists, ground the "after" description in it.
- **Acceptance criteria** must be directly grounded in the target visual reference — each criterion must be verifiable by looking at the UI. Do not invent visual details not present in the improvement context or reference images.
- Do NOT write criteria that merely restate how the current UI behaves. Every criterion must describe a specific observable change.

### 2. Write spec.md

Write `$SPEC_FILE` with this structure — keep each section brief:

```markdown
# [Short title derived from the improvement description]

## What changes for the user

[1–3 sentences describing the observable change from the user's perspective. What did they see/experience before? What will they see/experience after?]

## Acceptance criteria

- [criterion 1 — specific, testable, user-facing]
- [criterion 2]
- [criterion 3]
[3–6 criteria total. Each must be directly derivable from the improvement description. Do not add criteria for behaviors not mentioned.]

## Out of scope

- [explicit exclusion 1]
- [explicit exclusion 2]
[Anything that was explicitly excluded in improvement-context.md, or anything a developer might assume is included but isn't.]

## Constraints

[Any business rules, technical limits, or dependencies mentioned in improvement-context.md. Omit this section if none.]
```

**Rules:**
- No user stories, no functional requirements tables, no data model references.
- No performance metrics unless explicitly stated in the improvement context.
- No implementation details (no framework names, no API endpoints).
- The "What changes for the user" section must describe the DELTA (before → after), not just the after state.

### 3. Integrated self-validation

After writing `spec.md`, perform a self-check before finalizing. For each item below, verify it passes:

- [ ] Every acceptance criterion is directly traceable to something in `improvement-context.md`
- [ ] No criterion introduces new behavior not mentioned by the user
- [ ] "What changes for the user" is concrete (not vague like "improved experience")
- [ ] "Out of scope" has at least one explicit exclusion
- [ ] The spec fits in ~1 page (less than ~40 lines)
- [ ] (If images exist in `$FEATURE_DIR/images/` or links in `images/sources.md`) Acceptance criteria are consistent with the visual references — no criterion contradicts or ignores what the references show

**If any item fails:** fix the spec inline before continuing.

**Product ambiguities:** If after writing the spec there are genuine product questions (things that would change the acceptance criteria if answered differently), collect them all and ask in a **single AskUserQuestion call**:

- `question`: the specific question, ending with "?"
- `header`: short topic label (max 12 chars)
- `options`: 2–3 plausible answers, recommended option first with `" (Recommended)"`
- `multiSelect`: false

After receiving answers, update `spec.md` and record each answer as a PR comment via `/product-flow:pr-comments write`:
- `type`: `product`, `status`: `ANSWERED`
- `body`: the question and the user's answer

**Technical ambiguities:** resolve autonomously using project context. Record decisions as PR comments with `type: technical`, `status: ANSWERED`.

If there are no ambiguities: output this message and proceed.
> "Spec looks complete. No clarifications needed."

### 4. Persist and update PR

```bash
git add "$SPEC_FILE"
git commit -m "docs: write improvement spec"
git push origin HEAD
```

If the commit fails with a GPG error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:start-improvement again.
```
**STOP.**

Write `SPEC_CREATED` to `specs/$BRANCH/status.json`:

```bash
STATUS_FILE="$FEATURE_DIR/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {"SPEC_CREATED": $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record spec_created"
git push origin HEAD
```

Update the PR body — mark spec created:
- Mark `- [x] Spec created` in `## Status`
- Replace `- [ ] **Spec** — pending` with `- [x] **Spec** — complete · $SPEC_FILE` inside `<!-- dev-checklist -->`
- Add row to `## History`: `| Spec created | YYYY-MM-DD HH:MM:SS | @github-user | Improvement spec written |`

```bash
gh pr edit --body "<updated-body>"
```

### 5. Report

```
📄 Spec written: specs/<branch>/spec.md

Share the PR with the team for review.
Run /product-flow:continue when ready.
```
