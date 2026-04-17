---
description: "Analyzes a spec (pre-plan) or plan (post-plan) for scope creep using an iterative debate, then creates a new branch+PR for any extracted feature. Default posture is to split — the feature must justify staying together."
user-invocable: false
model: opus
context: fork
effort: high
handoffs:
  - label: Continue Current Feature
    agent: continue
    prompt: Continue with the reduced scope
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

### Step 1 — Setup and context loading

1. Run `git branch --show-current` to get BRANCH_NAME.
2. Derive FEATURE_DIR = `specs/$BRANCH_NAME`.
3. Read `$FEATURE_DIR/spec.md`. If it does not exist: stop with `ERROR: No spec found on branch '$BRANCH_NAME'. Run /product-flow:start-feature or /product-flow:start-improvement first.`
4. **Detect mode**:
   - If `$FEATURE_DIR/plan.md` does not exist → **MODE = pre-plan**
   - If `$FEATURE_DIR/plan.md` exists → **MODE = post-plan**
   - If post-plan: read `plan.md`, `research.md` (if present), `data-model.md` (if present)
5. **Load `split-analysis.md`** if it exists at `$FEATURE_DIR/split-analysis.md`. This contains prior analysis history and, for child features, the full inherited debate from the parent.
6. **Detect if this is a child feature**: read the "Feature Context" section of `split-analysis.md`. If "Original feature" is NOT "This is the original feature." → this is a child feature. Load `specs/[parent-branch]/split-analysis.md` as additional context.
7. If user provided input (e.g. "split out the payments part"), treat it as a strong override signal — skip scoring and proceed directly to proposing the split they described.

### Step 2 — Analysis and scoring

**Core philosophy**: the default posture is split. The scoring accumulates reasons to keep the feature together. A feature that cannot justify a high score should be split.

**Score scale: 0–10 reasons to NOT split**
- 0–2 → mandatory split
- 3–5 → recommended split
- 6–8 → optional split
- 9–10 → no split (must be explicitly justified)

#### Hard signals — trigger mandatory split regardless of score

Fire these before scoring. If any hard signal fires, skip scoring and go directly to Step 3 with "mandatory split":

- Two bounded contexts with zero dependencies between them
- Two completely distinct user journeys with no shared touchpoint
- (Post-plan only) No phase in the plan produces user-testable output

#### Pre-plan signals (scored against spec)

Each signal subtracts from the reasons-to-keep-together score. Evaluate individually — within a group, each fired signal contributes its own weight:

**Scope signals:**
- More than 4 independent user stories (-2)
- Two or more distinct user personas with completely different journeys (-2)
- Requirements that could ship independently and provide standalone value (-3)
- Spec spans multiple bounded contexts (-3)
- Overview implies more than one standalone product decision (-2)

**Size signals:**
- More than 8 distinct functional requirements (-2)
- More than 2 unrelated success criteria (-1)

**Language signals** (each instance found):
- Coordinating conjunctions bundling distinct actions: "and, or, but, yet" (-1 each)
- Catch-all verbs hiding multiple operations: "manage, handle, support, administer" (-1 each)
- Sequence words implying separate flows: "before, after, then, once X is done" (-1 each)
- Scope accretion words: "including, additionally, plus, as well as" (-1 each)
- Option indicators: "either/or, optionally, if the user wants" (-1 each)
- Exception carve-outs: "except when, unless, however in the case of" (-1 each)

**If post-plan mode**: before scoring pre-plan signals, read `split-analysis.md` and exclude any signals already debated and decided in the pre-plan analysis. Only score signals that the plan reveals as new.

#### Post-plan signals (scored against plan artifacts)

**Testability gap signals:**
- Phase 1 produces no user-visible output (pure infrastructure/scaffolding) (-3)
- First possible Given/When/Then for a real user action falls in Phase 2 or later (-2)
- A phase must complete in full before any other phase can begin testing (serial bottleneck, not user-facing) (-2)

**Independent workstream signals:**
- Two or more phases with no dependency between them, deployable independently (-3)
- Data model shows two distinct entity clusters with no shared foreign keys (-2)
- `research.md` describes two technically separate subsystems (-2)
- Two separate external integrations, each delivering standalone value without the other (-2)

