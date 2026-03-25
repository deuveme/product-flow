# product-flow

Claude Code plugin for spec-driven development. Enables PMs, designers, and developers to collaborate in a structured process: spec → plan → code → deploy, with Claude assisting at every step.

---

## Quick start

```bash
# In your Claude Code session:
/plugin marketplace add deuveme/product-flow
/plugin install product-flow@product-flow
```

**Commands:**
- `/start` — start a new feature
- `/continue` — advance to next step (repeatable)
- `/build` — generate code (when plan is ready)
- `/submit` — share code for review
- `/deploy-to-stage` — publish to staging
- `/status` — see where you are
- `/context` — see memory usage

**Workflow:**
```
/start → /continue (repeat) → /build → /submit → /deploy-to-stage
           (spec review)     (TDD)    (review)  (merge)
```

---

## Documentation

| Document | For | Content |
|---|---|---|
| [`docs/onboarding.md`](docs/onboarding.md) | PMs & designers | How to use the commands, full workflow, FAQs |
| [`docs/guide.md`](docs/guide.md) | Dev team | Architecture, setup, how to modify skills |
| [`docs/constitution.md`](docs/constitution.md) | Tech lead & AI | Project governance, standards, scope discipline |

---

## Features

- **Spec-driven**: No code without a spec. Specs are reviewed and refined before planning.
- **Quality gates**: Specs, plans, and code are validated before moving to the next step.
- **TDD by default**: Code is generated using Red-Green-Refactor cycles with ZOMBIES test ordering.
- **Design challenge**: Plans are challenged against 30 complexity dimensions to prevent over-engineering.
- **Approval testing**: Specs are written as executable fixtures before implementation.
- **Test quality**: Tests are validated against Kent Beck's 12 Test Desiderata properties.
- **Team collaboration**: Team feedback integrates back into specs and plans via PR comments.

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
