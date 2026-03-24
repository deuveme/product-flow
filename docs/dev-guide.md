# Technical plugin guide

Documentation for the development team on how the plugin is built, how to install it and how to maintain it.

---

## Index

1. [Plugin architecture](#1-plugin-architecture)
2. [Installation and configuration](#2-installation-and-configuration)
3. [What each skill does internally](#3-what-each-skill-does-internally)
4. [Your role in the workflow: approving the spec, plan and code](#4-your-role-in-the-workflow-approving-the-spec-plan-and-code)
5. [How to add or modify skills](#5-how-to-add-or-modify-skills)

---

## 1. Plugin architecture

The plugin is divided into layers inside `plugins/product-flow/skills/`:

```
skills/
├── PM commands        ← exposed in CLI, user-facing
│   ├── start/
│   ├── continue/      ← state machine (see below)
│   ├── build/
│   ├── submit/
│   ├── deploy-to-stage/
│   ├── status/
│   └── context/
│
├── internal commands  ← not exposed in CLI, invoked by PM commands
│   ├── consolidate-spec/
│   ├── consolidate-plan/
│   ├── plan/
│   ├── tasks/
│   ├── implement/
│   ├── checklist/
│   └── check-and-clear/
│
├── speckit.*          ← upstream engine from github/spec-kit (verbatim, do not modify)
│   ├── speckit.specify/
│   ├── speckit.clarify/
│   ├── speckit.plan/
│   ├── speckit.tasks/
│   ├── speckit.taskstoissues/
│   ├── speckit.implement/
│   ├── speckit.implement.withTDD/  ← our fork: ZOMBIES TDD per task
│   ├── speckit.checklist/
│   └── speckit.retro/
│
└── praxis.*           ← upstream engineering skills from acunap/praxis (verbatim, do not modify)
    ├── praxis.complexity-review/   ← called in plan: challenge design
    ├── praxis.bdd-with-approvals/  ← called in implement: write approval specs
    └── praxis.test-desiderata/     ← called in implement: validate test quality
```

**Design principle:** PM commands have no logic of their own regarding specs, plans or code. They delegate completely to the corresponding internal and `speckit.*` skills. Their exclusive responsibility is to:

- Manage the PR (open, update status, history)
- Verify gates before executing each step
- Provide clear instructions on the next step

**Composability rule:** Every state transition in `continue` MUST delegate to a named sub-skill. No step is performed inline. If a transition requires work with no dedicated sub-skill, surface the gap — do not implement it inline.

### `/continue` state machine

`continue` is a pure orchestrator. It reads the PR state and dispatches to the right sub-skill:

```
                     /start
                       │
                       ▼
               ┌──────────────┐
               │ SPEC_CREATED │◄─── after consolidating feedback
               └──────┬───────┘
                       │ team adds comments
                       ▼
               ┌──────────────┐
               │ SPEC_REVIEW  │──── /consolidate-spec ──►  SPEC_CREATED
               └──────────────┘
                       │ team approves spec
                       ▼
               ┌──────────────┐
               │ PLAN_PENDING │◄─── auto: /plan runs here
               └──────┬───────┘
                       │ team adds comments on plan
                       ▼
               ┌──────────────┐
               │ PLAN_REVIEW  │──── /consolidate-plan ──►  PLAN_PENDING
               └──────────────┘
                       │ team approves plan
                       ▼
               ┌──────────────┐
               │ BUILD_READY  │──── blocked: redirect to /build
               └──────────────┘
```

| State | Sub-skill invoked |
|-------|-------------------|
| `SPEC_REVIEW` | `/consolidate-spec` |
| `PLAN_PENDING` | `/plan` |
| `PLAN_REVIEW` | `/consolidate-plan` |

### Session hook gates

`session-start.sh` injects two behavioral gates at session start:

1. **Workflow gate** — If the user asks to build/implement something with no active feature branch → suggest `/start`, do not generate code.
2. **Implementation gate** — If there is an active PR with pending workflow steps → suggest the right command, do not implement outside the workflow.

These are guardrails, not hard blocks. If the user explicitly chooses to proceed outside the workflow, Claude respects that.

### Relationship between commands

**PM commands (user-facing):**

| PM Command | Delegates to | Own responsibility |
|---|---|---|
| `/start` | Internal spec engine | Open draft PR, initial push |
| `/continue` | State machine → consolidate-spec / plan / consolidate-plan | Detect state, dispatch, inform PM |
| `/build` | Internal tasks + checklist + implement | Verify plan approved gate, inform PM |
| `/submit` | — | Git add/commit/push, PR ready |
| `/deploy-to-stage` | — | Verify approval, squash merge |
| `/status` | — | Read PR state and orient |
| `/context` | — | Show session context usage |

**Internal commands:**

| Internal command | Delegates to | Own responsibility |
|---|---|---|
| `consolidate-spec` | `speckit.clarify` | Verify gate, commit, update PR |
| `consolidate-plan` | — | Read PR comments, apply to plan artifacts, commit |
| `plan` | `speckit.plan` → `praxis.complexity-review` | Verify gate, challenge design, commit, update PR |
| `tasks` | `speckit.tasks` + `speckit.taskstoissues` | Verify gate, commit, update PR |
| `implement` | `praxis.bdd-with-approvals` → `speckit.implement.withTDD` → `praxis.test-desiderata` | Verify gate, sync with main, validate tests |
| `checklist` | `speckit.checklist` | Commit (no gate) |

### PR status as source of truth

The workflow state lives in the PR body, not in local files. The checkboxes are the gate mechanism:

```markdown
## Status
- [x] Spec created
- [x] Spec approved by the development team
- [x] Plan generated
- [ ] Plan approved by the development team   ← blocks /build
- [ ] Tasks generated                          ← managed internally
- [ ] Code generated                           ← blocks /submit
- [ ] In code review                           ← blocks /deploy-to-stage
- [ ] Published
```

Commands read this body with `gh pr view --json body` to determine whether they can be executed.

---

## 2. Installation and configuration

### Prerequisites

- Claude Code installed
- `gh` CLI installed and authenticated (see below)
- `jq` installed (`brew install jq` on Mac)
- Repo access with push permissions

### Install and authenticate `gh` CLI

```bash
brew install gh
gh auth login
```

The process asks the following:

| Question | Answer |
|----------|-----------|
| Where do you use GitHub? | **GitHub.com** |
| What is your preferred protocol? | **HTTPS** |
| How would you like to authenticate? | **Login with a web browser** |

When choosing the browser:
1. The terminal shows an 8-character code (`XXXX-XXXX`)
2. The browser opens at `github.com/login/device`
3. Enter the code and click **Continue**
4. Authorise the application with your GitHub account

Verify it works:

```bash
gh auth status
gh pr list  # should respond without errors
```

### Install the plugin in a project

```bash
# Copy plugin
cp -r /path/to/product-flow/plugins /path/to/my-project/
```

Merge the permissions into `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git push *)",
      "Bash(git push origin HEAD)",
      "Bash(git rebase *)",
      "Bash(git merge *)",
      "Bash(gh pr *)",
      "Bash(gh run *)",
      "Bash(jq *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(chmod *)"
    ]
  }
}
```

### Post-installation verification

Run in Claude Code:

```
/status
```

Expected response:
```
📍 You are on the main branch, with no active feature.
To start a feature: /start <description>
```

---

## 3. What each skill does internally

### 3.1 Public commands (PM-facing)

---

#### `/start <description>`

Starts a new feature from scratch. Creates spec and draft PR.

**Calls:** `speckit.specify` → `speckit.retro` → `check-and-clear`

1. Verifies on `main` with no uncommitted changes
2. Calls `speckit.specify`: creates branch `NNN-short-name`, writes `specs/NNN-short-name/spec.md`, classifies technical questions and resolves them autonomously or records them as unresolved
3. Pushes branch to origin
4. Opens draft PR with status checkboxes and history table
5. Posts one PR comment per technical decision (proposed or unresolved)
6. Calls `speckit.retro` to validate spec quality
7. Calls `check-and-clear` to report context level

Note: When the team approves the spec and `/continue` is run, the `plan` step will challenge the design against 30 complexity dimensions using `praxis.complexity-review` before the team sees the technical plan.

**What can go wrong:** if `speckit.specify` fails, no PR is opened. The branch may have been created locally — run `git checkout main && git branch -d NNN-short-name` manually.

---

#### `/continue`

Reads the current workflow state and dispatches to the appropriate sub-skill. Pure orchestrator — no business logic inline.

**State machine:** `SPEC_CREATED → SPEC_REVIEW → PLAN_PENDING → PLAN_REVIEW → BUILD_READY`

**Dispatches to (depending on state):** `consolidate-spec` | `plan` (which delegates to `speckit.plan` → `praxis.complexity-review`) | `consolidate-plan` → `check-and-clear`

1. Reads PR state via `gh pr view --json body,comments`
2. Maps checkboxes + comment activity to current state
3. Displays current state name before acting
4. Dispatches to the sub-skill for that state:
   - `SPEC_REVIEW` → calls `consolidate-spec`
   - `PLAN_PENDING` → calls `plan` (which challenges design for over-engineering before team review)
   - `PLAN_REVIEW` → calls `consolidate-plan`
   - Waiting states → shows message and stops
   - `BUILD_READY` → redirects to `/build` and stops
5. Calls `check-and-clear`

**Repeatable:** can be run after each round of team feedback.

---

#### `/build`

Generates the code. Requires plan approved by the team.

**Calls:** `tasks` → `checklist` → `implement` (which delegates to `praxis.bdd-with-approvals` → `speckit.implement.withTDD` → `praxis.test-desiderata`) → `check-and-clear`

1. Verifies gate: `Plan approved` checkbox marked in PR
2. Verifies there are no unanswered technical decisions in PR comments
3. Calls `tasks` (generates `tasks.md` and creates GitHub issues)
4. Calls `checklist` (validates requirements quality — mandatory before implementing)
5. If checklist finds CRITICAL issues: stops and asks PM to fix before continuing
6. Calls `implement`:
   - Writes approval fixtures before implementation
   - Generates the code using TDD per task with Red-Green-Refactor cycles
   - Validates test quality against Kent Beck's 12 Test Desiderata properties
7. Calls `check-and-clear`

---

#### `/submit`

Commits, pushes and takes the PR out of draft.

**Calls:** `check-and-clear`

1. Verifies gate: `Code generated` marked in PR
2. Verifies there are uncommitted changes
3. Shows `git diff --stat HEAD`
4. Runs `git add -A && git commit && git push`
5. If PR is in draft: runs `gh pr ready` and marks `In code review`
6. Calls `check-and-clear`

**Repeatable:** each push updates the PR without changing the status.

---

#### `/deploy-to-stage`

Squash-merges to main and triggers deploy.

**Calls:** `check-and-clear`

1. Verifies gate: `In code review` marked in PR
2. Verifies `reviewDecision == APPROVED` via `gh pr view --json reviewDecision`
3. Runs `gh pr merge --squash --delete-branch`
4. Runs `gh run list --limit 3` to confirm GitHub Actions started
5. Calls `check-and-clear`

---

#### `/status`

Shows where the feature is in the workflow.

**Calls:** `check-and-clear`

1. Verifies `gh` is installed and authenticated
2. Reads branch, uncommitted changes and PR checkboxes
3. Displays progress with ✅ / ▶️ / ⏳ / 🔒 per step
4. Shows the next actionable command
5. Calls `check-and-clear`

---

#### `/context`

Shows how much session memory Claude has used.

No calls to other skills.

1. Estimates context usage based on conversation history
2. Displays a visual bar and recommendation (🟢 / 🟡 / 🟠 / 🔴)
3. Shows the next pending workflow step

---

### 3.2 Internal commands (called by public commands)

---

#### `consolidate-spec`

Integrates team feedback from PR comments into `spec.md`.

Called by: `/continue` (state: `SPEC_REVIEW`)

**Calls:** `speckit.clarify` → `speckit.retro` → `check-and-clear`

1. Verifies gate: `Spec created` marked in PR
2. Verifies there are comments on the PR
3. Collects corrections (`Correction:` / `Answer:` comments) to pass as context
4. Calls `speckit.clarify`: reads current spec, processes clarifications, updates `spec.md`
5. Posts one PR comment per technical decision (proposed or unresolved)
6. Commits `spec.md` and pushes
7. Updates PR history
8. Calls `speckit.retro` to validate quality after clarification
9. Calls `check-and-clear`

**Repeatable:** one run per feedback round.

---

#### `consolidate-plan`

Integrates team feedback from PR comments into plan artifacts (`plan.md`, `research.md`, `data-model.md`, `contracts/`).

Called by: `/continue` (state: `PLAN_REVIEW`)

1. Verifies gate: `Plan generated` marked in PR
2. Reads PR comments targeting plan artifacts
3. Applies corrections and answers, grouped by affected artifact
4. Validates cross-artifact consistency after applying changes
5. Commits updated artifacts and pushes
6. Posts PR comment summarising what changed
7. Calls `check-and-clear`

**Repeatable:** one run per feedback round.

---

#### `plan`

Generates the full technical plan once the spec is approved.

Called by: `/continue` (state: `PLAN_PENDING`)

**Calls:** `speckit.plan` → `praxis.complexity-review` → `speckit.retro` → `check-and-clear`

1. Verifies gate: `Spec approved` marked in PR
2. Applies any `Correction:` / `Answer:` comments to `spec.md` before delegating
3. Verifies no unanswered technical decisions remain
4. Calls `speckit.plan`: generates `research.md`, `data-model.md`, `contracts/`
5. Verifies the artifacts exist
6. Calls `praxis.complexity-review`: evaluates the proposal against 30 complexity dimensions to identify over-engineering before team reviews it
7. Posts one PR comment per technical decision (proposed or unresolved)
8. Commits plan artifacts and pushes
9. Marks `Plan generated` in PR
10. Calls `speckit.retro`
11. Calls `check-and-clear`

---

#### `tasks`

Breaks the approved plan into ordered tasks and creates GitHub issues.

Called by: `/build`

**Calls:** `speckit.tasks` → `speckit.taskstoissues` → `speckit.retro` → `check-and-clear`

1. Verifies gate: `Plan approved` marked in PR
2. Applies any `Correction:` / `Answer:` comments to plan artifacts before delegating
3. Verifies no unanswered technical decisions remain
4. Calls `speckit.tasks`: reads spec, plan, data-model, contracts → generates `tasks.md` with phases and dependencies
5. Calls `speckit.taskstoissues`: reads `tasks.md` → creates one GitHub issue per task
6. Posts one PR comment per technical decision (proposed or unresolved)
7. Commits `tasks.md` and pushes
8. Marks `Tasks generated` in PR
9. Calls `speckit.retro`
10. Calls `check-and-clear`

---

#### `implement`

Generates the feature code from all available artifacts, using TDD per task and quality validation.

Called by: `/build`

**Calls:** `praxis.bdd-with-approvals` → `speckit.implement.withTDD` → `praxis.test-desiderata` → `speckit.retro` → `check-and-clear`

1. Verifies gate: `Tasks generated` marked in PR
2. Applies any `Correction:` / `Answer:` comments before delegating
3. Verifies no unanswered technical decisions remain
4. Verifies no uncommitted changes
5. Runs `git fetch origin && git rebase origin/main` (critical to avoid conflicts)
6. Calls `praxis.bdd-with-approvals`: writes approval fixture files (executable specifications in domain language) before implementation
7. Calls `speckit.implement.withTDD`: reads spec, plan, data-model, contracts and tasks → implements each task with Red-Green-Refactor TDD cycles using the ZOMBIES heuristic, making the approval fixtures pass
8. Calls `praxis.test-desiderata`: analyzes generated test code against Kent Beck's 12 Test Desiderata properties to validate test quality
9. Marks `Code generated` in PR
10. Calls `speckit.retro`
11. Calls `check-and-clear`

---

#### `checklist`

Mandatory quality validation of spec, plan and tasks. Runs automatically as part of `/build` before implementation.

Called by: `/build`

**Calls:** `speckit.checklist` → `check-and-clear`

1. Verifies on a feature branch with open PR
2. Verifies `spec.md` exists
3. Calls `speckit.checklist`: detects available artifacts, generates `specs/<dir>/checklists/<domain>.md` validating completeness, clarity, consistency, measurability, coverage
4. Commits checklist and pushes
5. Calls `check-and-clear`

Does not block the workflow — purely informational.

---

### 3.3 Utilities (called by all commands)

---

#### `check-and-clear`

Context monitor. Called at the end of every command.

No calls to other skills.

1. Estimates % of context used based on conversation length and tool use
2. Acts by level:
   - **< 50% 🟢** — shows nothing
   - **50–89% 🟡/🟠** — shows bar + warning, does nothing else
   - **≥ 90% 🔴** — stops all execution and instructs the user to run `/clear` before continuing

---

### 3.4 Engineering skills (integrated into workflow)

These skills are now called automatically at specific workflow steps:

| Skill | Called from | Purpose |
|---|---|---|
| `praxis.complexity-review` | `plan` (step 5) | Challenge the technical design against 30 complexity dimensions before team review |
| `praxis.bdd-with-approvals` | `implement` (step 5) | Write approval fixture files (executable specifications) before code implementation |
| `praxis.test-desiderata` | `implement` (step 7) | Analyze test quality against Kent Beck's 12 Test Desiderata properties after TDD |

---

## 4. Your role in the workflow: approving the spec, plan and code

As a dev, your responsibility in the workflow is the three technical decision checkpoints:

### Approve the spec

When the PM runs `/start`, the draft PR opens with `spec.md`:

1. Open the PR on GitHub → **Files changed** tab
2. Review `spec.md` — requirements, use cases, acceptance criteria
3. Leave inline comments if there's anything to change
4. When ready: **Review changes → Approve**

> To mark the checkbox: edit the PR body changing `- [ ] Spec approved` to `- [x] Spec approved`.

---

### Approve the plan

When `/continue` generates the plan, the PR is updated with `research.md`, `data-model.md` and `contracts/`:

1. Review the technical artifacts in **Files changed**
2. Leave comments if there are technical decisions to change
3. When ready: **Review changes → Approve**

> Mark `- [x] Plan approved` in the PR body.

---

### Review the code

When the PM runs `/submit`, the PR exits draft:

1. Review the code in **Files changed**
2. Request changes if there are any
3. When ready: **Review changes → Approve**

After your approval, anyone can run `/deploy-to-stage`.

---

## 5. How to add or modify skills

### SKILL.md structure

```markdown
---
description: "Brief description that appears in Claude Code autocomplete"
---

## Purpose
What the skill does and what it's for.

## Execution

### 1. Pre-checks
...

### 2. Gate (if applicable)
Condition that must be met. If not met: ERROR with clear message.

### 3. Main logic
Invocation to speckit.* or bash commands.

### 4. Update PR status
Mark checkboxes, add row to history.

### 5. Final report
What to show the user and what the next step is.

### Session close
Standard context traffic light (🟢/🟡/🟠/🔴).
```

### Naming conventions

| Case | Convention | Example |
|---|---|---|
| New skill (original) | Any name | `consolidate-plan` |
| Fork of a `speckit.*` skill | `speckit.<name>.with<Change>` | `speckit.implement.withTDD` |
| `speckit.*` or `praxis.*` skill (unmodified) | Keep upstream name | `praxis.complexity-review`, `speckit.plan` |
| `speckit.*` or `praxis.*` skill (modified for our context) | `<prefix>.<name>.with<Change>` | `praxis.backend-architecture.withOurConventions` |

### Adding a new skill

1. Create `plugins/product-flow/skills/my-skill/SKILL.md`
2. Add `"my-skill"` to the `skills` array in `plugins/product-flow/.claude-plugin/plugin.json` only if it is a public command
3. If it needs new bash permissions, add them to the target project's `settings.json`
4. If it is part of the linear workflow, update the PR template in `start/SKILL.md` to add the new checkbox
5. Update `status/SKILL.md` so the new step appears in the progress report

### Modifying an existing skill

- `speckit.*` skills **must not be modified** — they are upstream. Fork with the `withX` suffix instead.
- `praxis.*` skills copied verbatim **must not be modified** — they are upstream. Fork with the `withX` suffix instead.
- Internal skills (`consolidate-spec`, `plan`, `tasks`, `implement`, `checklist`) can be freely edited.
- If you change the gates of a skill, make sure `status/SKILL.md` reflects the new state.
- If you add a new state to `/continue`, update the state machine diagram in this guide and in `continue/SKILL.md`.

### Conventions

- Error messages start with `🚫 BLOCKED` or `ERROR:`
- Final reports start with `✅`
- The next step is always shown in a block delimited with `─────`
- Critical bash commands (merge, push) are validated before executing
- Gates read the PR body with `gh pr view --json body` — not local files
- `continue` dispatches only — it never performs work inline

---

*For questions about upstream skills:*
- *`speckit.*` — consult upstream at [github/spec-kit](https://github.com/github/spec-kit)*
- *`praxis.*` — consult upstream at [acunap/praxis](https://github.com/acunap/praxis)*

*Do not modify these skills — fork with the `withX` naming convention instead.*
