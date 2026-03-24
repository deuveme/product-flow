# product-flow — Plugin structure and setup

This document is for the development team. It explains how the plugin is structured, how to install it in a project and how to onboard PMs and designers.

---

## Plugin structure

```
plugins/product-flow/
├── .claude-plugin/
│   └── plugin.json           ← manifest: 7 public PM commands + 1 SessionStart hook
├── hooks/
│   └── session-start.sh      ← auto-runs /status on session start
└── skills/
    │
    ├── [PM Commands — user-facing]
    │   ├── start/SKILL.md
    │   ├── continue/SKILL.md
    │   ├── build/SKILL.md
    │   ├── submit/SKILL.md
    │   ├── deploy-to-stage/SKILL.md
    │   ├── status/SKILL.md
    │   └── context/SKILL.md
    │
    └── [Internal engines — not exposed in CLI]
        ├── [PM Orchestrators]
        │   ├── consolidate-spec/SKILL.md
        │   ├── consolidate-plan/SKILL.md
        │   ├── plan/SKILL.md
        │   ├── tasks/SKILL.md
        │   ├── implement/SKILL.md
        │   ├── checklist/SKILL.md
        │   └── check-and-clear/SKILL.md
        │
        ├── [Spec-Kit engines — upstream from github/spec-kit]
        │   ├── speckit.specify/SKILL.md
        │   ├── speckit.clarify/SKILL.md
        │   ├── speckit.plan/SKILL.md
        │   ├── speckit.tasks/SKILL.md
        │   ├── speckit.implement/SKILL.md
        │   ├── speckit.implement.withTDD/SKILL.md  ← our fork: ZOMBIES TDD per task
        │   ├── speckit.taskstoissues/SKILL.md
        │   └── speckit.retro/SKILL.md
        │
        └── [Praxis engineering skills — upstream from acunap/praxis]
            ├── praxis.complexity-review/SKILL.md   ← called in plan: challenge design
            ├── praxis.bdd-with-approvals/SKILL.md  ← called in implement: approval specs
            └── praxis.test-desiderata/SKILL.md     ← called in implement: test quality
```

---

## Initial setup (per project)

### 1. Prerequisites

Make sure every team member has installed:

```bash
# GitHub CLI
brew install gh
gh auth login

# jq (for status scripts)
brew install jq
```

Verify it works:

```bash
gh auth status
gh pr list
```

### 2. Install the plugin in a new project

Inside a Claude Code session in the target project, run:

```
/plugin marketplace add git@github.com:deuveme/product-flow.git
/plugin install product-flow@product-flow
```

Once installed, all skills are available as `/start`, `/continue`, `/build`, `/submit`, `/deploy-to-stage`, `/status`, and `/context`.

### 3. Configure settings.json

Add the necessary permissions in the target project's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git status)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git fetch *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git checkout *)",
      "Bash(git branch *)",
      "Bash(git push *)",
      "Bash(git push origin HEAD)",
      "Bash(git rebase *)",
      "Bash(git merge *)",
      "Bash(gh pr *)",
      "Bash(gh run *)",
      "Bash(jq *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(chmod *)",
      "Bash(ls *)",
      "Bash(cat *)"
    ],
    "deny": [
      "Bash(git push --force*)",
      "Bash(git reset --hard *)",
      "Bash(rm -rf *)",
      "Bash(sudo *)"
    ]
  }
}
```

### 4. Create the staging branch

```bash
git checkout -b staging && git push origin staging
git checkout main
```

### 5. Post-installation verification

Open Claude Code in the project and run:

```
/status
```

Expected response:
```
📍 You are on the main branch, with no active feature.
To start a feature: /start <description>
```

---

## Onboarding PMs and designers

1. Share `docs/onboarding.md` with the team
2. Run a 30-minute session where they run `/start` together for the first time
3. Make sure they have Claude Code installed and access to the repo

The only commands they need to remember are:

| Command | What it does |
|---|---|
| `/start` | Start something new |
| `/continue` | Advance to the next step |
| `/build` | Generate the code |
| `/submit` | Share their work |
| `/deploy-to-stage` | Publish to staging |
| `/status` | See where I am |

The rest appears naturally in the workflow.

---

## Adding or modifying skills

### SKILL.md structure

Each `SKILL.md` follows this pattern:

```markdown
---
description: "Brief description that Claude Code shows in autocomplete"
---

## Purpose
What the skill does and what it's for.

## Execution

### 1. Pre-checks
...

### 2. Gate (if applicable)
Condition that must be met. If not: ERROR with clear message.

### 3. Main logic
Invocation to speckit or bash commands.

### 4. Update PR status
Mark checkboxes, add row to history.

### 5. Final report
What to show the user and what the next step is.

### Session close
Context traffic light (🟢/🟡/🟠/🔴).
```

### Adding a new skill

1. Create `plugins/product-flow/skills/my-skill/SKILL.md`
2. Add `"my-skill"` to the `skills` array in `plugins/product-flow/.claude-plugin/plugin.json`
3. If it needs new bash permissions, add them to the project's `settings.json`

### Conventions

- Error messages: start with `🚫 BLOCKED` or `ERROR:`
- Final reports: start with `✅`
- Next step: always in a block delimited with `─────`
- Gates: read the PR body with `gh pr view --json body`, never local files

---

## Design principle

PM commands have no logic of their own regarding specs, plans or code. They delegate completely to internal engines. Their exclusive responsibility is to:

- Manage the PR (open, update status, history)
- Verify gates before executing each step
- Provide clear instructions on the next step

**The workflow state lives in the PR body checkboxes** — `gh pr view --json body` is the source of truth, not local files.
