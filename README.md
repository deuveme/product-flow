# product-flow

Claude Code plugin for spec-driven development. Enables PMs, designers, and developers to collaborate in a structured process: spec → plan → code → deploy, with Claude assisting at every step.

---

## Quick start

**1. Install the plugin**

Open your terminal, type `claude` and press Enter. Once it loads, run:

```
/plugin marketplace add git@github.com:deuveme/product-flow.git
```

Then, in the same session, run:

```
/plugin install product-flow@product-flow
```

Close the terminal. If you had Claude Code Desktop open, close it and reopen it.

You are ready to use the plugin commands!

**2. Update the plugin**

Open your terminal, type `claude` and press Enter. Once it loads, run:

```
/plugin update product-flow@product-flow
```

Close the terminal and reopen Claude Code.

**Commands:**
- `/product-flow:start` — start a new feature
- `/product-flow:continue` — advance to next step (repeatable)
- `/product-flow:build` — generate code (when plan is ready)
- `/product-flow:submit` — share code for review
- `/product-flow:deploy-to-stage` — publish to staging
- `/product-flow:status` — see where you are
- `/product-flow:context` — see memory usage

**Workflow:**
```
/product-flow:start → /product-flow:continue (repeat) → /product-flow:build → /product-flow:submit → /product-flow:deploy-to-stage
  (DRAFT PR)            (spec → plan, team feedback)       (code, TDD)           (exit DRAFT, review)    (approved → merge)
```

---

## Documentation

| Document | For | Content |
|---|---|---|
| [`docs/onboarding.md`](plugins/product-flow/docs/onboarding.md) | PMs & designers | How to use the commands, full workflow, FAQs |
| [`docs/guide.md`](plugins/product-flow/docs/guide.md) | Dev team | Architecture, setup, how to modify skills |
| [`docs/constitution.md`](plugins/product-flow/docs/constitution.md) | Tech lead & AI | Project governance, standards, scope discipline |

---

## Features

- **Spec-driven**: No code without a spec. Specs are reviewed and refined before planning.
- **Quality gates**: Specs, plans, and code are validated before moving to the next step.
- **TDD by default**: Code is generated using Red-Green-Refactor cycles with ZOMBIES test ordering.
- **Design challenge**: Plans are challenged against 30 complexity dimensions to prevent over-engineering.
- **Approval testing**: Specs are written as executable fixtures before implementation.
- **Test quality**: Tests are validated against Kent Beck's 12 Test Desiderata properties.
- **Team collaboration**: Team feedback integrates back into specs and plans via PR comments.
- **Visual design exploration**: Collaborative design skill for exploring ambiguous features through scenarios and vertical slicing before spec creation.
- **Event modeling**: Decompose event-driven features into independently testable slices (STATE_CHANGE / STATE_VIEW / AUTOMATION) before planning.
- **Safe migrations**: Expand-contract pattern for breaking changes — rename columns, refactor APIs, or replace services with zero downtime.
- **Implementation verification**: Post-implement quality gate (`speckit.verify`) that validates code against spec, plan, tasks, and constitution before submitting for review.
- **Phantom completion detection**: `speckit.verify-tasks` checks that tasks marked done have real code behind them — not stubs or TODOs — using a 5-layer cascade (file existence, git diff, pattern matching, dead-code detection, semantic assessment).
- **Drift reconciliation**: `speckit.reconcile` surgically updates spec, plan, and tasks when implementation diverges from the original design.
- **Scope splitting**: `speckit.split` analyzes a spec for scope creep using scope, size, and language signals. If a split is warranted, it trims the current spec and creates a new branch with a draft PR for the extracted feature — with vertical-slice validation and expand-contract warnings when features share entities.

---

## Requirements

- Claude Code installed
- `gh` CLI installed and authenticated
- `jq` installed
- Repo access with push permissions
- [SpecKit](https://github.com/github/spec-kit) installed in the project (required by `/product-flow:start` for spec templates and branch creation scripts)
- [GitHub MCP server](https://github.com/github/github-mcp-server) configured (required by `/product-flow:build` to create GitHub issues)

---

## Attributions

- **SpecKit** — spec-driven development engine, upstream at [github/spec-kit](https://github.com/github/spec-kit)
- **Praxis** — engineering skills by [Antonio Acuña](https://github.com/acunap/praxis)
- **Test Desiderata** — Kent Beck framework
- **ZOMBIES** — TDD test ordering heuristic by James Grenning
- **Retro SpecKit + more ideas** - skills by [Alex Fernández](https://github.com/alexfdz)
- **speckit.verify** — adapted from [ismaelJimenez/spec-kit-verify](https://github.com/ismaelJimenez/spec-kit-verify)
- **speckit.verify-tasks** — adapted from [datastone-inc/spec-kit-verify-tasks](https://github.com/datastone-inc/spec-kit-verify-tasks)
- **speckit.reconcile** — adapted from [stn1slv/spec-kit-reconcile](https://github.com/stn1slv/spec-kit-reconcile)
