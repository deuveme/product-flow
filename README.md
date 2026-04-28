# product-flow

Claude Code plugin for spec-driven development. Enables PMs, designers, and developers to collaborate in a structured process: spec → plan → code → deploy, with Claude assisting at every step.

---

## Quick start

**1. Install the plugin**

Open your terminal, type `claude` and press Enter. Once it loads, run:

```
/plugin marketplace add https://github.com/deuveme/product-flow.git
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
- `/product-flow:start-feature` — start a new feature (full flow)
- `/product-flow:start-improvement` — improve something already live (lighter flow)
- `/product-flow:continue` — advance to next step (repeatable)
- `/product-flow:build` — generate code (when plan is ready)
- `/product-flow:submit` — share code for review
- `/product-flow:fix` — fix issues found during testing or code review (TDD guaranteed)
- `/product-flow:deploy` — publish to staging
- `/product-flow:status` — see where you are
- `/product-flow:context` — see memory usage

**Workflows:**
```
New feature:
/product-flow:start-feature → /product-flow:continue (repeat) → /product-flow:build → /product-flow:submit → /product-flow:deploy
  (DRAFT PR)                    (spec → plan, team feedback)       (code, TDD)           (exit DRAFT, review)    (approved → merge)
                                                                        ↕ issues found?
                                                                 /product-flow:fix
                                                                   (TDD fix cycle)

Small improvement to something already live:
/product-flow:start-improvement → /product-flow:continue (repeat) → /product-flow:build → /product-flow:submit → /product-flow:deploy
  (DRAFT PR, lean spec+plan)        (spec → plan, team feedback)       (code, TDD)           (exit DRAFT, review)    (approved → merge)
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
- **ADR proposals**: At submit time, the agent analyzes `research.md` and `decisions.md` and proposes which decisions are worth promoting to project-level Architecture Decision Records. Proposals appear in the PR body under `## For Developers` so the team can review them alongside the code.
- **ADR consolidation**: At deploy time, if the PR has proposed ADRs the agent asks the user whether to write them. If confirmed, each ADR is written to `docs/adr/NNNN-<slug>.md` in standard format (Context / Decision / Consequences) and committed to main alongside the merge.
- **Scope splitting**: `speckit.split` runs at two mandatory points in every workflow — pre-plan (after spec creation) and post-plan (after plan generation). Default posture is to split: the feature must justify staying together using a scored debate. When a split is confirmed, it trims the current spec, validates both resulting features as independent vertical slices, creates a new branch with a draft PR for the extracted feature, and records the full analysis and debate in `split-analysis.md`. Expand-contract warnings are surfaced when features share entities.

---

## Requirements

- Claude Code installed
- `gh` CLI installed and authenticated
- `jq` installed
- Repo access with push permissions
- `.specify/templates/` in the project (optional — provides spec, plan and tasks templates; if absent, skills use built-in defaults)
- `.specify/memory/constitution.md` in the project (optional — project-specific architecture principles read by verification skills)
- [GitHub MCP server](https://github.com/github/github-mcp-server) configured (required by `/product-flow:build` to interact with GitHub)

---

## Attributions

- **SpecKit** — spec-driven development engine, upstream at [github/spec-kit](https://github.com/github/spec-kit)
- **Praxis** — engineering skills by [Antonio Acuña](https://github.com/acunap/praxis)
- **Bugmagnet** — exploratory testing heuristics by [Gojko Adzic](https://github.com/gojko/bugmagnet)
- **Test Desiderata** — Kent Beck framework
- **ZOMBIES** — TDD test ordering heuristic by James Grenning
- **Retro SpecKit + more ideas** - skills by [Alex Fernández](https://github.com/alexfdz)
- **speckit.verify** — adapted from [ismaelJimenez/spec-kit-verify](https://github.com/ismaelJimenez/spec-kit-verify)
- **speckit.verify-tasks** — adapted from [datastone-inc/spec-kit-verify-tasks](https://github.com/datastone-inc/spec-kit-verify-tasks)
- **speckit.reconcile** — adapted from [stn1slv/spec-kit-reconcile](https://github.com/stn1slv/spec-kit-reconcile)
