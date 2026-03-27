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

---

## Requirements

- Claude Code installed
- `gh` CLI installed and authenticated
- `jq` installed
- Repo access with push permissions

---

## Attributions

- **SpecKit** — spec-driven development engine, upstream at [github/spec-kit](https://github.com/github/spec-kit)
- **Praxis** — engineering skills by [Antonio Acuña](https://github.com/acunap/praxis)
- **Test Desiderata** — Kent Beck framework
- **ZOMBIES** — TDD test ordering heuristic by James Grenning
- **Retro SpecKit + more ideas** - skills by [Alex Fernández](https://github.com/alexfdz)