**Complexity signals:**
- Plan has more than 4 phases (-1)
- Any single phase spans more than one bounded context (-2)
- Plan implies more than 15 discrete implementation tasks at leaf level (-1)
- Dedicated "cleanup" or "refinement" phase present (-1)

### Step 3 — Present analysis and open debate

Print a structured report. Reference actual user stories, requirements, phase names, and entities from the artifacts — no placeholders.

```
## Split Analysis: [Feature name from spec] — [Pre-plan | Post-plan]

**Score: N/10 reasons to keep together** — [Mandatory split | Recommended split | Optional split | No split]

### Hard signals fired
[List with reasoning referencing specific parts of the spec/plan. Or: "None."]

### Signals detected
| Signal | Weight | Why it matters here |
|--------|--------|---------------------|
| [specific signal referencing actual content] | -N | [reasoning in context] |

### Proposed split   ← only if score ≤ 8 or hard signal fired
**Feature A — [BRANCH_NAME] (keep)**
- Goal: [one sentence]
- What stays: [user stories / phases retained]
- Given/When/Then (day 1 test): Given [precondition] / When [action] / Then [outcome]
- Why this is a valid vertical slice: [one sentence]

**Feature B — [proposed-slug] (extract)**
- Goal: [one sentence]
- What moves: [user stories / phases extracted]
- Given/When/Then (day 1 test): Given [precondition] / When [action] / Then [outcome]
- Why independent: [one sentence]
- Why this boundary and not another: [reasoning]
- Alternatives considered and discarded: [list with reasons]

⚠️ Expand-contract needed: [shared entities, or omit if none]
```

Then open the debate. Do not ask a yes/no question — invite the user to engage:

```
This analysis is a starting point for discussion, not a final verdict.

You can:
- Accept the proposed split as-is
- Challenge a specific signal ("I don't think X is a separate concern because...")
- Propose a different boundary ("What if we split at Y instead?")
- Question the score ("Feature B still depends on Feature A because...")

What do you think?
```

Use **AskUserQuestion** with options as starting points:
- `Yes, split as proposed` (mark as Recommended if score ≤ 5 or hard signal)
- `Adjust the boundary`
- `Challenge a signal`
- `No, keep as-is` (mark as Recommended if score ≥ 9)

Record each exchange in `split-analysis.md` as it happens (Step 5 below) — update the file after each message so the debate is durable even if the session is interrupted.

If the user challenges a signal or proposes a different boundary: re-evaluate with their input, update the analysis, and present a revised proposal. Repeat until a decision is reached.

If the user selects **No / keep as-is**: confirm the spec stays intact, record the decision, and stop at Step 5.

### Step 4 — Vertical slice validation (before any commit)

Before executing the split, validate that each resulting feature forms a true vertical slice:

For each proposed feature:
- The Given/When/Then test can be executed without the other feature being built
- It deploys independently and provides value in production on its own
- It does not leave a half-built domain entity that only becomes useful when the other feature ships

If validation fails for any feature: return to Step 3, adjust the boundary, and re-debate. Never commit an invalid split.

### Step 5 — Record in `split-analysis.md`

Update (or create) `$FEATURE_DIR/split-analysis.md` after every exchange during the debate — not just at the end.

#### File structure

```markdown
# Split Analysis — [BRANCH_NAME]

## Feature Context
**This feature:** `specs/[BRANCH_NAME]/spec.md`
**Original feature:** This is the original feature. | `specs/[parent-branch]/spec.md`
**Features split from this:** None. |
- `specs/[child-branch]/spec.md` — [one-line reason extracted]

---

## [Pre-plan | Post-plan] analysis
**Date:** ISO timestamp
**Mode:** pre-plan | post-plan

### Score: N/10 → [Mandatory split | Recommended | Optional | No split]

### Hard signals fired
[list with reasoning, or "None"]

### Signals detected
| Signal | Weight | Why it matters here |

### Proposed split
**Feature A — [BRANCH_NAME] (keep)**
- Goal: ...
- What stays: ...
- Given/When/Then: ...
- Vertical slice: ...

**Feature B — [slug] (extract)**
- Goal: ...
- What moves: ...
- Given/When/Then: ...
- Why independent: ...
- Boundary reasoning: ...
- Alternatives discarded: ...

⚠️ Expand-contract: [entities, or omit]

### Debate
**[ISO timestamp] Skill:** [proposal or response with full reasoning]
**[ISO timestamp] User:** [response or argument]
[... each exchange appended as it happens ...]

### Decision
[Decision verbatim] — [reasoning]

---

## [Next analysis section if applicable]
```

