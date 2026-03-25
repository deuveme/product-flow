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
│   └── session-start.sh      ← auto-runs /status on session start
└── skills/
    ├── [PM Commands — user-facing]
    │   ├── start, continue, build, submit, deploy-to-stage, status, context
    │
    └── [Internal engines]
        ├── [Orchestrators]
        │   ├── consolidate-spec, consolidate-plan, plan, tasks, implement, checklist, check-and-clear, pr-comments
        │
        ├── [Spec-Kit engines]
        │   ├── speckit.specify, speckit.clarify, speckit.plan, speckit.tasks
        │   ├── speckit.implement.withTDD
        │   ├── speckit.taskstoissues, speckit.retro, speckit.checklist
        │
        └── [Praxis engineering skills]
            ├── praxis.complexity-review      (called in plan: challenge design)
            ├── praxis.backend-architecture   (called in plan: validate hexagonal structure)
            ├── praxis.frontend-architecture  (called in plan: validate feature-based structure)
            ├── praxis.bdd-with-approvals     (called in implement: write approval specs first)
            └── praxis.test-desiderata        (called in implement: validate test quality)
```

### Design principle

PM commands have no logic. They delegate completely to internal engines and only:
- Manage the PR (open, update status, history)
- Verify gates before executing each step
- Provide clear next-step instructions

**The PR body is the source of truth** — `gh pr view --json body` determines workflow state, not local files.

### PM command flow

| Command | Internal call chain |
|---|---|
| `/start` | `speckit.specify` → `speckit.retro` |
| `/continue` | `pr-comments pending` → `consolidate-spec` / `plan` / `consolidate-plan` (dispatched by state machine) |
| `/build` | `tasks` → `checklist` → `implement` (→ `praxis.bdd-with-approvals` → `speckit.implement.withTDD` → `praxis.test-desiderata`) |
| `/submit` | git add/commit/push |
| `/deploy-to-stage` | git merge --squash |

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
/status
```

Expected: `📍 You are on the main branch, with no active feature.`

---

## 3. Workflow details

### `/continue` state machine

```
/start
  │
  ▼
SPEC_CREATED  ←──── /consolidate-spec ←──── SPEC_REVIEW  (team adds comments)
  │ (team approves)
  ▼
PLAN_PENDING  ──── /plan auto-runs ──────────────────────────────────────────┐
  │                                                                           │
  │ (team adds comments on plan)                                              ▼
  ▼                                                                     PLAN_PENDING
PLAN_REVIEW   ←──── /consolidate-plan ─────────────────────────────────  (waiting)
  │ (team approves)
  ▼
BUILD_READY   ──── redirect to /build
```

### Key workflow steps

**`plan` skill:**
1. Calls `speckit.plan` → generates `research.md`, `data-model.md`, `contracts/`
2. Calls `praxis.complexity-review` → challenges design against 30 dimensions
3. Calls `praxis.backend-architecture` (if backend) → validates hexagonal structure
4. Calls `praxis.frontend-architecture` (if frontend) → validates feature-based structure
5. Posts technical decisions as PR comments
6. Calls `speckit.retro` for quality validation

**`implement` skill:**
1. Calls `praxis.bdd-with-approvals` → writes approval fixtures (executable specs)
2. Calls `speckit.implement.withTDD` → implements with Red-Green-Refactor TDD + ZOMBIES
3. Calls `praxis.test-desiderata` → validates test quality against Kent Beck's 12 properties
4. Calls `speckit.retro` for quality validation

---

## 4. How to modify skills

### SKILL.md structure

```markdown
---
description: "Shown in Claude Code autocomplete"
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
(context traffic light)
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
2. Add to `plugins/product-flow/.claude-plugin/plugin.json` only if public
3. Add bash permissions to project's `settings.json` if needed
4. Update PR template in `start/SKILL.md` if adding a workflow step
5. Update `status/SKILL.md` if adding a progress indicator

### Modifying an existing skill

- **Upstream skills** (`speckit.*`, `praxis.*`): fork with `withX` suffix
- **Internal skills** (`consolidate-spec`, `plan`, etc.): freely editable
- Update `continue/SKILL.md` if changing state machine
- Update `status/SKILL.md` if changing gates

### Conventions

- Errors: `🚫 BLOCKED` or `ERROR:`
- Success: `✅`
- Next step: always in a `─────` delimited block
- Gates: read PR with `gh pr view --json body`, never local files
- Error messages: actionable, explain what failed and why

---

*For upstream documentation:*
- *`speckit.*` — [github/spec-kit](https://github.com/github/spec-kit)*
- *`praxis.*` — [acunap/praxis](https://github.com/acunap/praxis)*
