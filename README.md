# product-flow

Claude Code plugin for spec-driven development workflows. Enables PMs, designers, and developers to work together in a structured process: from specification through code generation to deployment, with Claude as an assistant at every step.

---

## Install

Inside a Claude Code session in your project, run:

```
/plugin marketplace add git@github.com:deuveme/product-flow.git
/plugin install product-flow@product-flow
```

Once installed, all commands are available as `/start`, `/continue`, `/build`, `/submit`, `/deploy-to-stage`, `/status`, and `/context`. A `SessionStart` hook automatically runs `/status` when you open Claude Code and enforces workflow gates to prevent premature coding.

---

## What's included

### PM workflow (user-facing commands)

| Command | When to use it |
|---|---|
| `/start` | Start a new feature |
| `/continue` | Advance to the next step (repeatable) |
| `/build` | Generate the code once the plan is approved |
| `/submit` | Share the code for team review |
| `/deploy-to-stage` | Publish to staging with squash merge |
| `/status` | See where you are in the workflow |
| `/context` | See how much memory Claude has left |

### Feature lifecycle

```
/start "description"
        ↓
   /continue  (repeat until the plan is approved)
   — integrates team feedback into the spec
   — generates the technical plan once the spec is approved
        ↓
   Team approves the plan  ← mandatory checkpoint
        ↓
/build → code generated with TDD (Red-Green-Refactor per task)
        ↓
/submit → review room (PR)
        ↓
   Team does code review and approves  ← mandatory checkpoint
        ↓
/deploy-to-stage → published to main
```

### Internal engines

The PM commands delegate to internal engines that manage artifact generation and validation. These are not exposed as public commands.

---

## Plugin structure

```
product-flow/
├── docs/
│   ├── onboarding.md             ← PM guide
│   ├── dev-guide.md              ← technical guide
│   ├── constitution.md           ← project principles
│   └── README-kit.md             ← setup instructions
└── plugins/product-flow/
    ├── .claude-plugin/
    │   └── plugin.json           ← manifest: 7 public PM commands
    ├── hooks/
    │   └── session-start.sh      ← runs /status + workflow gates on session start
    └── skills/
        ├── start/                ← PM commands (public)
        ├── continue/             ← state machine: SPEC_CREATED→SPEC_REVIEW→PLAN_PENDING→PLAN_REVIEW→BUILD_READY
        ├── build/
        ├── submit/
        ├── deploy-to-stage/
        ├── status/
        ├── context/
        ├── consolidate-spec/     ← internal commands (not exposed)
        ├── consolidate-plan/
        ├── plan/
        ├── tasks/
        ├── implement/
        ├── checklist/
        ├── check-and-clear/
        ├── speckit.specify/      ← upstream engine from github/spec-kit (do not modify)
        ├── speckit.clarify/
        ├── speckit.plan/
        ├── speckit.tasks/
        ├── speckit.implement/
        ├── speckit.implement.withTDD/  ← our fork: adds ZOMBIES TDD cycle per task
        ├── speckit.taskstoissues/
        ├── speckit.retro/
        └── speckit.checklist/

        └── praxis.*                    ← upstream from acunap/praxis (verbatim, do not modify)
            ├── praxis.complexity-review/   ← called in plan: challenge design against 30 dims
            ├── praxis.bdd-with-approvals/  ← called in implement: write approval fixtures first
            └── praxis.test-desiderata/     ← called in implement: validate test quality
```

---

## Documentation

| Document | Audience | Description |
|---|---|---|
| [`docs/onboarding.md`](docs/onboarding.md) | PMs and designers | Non-technical guide: commands, full workflow, frequently asked questions |
| [`docs/dev-guide.md`](docs/dev-guide.md) | Development team | Kit architecture, installation, what each command does internally |
| [`docs/constitution.md`](docs/constitution.md) | AI Agent + Tech Lead | Project governance principles |
| [`docs/README-kit.md`](docs/README-kit.md) | Development team | Initial setup, plugin structure, onboarding |

---

## Requirements

- Claude Code installed
- `gh` CLI installed and authenticated (`brew install gh && gh auth login`)
- `jq` installed (`brew install jq`)
- Repo access with push permissions

---

## Attributions

- **SpecKit** — spec-driven development engine, upstream at [github/spec-kit](https://github.com/github/spec-kit)
- **Praxis** — engineering skills by [Antonio Acuña](https://github.com/acunap/praxis)
- **Test Desiderata** — Kent Beck framework
- **ZOMBIES** — TDD test ordering heuristic by James Grenning
- **Retro SpecKit + more ideas** - skills by [Alex Fernández](https://github.com/alexfdz)