**For child features**: the file starts with Feature Context, then embeds the full parent debate verbatim (copy of the parent's relevant analysis section), then has its own empty analysis sections for pre-plan and post-plan.

If this is the first time running on this branch: initialize the file with Feature Context, then the current analysis section. Set "Original feature" and "Features split from this" correctly.

If the file already exists: append the new analysis section. Do not modify previous sections.

### Step 6 — Execute split (only if user confirmed)

Run steps 6a through 6k in order. Do not skip any.

**Sequencing rule**: fully set up the child branch first (6a–6e), then return to the parent to trim it (6f–6k). Never switch branches with uncommitted changes.

#### 6a — Validate the cut (pre-commit check)

Re-read both the content to keep (Feature A) and the content to extract (Feature B). Verify:
- No requirement appears in both
- No user story is left without acceptance criteria in either feature
- Both features have a valid, independent Given/When/Then
- Any cross-feature dependencies are explicitly documented

If any check fails: correct the cut and re-validate. Do not proceed until all checks pass.

#### 6a.1 — PM confirmation of requirement allocation (mandatory before any file is modified)

Before touching any file, present the exact allocation of every user story and functional requirement to the PM for explicit confirmation. Use **AskUserQuestion**:

- `question`: "Before I execute the split, please confirm that every requirement is going to the right place.\n\n**Stays in [BRANCH_NAME]:**\n[bullet list of user stories and FRs staying]\n\n**Moves to [NEW_BRANCH_SLUG]:**\n[bullet list of user stories and FRs moving]\n\n**Ambiguous (needs your call):**\n[list any requirements that could reasonably belong to either side, or 'None']\n\nDoes this allocation look correct?"
- `header`: "Split review"
- `options`:
  - `"Yes, this is correct — proceed"`
  - `"No, I need to move something"`
- `multiSelect`: false

If the PM says **yes**: proceed to step 6b.

If the PM says **no**: ask which requirements need to move (follow-up `AskUserQuestion` with the full list as multi-select options), update the allocation, and repeat this step until the PM confirms. Do not proceed until explicit confirmation is given.

**This is a product gate, not a technical one.** The PM is the only authority on which requirements belong to which feature.

#### 6b — Determine new branch identity

- Derive SHORT_NAME: 2–4 words, kebab-case, action-noun format (e.g. `notifications-engine`, `audit-log`)
- Run `git fetch --all --prune`
- Find highest feature number across:
  - Remote branches: `git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-'`
  - Local branches: `git branch | grep -E '^[* ]*[0-9]+-'`
  - Specs directories: `ls specs/ 2>/dev/null | grep -E '^[0-9]+-'`
- BRANCH_NUMBER = highest N + 1, zero-padded: `printf "%03d" $((N+1))`. If nothing found: `001`.
- NEW_BRANCH = `BRANCH_NUMBER-SHORT_NAME`
- PR_TITLE:
  ```bash
  SLUG_WORDS="${SHORT_NAME//-/ }"
  PR_TITLE="$BRANCH_NUMBER: ${SLUG_WORDS^}"
  ```

#### 6c — Create child branch

```bash
git checkout main
git pull
git checkout -b "$NEW_BRANCH" || {
  echo "ERROR: Failed to create branch $NEW_BRANCH"; exit 1
}
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
NEW_FEATURE_DIR="$REPO_ROOT/specs/$NEW_BRANCH"
mkdir -p "$NEW_FEATURE_DIR"
```

#### 6d — Write spec-draft.md on child branch

Write `$NEW_FEATURE_DIR/spec-draft.md` with the extracted content (user stories, requirements, success criteria, assumptions). Use the same section headings as the parent spec. Do NOT write `spec.md` directly — `speckit.specify` will generate it.

Include in the draft:
- Overview focused on the extracted goal
- The extracted user stories and their acceptance criteria
- The extracted requirements
- Relevant success criteria
- A `## Related Features` section:
  ```markdown
  ## Related Features
  - **[BRANCH_NAME]**: [one-line description of the parent feature]
  ```
- If expand-contract was flagged:
  ```markdown
  ## Assumptions
  - Shared entities with [BRANCH_NAME] ([entity names]) require expand-contract coordination. See /product-flow:praxis.expand-contract.
  ```

#### 6e — Write split-analysis.md on child branch

Write `$NEW_FEATURE_DIR/split-analysis.md`:

```markdown
# Split Analysis — [NEW_BRANCH]

## Feature Context
**This feature:** `specs/[NEW_BRANCH]/spec.md`
**Original feature:** `specs/[BRANCH_NAME]/spec.md`
**Features split from this:** None.

---

## Inherited from parent: [BRANCH_NAME]

[Copy the full analysis section from the parent's split-analysis.md that produced this split — including signals, proposed split, full debate, and decision. Do not summarize.]

---

## Pre-plan analysis
[empty — will be filled when /product-flow:continue runs speckit.split on this branch]

## Post-plan analysis
[empty — will be filled when /product-flow:continue runs speckit.split post-plan on this branch]
```

#### 6f — Invoke speckit.specify on child branch

Invoke `/product-flow:speckit.specify`. It will detect `spec-draft.md` as input, generate a complete validated `spec.md`, run quality checks, and remove the draft.

Wait for `speckit.specify` to finish. If ERROR: propagate and stop.

#### 6g — Write status.json and commit child branch

```bash
STATUS_FILE="$NEW_FEATURE_DIR/status.json"
echo "{}" | jq \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg parent "$BRANCH_NAME" \
  '. + {"SPEC_CREATED": $ts, "parent": $parent}' > "$STATUS_FILE"
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

Then run /product-flow:continue again.
```
**STOP.**

#### 6h — Open draft PR for child branch

```bash
gh pr create \
  --title "$PR_TITLE" \
  --draft \
  --base main \
  --body "$(cat <<EOF
## Feature
Spec: specs/$NEW_BRANCH/spec.md

## Status
- [x] Spec created
- [ ] Plan generated
- [ ] Tasks generated
- [ ] Code generated
- [ ] In code review
- [ ] Published

## History

| Status | Date | Note |
|--------|------|------|
| PR created | $(date +%Y-%m-%d) | Extracted from $BRANCH_NAME |
| Spec created | $(date +%Y-%m-%d) | Spec written during split |

## Notes
EOF
)"
```

Save returned URL as NEW_PR_URL.

#### 6i — Return to parent branch and trim spec

```bash
git checkout $BRANCH_NAME
```

Edit `$FEATURE_DIR/spec.md`:
- Remove the extracted user stories and their acceptance criteria
- Remove requirements that belong exclusively to the extracted feature
- Remove success criteria that address only the extracted feature
- Preserve: Overview, all retained user stories, retained requirements, Assumptions
- Append or update `## Related Features`:
  ```markdown
  ## Related Features
  - **[NEW_BRANCH]**: [one-line description of what was extracted]
  ```
- If expand-contract was flagged, add to Assumptions:
  ```markdown
  - Shared entities with [NEW_BRANCH] ([entity names]) require expand-contract coordination. See /product-flow:praxis.expand-contract.
  ```

#### 6j — Write spec-draft.md on parent and invoke speckit.specify

Write `$FEATURE_DIR/spec-draft.md` with the trimmed spec content. Invoke `/product-flow:speckit.specify`. It will detect the draft, regenerate a complete validated `spec.md` for the reduced scope, and remove the draft.

Wait for `speckit.specify` to finish. If ERROR: propagate and stop.

#### 6k — Update parent split-analysis.md

Update the "Features split from this" line in the Feature Context section:

```markdown
**Features split from this:**
- `specs/[NEW_BRANCH]/spec.md` — [one-line reason extracted]
```

#### 6l — If post-plan mode: reset plan on parent

Clear flags and delete artifacts — the plan was generated for the full scope and is no longer valid:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE")
echo "$EXISTING" | jq 'del(.PLAN_GENERATED, .SPLIT_POSTPLAN_ANALIZED, .TASKS_GENERATED, .CHECKLIST_DONE, .CODE_WRITTEN)' > "$STATUS_FILE"
```

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
rm -f "$REPO_ROOT/specs/$BRANCH_NAME/plan.md"
rm -f "$REPO_ROOT/specs/$BRANCH_NAME/research.md"
rm -f "$REPO_ROOT/specs/$BRANCH_NAME/data-model.md"
rm -rf "$REPO_ROOT/specs/$BRANCH_NAME/contracts/"
```

Conserve: `SPEC_CREATED` + `SPLIT_PREPLAN_ANALIZED`. The user runs `/product-flow:continue` to regenerate the plan for the reduced scope.

#### 6m — Commit and push parent

```bash
git add specs/$BRANCH_NAME/
git commit -m "feat: trim spec to reduced scope after split ($NEW_BRANCH extracted)"
git push
```

If the commit fails with a GPG or signing error (output contains `gpg`, `signing`, or `secret key`):
```
🚫 Commit failed — GPG signing is blocking automatic commits.

To fix it, run in your terminal:
  git config commit.gpgsign false

Then run /product-flow:continue again.
```
**STOP.**

#### 6n — Update parent PR body

If no PR exists for the parent branch, skip silently.

```bash
ORIG_PR_NUMBER=$(gh pr view --json number -q '.number')
ORIG_PR_BODY=$(gh pr view --json body -q '.body')
```

Append to History table:
```
| Scope extracted | $(date -u +%Y-%m-%d\ %H:%M:%S) | @$(gh api user --jq '.login') | $SHORT_NAME split to $NEW_BRANCH — $NEW_PR_URL |
```

```bash
gh pr edit $ORIG_PR_NUMBER --body "<reconstructed body>"
```

### Step 7 — Write flag and PR comment

Write the appropriate flag to `status.json` in every exit path (split executed, split declined, score too high):

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")

# Pre-plan mode:
FLAG="SPLIT_PREPLAN_ANALIZED"
# Post-plan mode:
FLAG="SPLIT_POSTPLAN_ANALIZED"

echo "$EXISTING" | jq --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --arg flag "$FLAG" '. + {($flag): $ts}' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: record $FLAG"
git push origin HEAD
```

Post a PR comment via `/product-flow:pr-comments write`:
- `type: product`
- `status: ANSWERED`
- `body`: summary of score, signals, proposed split (if any), and decision

### Step 8 — Final report (if split executed)

```
## Split Complete

**[BRANCH_NAME]** — spec trimmed and re-validated
  Spec: specs/[BRANCH_NAME]/spec.md
  [If post-plan:] Plan reset — run /product-flow:continue to regenerate for reduced scope.

**[NEW_BRANCH]** — new branch created with draft PR
  Spec: specs/[NEW_BRANCH]/spec.md
  PR: [NEW_PR_URL]

[If expand-contract flagged:]
⚠️  Shared entities: [list]. Apply /product-flow:praxis.expand-contract when implementing both features in parallel.

Next steps:
- Continue current feature:  /product-flow:continue
- Start extracted feature:   switch to [NEW_BRANCH], then /product-flow:continue
```

## Exit states

**Split executed**: parent on BRANCH_NAME with trimmed + re-validated spec, child on NEW_BRANCH with validated spec and draft PR. Flag written. If post-plan: parent plan reset, awaiting /continue.

**Split declined**: no changes to spec or artifacts. Flag written. Workflow advances normally.

## Key rules

- Never delete content without the user's confirmation — the debate in Step 3 is the gate.
- Every proposed split must pass vertical slice validation (Step 4) before any commit.
- The split must be clean: no requirement appears in both specs after the split.
- If a requirement is shared, keep it in Feature A and reference it from Feature B's Assumptions.
- Never commit to the parent branch until the child branch is fully set up and pushed (steps 6b–6h complete first).
- When post-plan split is executed, always clear PLAN_GENERATED and delete plan artifacts on the parent — a plan for the full scope is invalid for the trimmed scope.
- `split-analysis.md` is updated after every debate exchange, not just at the end.
- Use absolute paths when reading or writing files.
