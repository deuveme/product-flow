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
│   └── plugin.json           ← manifest: 7 public PM commands
├── hooks/
│   ├── security-guard.sh     ← blocks writes/deletes outside the repository (PreToolUse)
│   └── workflow-guard.sh     ← enforces product-flow git discipline: branch naming, no direct commits/pushes/merges to main, no PRs outside NNN-kebab-name branches, squash-only merges (PreToolUse)
└── skills/
    ├── [PM Commands — user-facing]
    │   ├── start, continue, build, submit, deploy-to-stage, status, context
    │
    └── [Internal engines]
        ├── [Orchestrators]
        │   ├── consolidate-spec, consolidate-plan, plan, tasks, implement, checklist, pr-comments
        │
        ├── [Spec-Kit engines]
        │   ├── speckit.specify, speckit.clarify, speckit.plan, speckit.tasks
        │   ├── speckit.implement.withTDD
        │   ├── speckit.retro, speckit.checklist
        │   ├── speckit.verify, speckit.verify-tasks, speckit.reconcile
        │   ├── speckit.split                          (optional pre-tasks: split over-scoped specs)
        │
        └── [Praxis engineering skills]
            ├── praxis.complexity-review        (called in plan: challenge design)
            ├── praxis.backend-architecture     (called in plan: validate hexagonal structure)
            ├── praxis.frontend-architecture    (called in plan: validate feature-based structure)
            ├── praxis.bdd-with-approvals       (called in implement: write approval specs first)
            ├── praxis.test-desiderata          (called in implement: validate test quality)
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

### PM command flow

| Command | Internal call chain |
|---|---|
| `/product-flow:start` | create branch + Draft PR → [`praxis.collaborative-design` if vague] → `speckit.specify` → `speckit.retro` |
| `/product-flow:continue` | state machine: `SPEC_REVIEW` → `consolidate-spec` / `PLAN_PENDING` → `plan` / `PLAN_REVIEW` → `consolidate-plan` (dispatched by state machine) |
| `/product-flow:build` | `tasks` → `checklist` → `implement` (→ `praxis.bdd-with-approvals` *(TS/JS only)* → `speckit.implement.withTDD` *(includes `praxis.code-simplifier` per task)* → `praxis.test-desiderata` → `speckit.retro`) → proposes `speckit.verify-tasks` |
| `/product-flow:submit` | `speckit.verify` (gate: CRITICAL blocks, HIGH/MEDIUM/LOW asks, passes silently) → git add/commit/push → `gh pr ready` on first run (exits DRAFT) → proposes ADRs in PR body |
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
/plugin marketplace add git@github.com:deuveme/product-flow.git
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

```
/product-flow:start
  │
  ▼
SPEC_CREATED  ←──── /product-flow:consolidate-spec ←──── SPEC_REVIEW  (team adds comments)
  │ (no comments)
  ▼
PLAN_PENDING  ──── speckit.clarify runs first (ambiguity check) ──── /product-flow:plan auto-runs ──┐
                                                                                                    │
  (team adds comments on plan)                                                                       ▼
PLAN_REVIEW   ←──── /product-flow:consolidate-plan ───────────────────────────────────────── PLAN_PENDING
  │ (no comments)
  ▼
READY_TO_BE_BUILT ──── redirect to /product-flow:build
```

### PR draft lifecycle

The PR is created as a **Draft** by `/product-flow:start` and stays in Draft through the entire spec → plan → build phase. The team can see the PR and comment on it, but GitHub does not request their review.

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
4. Calls `/product-flow:speckit.retro` → phase retrospective and artifact sync
5. Proposes `/product-flow:speckit.verify-tasks` → user chooses: run now, open new session, or skip

**`consolidate-spec` skill:**
1. Reads pending PR comments and user answers via `pr-comments pending` + `pr-comments read-answers`
2. Classifies each comment: product (AskUserQuestion → PM answers) / technical (resolves autonomously)
3. Delegates to `speckit.clarify` with the feedback as context → updates `spec.md`
4. Posts each decision as a PR comment via `pr-comments write` (ANSWERED or UNANSWERED)
5. Calls `pr-comments mark-processed` and `pr-comments resolve`
6. Calls `speckit.retro`

**`consolidate-plan` skill:**
1. Reads pending PR comments and user answers via `pr-comments pending` + `pr-comments read-answers`
2. Classifies each comment: product (AskUserQuestion → PM answers) / technical (applies autonomously)
3. Updates `research.md`, `data-model.md`, and `contracts/` with the feedback
4. Posts each decision as a PR comment via `pr-comments write` (ANSWERED or UNANSWERED)
5. Calls `pr-comments mark-processed` and `pr-comments resolve`
6. Calls `speckit.retro`

**`tasks` skill:**
1. Calls `/product-flow:speckit.tasks` → generates `tasks.md` ordered by dependencies
2. Updates the PR body with a task checklist table inside `## For Developers`, listing all tasks grouped by phase, each with `TO DO` status

**`submit` skill:**
1. Verifies branch and PR exist
2. Runs **Inbox check** — processes pending answers and new user comments (same as `continue` and `build`)
3. Runs `speckit.verify` — CRITICAL blocks; HIGH/MEDIUM/LOW asks the user
3. Verifies there are uncommitted changes
4. Shows change summary (`git diff --stat`)
5. Commits and pushes
6. Takes PR out of draft on first run (`gh pr ready`)
7. Updates `status.json` with `in_review` on first run
8. Proposes ADRs: reads `research.md` and `decisions.md`, filters decisions that would cause future inconsistency, inserts `### Proposed ADRs` inside `## For Developers` in the PR body

**`deploy-to-stage` skill:**
1. Verifies branch and PR exist
2. Gate: `in_review` present in `status.json`
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
| `speckit.verify-tasks` | `/product-flow:build` (proposed) | Proposed at the end of implement. User chooses: run now, open a new session, or skip |
| `speckit.reconcile` | `speckit.verify` (user opt-in on CRITICAL) | When verify finds CRITICAL drift, the user is offered two options: fix manually (A) or reconcile (B). Only invoked if the user chooses B and provides a gap description |

### Optional praxis skills

Some are invoked automatically under certain conditions; others require explicit invocation.

**Automatically invoked (conditional):**

| Skill | Condition | Triggered by |
|---|---|---|
| `/product-flow:praxis.collaborative-design` | Feature description is vague or short (< 15 words, no clear actor/action) | `/product-flow:start` step 3 |
| `/product-flow:praxis.event-modeling` | Spec contains event-driven signals (domain events, async, webhooks, background processing) | `/product-flow:plan` step 3 |

**Manual invocation only:**

| Skill | When to use | How to invoke |
|---|---|---|
| `/product-flow:praxis.expand-contract` | Plan includes breaking changes (rename DB column, change API contract, replace service) — use to define the three migration phases | Say: "Apply expand-contract to this migration" |
| `/product-flow:speckit.split` | Spec covers too many bounded contexts, user personas, or independent deliverables — use after `speckit.specify`, `speckit.clarify`, or `speckit.plan` and before `speckit.tasks` to extract the excess scope into a new branch with its own draft PR. Also offered automatically as a handoff button at the end of those three skills. | Say: "Analyze if this spec should be split" or use the handoff button |

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
4. Update PR template in `/product-flow:start` SKILL.md if adding a workflow step
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
