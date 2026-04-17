# Technical Guide

Documentation for the development team on how the plugin is built, structured, installed and maintained.

---

## Index

1. [Architecture](#1-architecture)
2. [Installation](#2-installation)
3. [Workflow details](#3-workflow-details)
4. [How to modify skills](#4-how-to-modify-skills)

---

## 1. Architecture

### Plugin structure

```
plugins/product-flow/
├── .claude-plugin/
│   └── plugin.json           ← manifest: PM commands and internal engines
├── hooks/
│   ├── git-sync.sh           ← syncs repo with origin before any public skill (UserPromptSubmit)
│   ├── intent-router.sh      ← maps short ambiguous phrases to the correct skill via status.json (UserPromptSubmit)
│   ├── state-notifier.sh     ← shows PM-friendly message on every status.json state transition (PostToolUse on Bash)
│   ├── permission-request.sh ← auto-approves safe read/write operations (PermissionRequest)
│   ├── security-guard.sh     ← blocks writes/deletes outside the repository (PreToolUse)
│   └── workflow-guard.sh     ← enforces product-flow git discipline: branch naming, no direct commits/pushes/merges to main, no PRs outside NNN-kebab-name branches, squash-only merges (PreToolUse)
└── skills/
    ├── [PM Commands — user-facing]
    │   ├── start-feature, start-improvement
    │   ├── continue, build, submit, fix, deploy-to-stage, status, context
    │
    └── [Internal engines]
        ├── [Orchestrators]
        │   ├── consolidate-spec, consolidate-plan, plan, tasks, implement, checklist, pr-comments, inbox-sync
        │
        ├── [Spec-Kit engines]
        │   ├── speckit.specify, speckit.clarify, speckit.plan, speckit.tasks
        │   ├── speckit.specify.improvement            (lean spec for improvement flow: ~1 page + integrated self-validation)
        │   ├── speckit.plan.improvement               (lean plan for improvement flow: files to touch + escalation gate)
        │   ├── speckit.implement.withTDD
        │   ├── speckit.retro, speckit.checklist
        │   ├── speckit.verify, speckit.verify-tasks, speckit.reconcile
        │   ├── speckit.split                          (mandatory pre-plan + post-plan: scope analysis, iterative debate, vertical slice enforcement)
        │
        └── [Praxis engineering skills]
            ├── praxis.complexity-review        (called in plan: challenge design)
            ├── praxis.backend-architecture     (called in plan: validate hexagonal structure)
            ├── praxis.frontend-architecture    (called in plan: validate feature-based structure)
            ├── praxis.bdd-with-approvals       (called in implement: write approval specs first)
            ├── praxis.test-desiderata          (called in implement: validate test quality)
            ├── bugmagnet                        (called in implement: adversarial coverage pass using exploratory testing heuristics)
            ├── praxis.code-simplifier          (called in implement: simplify and refine code after TDD cycles)
            ├── praxis.collaborative-design     (optional pre-spec: explore ambiguous features visually before speckit.specify)
            ├── praxis.event-modeling           (optional in plan: decompose event-driven features into slices before speckit.plan)
            └── praxis.expand-contract          (optional in plan/implement: safe migration pattern for breaking changes)
```

### Design principle

PM commands delegate to internal engines and only:
- Manage the PR (open, update status, history)
- Verify gates before executing each step
- Detect progress and optimize re-entry points (e.g. skip already-completed steps)
- Provide clear next-step instructions

**`status.json` is the source of truth** — `specs/<branch>/status.json` determines workflow state. The PR body is updated in parallel for human visibility only.

### Spec folder structure

Each feature branch has a corresponding folder under `specs/<branch>/`:

```
specs/<branch>/
├── status.json            ← workflow state machine (source of truth). Includes "flow": "feature"|"improvement"
├── gathered-context.md    ← context for feature flow (/start-feature): product framing (outcome, scenario, scope, constraints), description, clarifications, technical decisions, asset references
├── improvement-context.md ← context for improvement flow (/start-improvement): what to improve, location, change for user, scope, constraints
├── spec.md                ← feature or improvement specification (created by speckit.specify or speckit.specify.improvement)
├── plan.md                ← technical plan: data model, contracts, research (created by speckit.plan)
├── tasks.md               ← ordered task breakdown (created by speckit.tasks)
├── decisions.md           ← durable log of all PR comments/decisions
├── images/                ← uploaded visual assets (wireframes, mockups, screenshots)
│   └── sources.md         ← external visual links (Figma, Storybook, etc.) — only if provided
└── docs/                  ← uploaded documents (PDFs, API specs, requirements)
    └── sources.md         ← external doc links (Confluence, Google Docs, etc.) — only if provided
```

`gathered-context.md` is written by `/product-flow:start-feature` before spec writing and acts as the authoritative input for `speckit.specify` and `speckit.plan`. It ensures no question already answered is re-asked, and that all visual/documentation assets are accessible throughout the workflow.

### PM command flow

| Command | Internal call chain |
|---|---|
| `/product-flow:start-feature` | create branch + Draft PR → facilitated product framing (4 dimensions) + visual assets + docs → quality gate → [epic scope check: split into N branches if epic signals detected] → [`praxis.collaborative-design` if vague] → `speckit.specify` → `speckit.retro` |
| `/product-flow:start-improvement` | create branch (`NNN-improvement-<slug>`) + Draft PR → 3-question context gathering → scope analysis (escalate to start-feature if too big) → `speckit.specify.improvement` |
| `/product-flow:continue` | `inbox-sync` → flag-based routing: `consolidate-spec` + `speckit.split` pre-plan (if SPLIT_PREPLAN_ANALIZED absent) / `plan` (if PLAN_GENERATED absent) / `speckit.split` post-plan (if SPLIT_POSTPLAN_ANALIZED absent) / `consolidate-plan` (if comments) / `tasks` (if TASKS_GENERATED absent) / `checklist` (if CHECKLIST_DONE absent) — dispatched by reading `status.json` flags |
| `/product-flow:build` | `inbox-sync` → `implement` (→ `praxis.bdd-with-approvals` *(TS/JS only)* → `speckit.implement.withTDD` *(includes `praxis.code-simplifier` per task)* → `praxis.test-desiderata` → `bugmagnet` → `speckit.retro`) → `speckit.verify-tasks` → `speckit.verify` |
| `/product-flow:submit` | `inbox-sync` → `speckit.verify` (gate: CRITICAL blocks, HIGH/MEDIUM/LOW asks, passes silently) → optional git add/commit/push (only if local changes exist) → `gh pr ready` on first run (exits DRAFT) → proposes ADRs in PR body |
| `/product-flow:fix` | `inbox-sync` → `pr-comments new-comments` → diagnosis (4 dimensions, iterative) → confirmed summary → save `fixes/fix-N.md` + PR comment → clear `CODE_VERIFIED`+`VERIFY_TASKS_DONE` → append fix-tasks to `tasks.md` → `speckit.implement.withTDD [IDs]` → `speckit.verify-tasks [IDs]` → `speckit.verify` → re-set `CODE_VERIFIED`+`VERIFY_TASKS_DONE` → `spec-amendments.md` (if Ambiguity/Omission) → `speckit.retro` |
| `/product-flow:deploy-to-stage` | [ADR consolidation: ask user → generate in memory if yes] → `gh pr merge --squash --delete-branch` → [write ADRs to `docs/adr/` + commit if yes] → mark published |

---

## 2. Installation

### Prerequisites

```bash
brew install gh
gh auth login

brew install jq
```

Verify:
```bash
gh auth status
gh pr list
```

The GitHub MCP server is required by `/product-flow:build` to interact with GitHub. Install it via Claude Code:

```
/mcp add github
```

Without it, PR interactions (comments, status updates) will not work.

### Install in a project

Inside Claude Code in your project:

```
/plugin marketplace add https://github.com/deuveme/product-flow.git
/plugin install product-flow@product-flow
```

### Configure settings.json


```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(gh pr *)",
      "Bash(gh issue *)",
      "Bash(gh run *)",
      "Bash(jq *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(chmod *)"
    ],
    "deny": [
      "Bash(git push --force*)",
      "Bash(git reset --hard *)"
    ]
  }
}
```

### Verify

```
/product-flow:status
```

Expected: `📍 main  ·  no active feature`

---

## 3. Workflow details

### `/product-flow:continue` state machine

State is determined by reading `specs/<branch>/status.json` flags + a live `has_comments` check on the PR. First matching row in the routing table wins.

**Feature flow** (`flow === "feature"` or absent):

```
/product-flow:start-feature
  │  writes: FEATURE_STARTED → DESIGN_DONE → SPEC_CREATED
  ▼

SPEC_CREATED + SPLIT_PREPLAN_ANALIZED absent + has_comments  →  consolidate-spec  (clears SPLIT_PREPLAN_ANALIZED, auto-proceeds)
SPEC_CREATED + SPLIT_PREPLAN_ANALIZED absent + no comments   →  speckit.split     (writes SPLIT_PREPLAN_ANALIZED, auto-proceeds)
SPEC_CREATED + SPLIT_PREPLAN_ANALIZED + PLAN_GENERATED absent →  speckit.clarify → plan  (writes PLAN_GENERATED)

PLAN_GENERATED + SPLIT_POSTPLAN_ANALIZED absent + has_comments  →  consolidate-plan → speckit.split  (post-plan, writes SPLIT_POSTPLAN_ANALIZED)
PLAN_GENERATED + SPLIT_POSTPLAN_ANALIZED absent + no comments   →  speckit.split  (post-plan, writes SPLIT_POSTPLAN_ANALIZED)
PLAN_GENERATED + SPLIT_POSTPLAN_ANALIZED + TASKS_GENERATED absent + has_comments  →  consolidate-plan
PLAN_GENERATED + SPLIT_POSTPLAN_ANALIZED + TASKS_GENERATED absent + no comments   →  tasks  (writes TASKS_GENERATED, auto-proceeds to checklist)

TASKS_GENERATED + CHECKLIST_DONE absent + has_comments  →  consolidate-plan
TASKS_GENERATED + CHECKLIST_DONE absent + no comments   →  checklist  (writes CHECKLIST_DONE)

CHECKLIST_DONE + CODE_WRITTEN absent + has_comments  →  consolidate-plan  (clears CHECKLIST_DONE)
CHECKLIST_DONE + CODE_WRITTEN absent + no comments   →  ready for /product-flow:build
```

**Improvement flow** (`flow === "improvement"`):

```
/product-flow:start-improvement
  │  writes: IMPROVEMENT_STARTED → SPEC_CREATED (via speckit.specify.improvement)
  ▼

SPEC_CREATED + PLAN_GENERATED absent + has_comments   →  consolidate-spec
SPEC_CREATED + PLAN_GENERATED absent + no comments    →  speckit.plan.improvement  (writes PLAN_GENERATED)

PLAN_GENERATED + TASKS_GENERATED absent + has_comments  →  consolidate-plan
PLAN_GENERATED + TASKS_GENERATED absent + no comments   →  tasks  (writes TASKS_GENERATED)

TASKS_GENERATED + CODE_WRITTEN absent + has_comments  →  consolidate-plan
TASKS_GENERATED + CODE_WRITTEN absent + no comments   →  ready for /product-flow:build
                                                          (no checklist phase)
```

### PR draft lifecycle

The PR is created as a **Draft** by `/product-flow:start-feature` or `/product-flow:start-improvement` and stays in Draft through the entire spec → plan → build phase. The team can see the PR and comment on it, but GitHub does not request their review.

When `/product-flow:submit` runs for the **first time**, it calls `gh pr ready` to exit Draft mode and trigger a GitHub review request notification. Subsequent `/product-flow:submit` calls only push new commits — they do not call `gh pr ready` again.

The only approval gate is at `/product-flow:deploy-to-stage`, which requires the PR to be approved by the team before merging.

### PR comment classification

Every public command (`continue`, `build`, `submit`) runs an **Inbox check** at startup that processes two things in order:

1. **Answers to bot questions** — responses the team left using `Question <N>. Answer: [text]`. If an answer is ambiguous, the skill clarifies before applying: technical ambiguities are resolved autonomously; product ambiguities are re-asked via AskUserQuestion.
2. **New user comments** — any general or code-review comment not previously seen. Classified and resolved before continuing.

| Type | Criteria | How it's handled |
|---|---|---|
| **Product** | Business intent, priorities, user flows, terminology, functional scope | AskUserQuestion → PM answer recorded as PR comment (ANSWERED) |
| **Technical** | Architecture, security, integrations, data model, infrastructure, implementation patterns | Resolved autonomously → PR comment (ANSWERED or UNANSWERED) |
| **Ambiguous** | Could be either product or technical | Defaults to **product** — AskUserQuestion. Never resolved autonomously when classification is uncertain. |
| **Incomprehensible** | No discernible actionable intent (e.g. `"???"`, stray emoji, link without context) | No change applied. Bot comment posted as UNANSWERED asking for clarification. |

After processing, a 👍 reaction is added to each handled comment on GitHub, and all IDs are recorded in `status.json` to prevent re-processing.

**For autonomously resolved technical questions**, Claude posts a comment on the PR:

```
<!-- id:q3 type:technical status:ANSWERED -->
**Question 3 · Type: technical · Status: ANSWERED**

**Technical question detected:** "..."

**Proposed answers:** A. "..." B. "..." C. "..."

**Autonomously chosen answer:** We chose "..." because "..."

> 💬 To change this decision, add a new comment: `Question 3. Answer: [letter or answer]`
```

**For unresolved technical questions** (insufficient project context), Claude posts:

```
<!-- id:q4 type:technical status:UNANSWERED -->
**Question 4 · Type: technical · Status: UNANSWERED**

**Technical question detected:** "..."

**Possible answers:** A. "..." B. "..." C. "..."

⚠️ Unresolved — requires input from the development team.

> 💬 To answer, add a new comment: `Question 4. Answer: [letter or answer]`
```

To respond, add a **new top-level comment** to the PR (GitHub does not support direct replies). The format is flexible — all of these are valid:

```
Question 4. Answer: B
Q4: B
Question 4 - Answer: go with option B because...
```

Multiple responses for the same question are allowed — the last one wins. A single comment can respond to multiple questions, one per line.

On the next run of any public command (`/product-flow:continue`, `/product-flow:build`, or `/product-flow:submit`), Claude picks up those answers and continues.

### PR body editing convention

**Every skill that calls `gh pr edit --body` MUST follow this pattern — no exceptions:**

1. Read the current PR body first:
   ```bash
   gh pr view --json body -q '.body'
   ```
2. Apply only the intended change (update a checkbox, add a history row, replace a marked block, insert a section).
3. Pass the full updated body — with all other sections intact — to `gh pr edit --body`.

**Never reconstruct the body from scratch** unless this is `start` step 2f (initial creation) or `start` step 7 (first edit, which always runs immediately after step 2f with no other edits possible yet).

**Critical sections that must always be preserved:**
- `## Feature` — spec path
- `## Status` — all checkboxes
- `## History` — full table
- `## Notes` — free text area
- `## For Developers` — entire section including `<!-- dev-checklist -->`, `<!-- /dev-checklist -->`, and any `### Proposed ADRs` subsection

**Marked block replacements** (e.g. the dev-checklist): use the markers as boundaries. Each skill updates **only its own line** within the block — never rewrite the entire block. Lines from previous steps (already `[x]`) must remain untouched.

### Comment lifecycle (pr-comments skill)

Bot comments are tracked via invisible HTML markers on the first line:
- `<!-- id:q<N> type:technical|product status:UNANSWERED -->` — pending, will be processed on the next public command run
- `<!-- id:q<N> type:technical|product status:ANSWERED -->` — processed, will be ignored in future runs

**All bot PR comments MUST go through `/product-flow:pr-comments write`** — never `gh pr comment` directly. This guarantees every comment is numbered, marked, and appended to `specs/<branch>/decisions.md` — a durable local log that persists even if the PR is deleted.

| Operation | What it does |
|---|---|
| `write` | Posts a numbered bot comment to the PR and appends it to `decisions.md` |
| `pending` | Returns all UNANSWERED bot comments |
| `resolve` | Rewrites one or more bot comments from UNANSWERED → ANSWERED |
| `read-answers` | Reads all user `Question <N>. Answer:` responses; returns the last one per question number |
| `mark-processed` | Records applied answer question numbers in `status.json`, appends responses to `decisions.md`, adds 👍 to the user's comment |
| `new-comments` | Returns new user comments (general + code review) that are not bot-generated and not yet processed |
| `mark-comments-processed` | Adds 👍 to each general user comment and records its ID in `status.json` `processed_comment_ids` |

### Key workflow steps

**`plan` skill:**
1. Calls `/product-flow:praxis.event-modeling` (if event-driven signals detected) → decomposes into STATE_CHANGE / STATE_VIEW / AUTOMATION slices, writes `event-model.md`
2. Calls `/product-flow:speckit.plan` → generates `research.md`, `data-model.md`, `contracts/`
3. Calls `/product-flow:praxis.complexity-review` → challenges design against 30 dimensions
4. Calls `/product-flow:praxis.backend-architecture` (if backend) → validates hexagonal structure
5. Calls `/product-flow:praxis.frontend-architecture` (if frontend) → validates feature-based structure
6. Posts technical decisions as PR comments
7. Calls `/product-flow:speckit.retro` for quality validation

**`implement` skill:**
1. Calls `/product-flow:praxis.bdd-with-approvals` → writes approval fixtures (executable specs) *(TS/JS only)*
2. Calls `/product-flow:speckit.implement.withTDD` → implements with Red-Green-Refactor TDD + ZOMBIES. After each task, `praxis.code-simplifier` is invoked on the touched files. As each task is completed, its status in the PR checklist section is updated to `DONE`
3. Calls `/product-flow:praxis.test-desiderata` → validates test quality against Kent Beck's 12 properties
4. Calls `/product-flow:bugmagnet` → adversarial coverage pass: applies exploratory testing heuristics to find untested cases; writes HIGH priority tests automatically
5. Calls `/product-flow:speckit.retro` → phase retrospective and artifact sync
6. Calls `/product-flow:speckit.verify-tasks` → detects phantom completions (tasks marked done with no real implementation); fixes or escalates findings before continuing

**`consolidate-spec` skill:**
1. Reads pending PR comments and user answers via `pr-comments pending` + `pr-comments read-answers`
2. Evaluates each answer for clarity: ambiguous product answers → AskUserQuestion before proceeding; ambiguous technical answers → flagged for autonomous resolution. Incomprehensible freeform comments → posted back as UNANSWERED asking for clarification.
3. Detects conflicting comments (two items affecting the same spec section with incompatible intent) → AskUserQuestion to resolve before applying either side.
4. Delegates to `speckit.clarify` with the reconciled feedback as context → updates `spec.md`
5. Posts each decision as a PR comment via `pr-comments write` (ANSWERED or UNANSWERED)
6. Calls `pr-comments mark-processed` and `pr-comments resolve`
7. Calls `speckit.retro`

**`consolidate-plan` skill:**
1. Reads pending PR comments and user answers via `pr-comments pending` + `pr-comments read-answers`
2. Classifies each comment: product (AskUserQuestion → PM answers) / technical (applies autonomously) / ambiguous (defaults to product) / incomprehensible (posted back as UNANSWERED).
3. Detects conflicting comments before applying — conflicts are included in the AskUserQuestion call for PM resolution.
4. Updates `research.md`, `data-model.md`, and `contracts/` with the feedback
5. Posts each decision as a PR comment via `pr-comments write` (ANSWERED or UNANSWERED)
6. Calls `pr-comments mark-processed` and `pr-comments resolve`
7. Calls `speckit.retro`

**`tasks` skill:**
1. Calls `/product-flow:speckit.tasks` → generates `tasks.md` ordered by dependencies
2. Updates the PR body with a task checklist table inside `## For Developers`, listing all tasks grouped by phase, each with `TO DO` status

**`submit` skill:**
1. Verifies branch and PR exist
2. Runs `/product-flow:inbox-sync` — processes pending answers and new user comments
3. Runs `speckit.verify` — CRITICAL blocks; HIGH/MEDIUM/LOW asks the user
4. If there are local changes: shows summary (`git diff --stat`), commits and pushes
5. If there are no local changes: skips commit/push and continues to review transition
6. Takes PR out of draft on first run (`gh pr ready`)
7. Updates `status.json` with `IN_REVIEW` on first run
8. Proposes ADRs: reads `research.md` and `decisions.md`, filters decisions that would cause future inconsistency, inserts `### Proposed ADRs` inside `## For Developers` in the PR body

**`deploy-to-stage` skill:**
1. Verifies branch and PR exist
2. Gate: `IN_REVIEW` present in `status.json`
3. Gate: PR approved (`reviewDecision: APPROVED`)
4. ADR consolidation (conditional): if unchecked ADRs exist in `### Proposed ADRs`, asks the user — if yes, reads `research.md` and generates ADR file contents in memory
5. Squash merge to main, branch deleted (`gh pr merge --squash --delete-branch`)
6. Writes ADR files to `docs/adr/NNNN-<slug>.md` and commits to main (only if user confirmed in step 4)
7. Marks `- [x] Published` in the PR body and adds history row
8. Checks CI/CD pipeline status

### Automatic quality gates

These three skills are **internal** — they are not invokable directly. The
orchestrators decide when to run them:

| Skill | Triggered by | Behaviour |
|---|---|---|
| `speckit.verify` | `/product-flow:submit` (always) | Validates implementation against spec, plan, tasks, constitution. CRITICAL findings block submit; HIGH/MEDIUM/LOW ask the user; clean pass is silent |
| `speckit.verify-tasks` | `/product-flow:build` (mandatory) | Runs automatically after implement. Detects phantom completions — tasks marked done with no real implementation — before the verification gate |
| `speckit.reconcile` | `speckit.verify` (user opt-in on CRITICAL) | When verify finds CRITICAL drift, the user is offered two options: fix manually (A) or reconcile (B). Only invoked if the user chooses B and provides a gap description |

### Mandatory scope analysis

`/product-flow:speckit.split` runs at two mandatory points in every workflow, triggered automatically by `/product-flow:continue`:

| Point | When | Flag written |
|---|---|---|
| Pre-plan | After spec creation, before plan generation | `SPLIT_PREPLAN_ANALIZED` |
| Post-plan | After plan generation, before task breakdown | `SPLIT_POSTPLAN_ANALIZED` |

Default posture is to split — the feature must justify staying together. Analysis uses a scored debate (0–10 reasons to NOT split) with hard signals that force a mandatory split. Each analysis is recorded in `split-analysis.md` with the full debate history. Can also be triggered manually via handoff buttons in `speckit.specify`, `speckit.clarify`, and `speckit.plan`.

### Optional praxis skills

Some are invoked automatically under certain conditions; others require explicit invocation.

**Automatically invoked (conditional):**

| Skill | Condition | Triggered by |
|---|---|---|
| `/product-flow:praxis.collaborative-design` | Feature description is vague or short (< 15 words, no clear actor/action) | `/product-flow:start-feature` step 4 |
| `/product-flow:praxis.event-modeling` | Spec contains event-driven signals (domain events, async, webhooks, background processing) | `/product-flow:plan` step 3 |

**Manual invocation only:**

| Skill | When to use | How to invoke |
|---|---|---|
| `/product-flow:praxis.expand-contract` | Plan includes breaking changes (rename DB column, change API contract, replace service) — use to define the three migration phases | Say: "Apply expand-contract to this migration" |

---

## 4. How to modify skills

### SKILL.md structure

```markdown
---
description: "Shown in Claude Code autocomplete"
user-invocable: false        # optional — Claude-only (hides from user /menu)
context: fork                # optional — runs in isolated subagent
model: sonnet                # optional — haiku | sonnet | opus (overrides session model)
effort: medium               # optional — low | medium | high (overrides session effort)
handoffs:                    # optional — transition buttons to other skills
  - label: "Next Step"
    agent: other-skill
    prompt: "Continue with..."
    send: true
tools: ['github/github-mcp-server/issue_write']  # optional — required MCP tools
---

## Execution

### 1. Pre-checks
...
### 2. Gate (if applicable)
...
### 3. Main logic
...
### 4. Update PR status
...
### 5. Final report
...
### Session close
Invoke `/product-flow:context`.
```

### Naming conventions

| Case | Convention | Example |
|---|---|---|
| New skill | Any name | `consolidate-plan` |
| Fork of upstream skill | `<upstream>.<name>.with<Change>` | `speckit.implement.withTDD` |
| Unmodified upstream | Keep original name | `praxis.complexity-review` |

**Important:** `speckit.*` and `praxis.*` skills are upstream. Do not modify them. Fork with the `withX` suffix instead.

### Adding a new skill

1. Create `plugins/product-flow/skills/my-skill/SKILL.md`
2. Add to `plugins/product-flow/.claude-plugin/plugin.json` — all skills must be registered, both public and internal
3. Add bash permissions to project's `settings.json` if needed
4. Update PR template in `/product-flow:start-feature` or `/product-flow:start-improvement` SKILL.md if adding a workflow step
5. Update `/product-flow:status` SKILL.md if adding a progress indicator

### Modifying an existing skill

- **Upstream skills** (`speckit.*`, `praxis.*`): fork with `withX` suffix
- **Internal skills** (`consolidate-spec`, `plan`, etc.): freely editable
- Update `/product-flow:continue` SKILL.md if changing state machine
- Update `/product-flow:status` SKILL.md if changing gates

### Conventions

- Errors: `🚫 BLOCKED` or `ERROR:`
- Success: `✅`
- Next step: always in a `─────` delimited block
- Gates: read `specs/<branch>/status.json` for state; never use PR body checkboxes as logic gates
- Error messages: actionable, explain what failed and why

---

*For upstream documentation:*
- *`speckit.*` — [github/spec-kit](https://github.com/github/spec-kit)*
- *`praxis.*` — [acunap/praxis](https://github.com/acunap/praxis)*
