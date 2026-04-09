# Project constitution

> This document defines the governance principles for all development of the product-flow plugin.
> It is the first document the AI agent reads before any planning or implementation.
> It takes precedence over any instruction in a spec or plan.

---

## 1. Core philosophy

- **Simplicity over cleverness.** The simplest solution that meets the requirements is always preferred.
- **Explicit over implicit.** Code must be readable by someone who doesn't know the repository.
- **Spec-first.** No code is written without a corresponding spec. No PR exists without a link to its originating spec.
- **Small and reversible.** Prefer small, focused changes over large changes. If a decision is hard to revert, escalate to the tech lead before proceeding.

---

## 2. What the AI agent can decide autonomously

The agent can make the following decisions without explicit instruction:

- Names of variables, functions and files (following the conventions in section 5)
- Internal folder structure within already established modules
- Writing and structuring tests
- Refactoring within the scope of the current task (without scope creep)
- Choosing between equivalent implementation approaches when no preference has been declared

---

## 3. What requires Tech Lead approval before implementing

The agent must **stop and escalate** — never decide unilaterally — on:

- Adding a new dependency or library
- Changing the plugin manifest (`plugin.json`)
- Modifying any hook (`git-sync.sh`, `intent-router.sh`, `state-notifier.sh`, `permission-request.sh`, `security-guard.sh`, `workflow-guard.sh`)
- Adding or removing skills from the plugin
- Changing the command structure that affects the PM workflow
- Any change that affects more than one skill/module simultaneously
- Deleting existing code that is not directly replaced by the current task

If there is uncertainty, the agent must ask before assuming.

---

## 4. Code quality standards

### General
- Each function does one thing. If it needs a comment to explain what it does, it must be split or renamed.
- No dead code. No commented-out blocks. No `TODO` in production.
- No premature abstraction. Only abstract when there are at least two concrete cases.
- No code added "for the future". Implement only what the current spec requires.

### Error handling
- All errors must be handled explicitly. No silent catches.
- Error messages must be actionable — describe what failed and why.
- Never expose internal error details (stack traces) to the end user.

### Security
- No hardcoded credentials, tokens or secrets — never. Use environment variables.
- No personally identifiable information (PII) in logs.

---

## 5. Naming and style conventions

- **Files:** `kebab-case`
- **Skill directories:** `kebab-case` (PM commands) or `domain.skill` (SpecKit and Praxis)
- **Variables/functions:** `camelCase` (bash scripts: `snake_case`)
- **Constants:** `SCREAMING_SNAKE_CASE`
- Avoid abbreviations except universally known ones (`id`, `url`, `pr`)
- User-facing messages always in English
- Internal skill variables in English

---

## 6. Testing standards

- Tests are written alongside the implementation, not after.
- Each new skill must have its expected behaviour documented in its `SKILL.md`.
- Integration tests verify the complete workflow: from the PM command to the generated artifact.
- A PR with untested business logic will not be merged.

---

## 7. Pull Request standards

### Size
- Maximum **10 changed files** per PR. If a task requires more, split it.
- A PR must represent a logical unit of work, traceable to a spec.

### Description (required)
Every PR must include:

```
## What
[One paragraph describing what this PR does]

## Why
[Link to the spec or issue that originates this work]

## What it does NOT do
[Explicit scope limits — what was intentionally left out]

## How to test
[Steps to verify the change works]
```

---

## 8. Scope discipline

- The agent implements **only what the current spec requires.** Noticing something broken or improvable outside the current scope is welcome — but it goes to a new issue, not the current PR.
- If implementing a task reveals that the spec is ambiguous or incomplete, stop and clarify with the PM before continuing.
- Gold-plating (adding features or improvements not included in the spec) is not allowed.

---

## 9. Documentation

- Public skills (PM commands) must have a clear description in their `SKILL.md` frontmatter.
- Non-obvious architecture decisions must be documented in `docs/`.
- Non-structural changes (new skills, updated workflows) must be reflected in `docs/guide.md`. Installation changes must be reflected in `docs/onboarding.md`.

---

## 10. Session context management

The agent proactively checks context usage at the end of each workflow command.

Action thresholds:

- **< 50% 🟢** → continue without mentioning anything
- **50–79% 🟡** → continue without mentioning anything; warn at the end of the step
- **80–89% 🟠** → add warning at the end: "Open a new session before the next command"
- **≥ 90% 🔴** → interrupt before executing any action and instruct the user to run `/clear`

The user can check the status at any time with `/product-flow:context`.

---

## 11. Workflow with PMs

This project uses a spec-driven workflow where PM commands orchestrate internal engines. Commands have no logic of their own regarding specs, plans or code — they delegate to the internal skills and only add PR management and approval gates.

### Workflow commands (PM)

| Command | Internal delegates | Own responsibility |
|---|---|---|
| `/product-flow:start` | Internal spec engine | Be on `main` |
| `/product-flow:continue` | Internal clarify / plan engine | Spec created |
| `/product-flow:build` | Internal tasks + implement engine | Plan approved in PR |
| `/product-flow:submit` | — | Code generated |
| `/product-flow:deploy-to-stage` | — | PR approved |

### `status.json` as source of truth

The workflow state lives in `specs/<branch>/status.json`. Commands read this file to determine whether they can execute. The PR body checkboxes are updated in parallel for human visibility only — never use them as logic gates.

Fields written by each skill:

| Field | Written by |
|---|---|
| `spec_created` | `/product-flow:start`, `speckit.split` |
| `plan_generated` | `/product-flow:plan` |
| `tasks_generated` | `/product-flow:tasks` |
| `checklist_done` | `/product-flow:checklist` (step 4, after artifact commit) and `/product-flow:build` (step 5, after resolving critical issues) |
| `code_written` | `/product-flow:implement` |
| `code_verified` | `/product-flow:build` (after verify-tasks) |
| `in_review` | `/product-flow:submit` |
| `processed_answers` | `pr-comments mark-processed` — question numbers already applied (prevents re-processing) |
| `processed_comment_ids` | `pr-comments mark-comments-processed` — IDs of general user comments already evaluated |

---

## 12. Domain design principles

When modeling a domain, use business language throughout — no infrastructure or technical terms in names or events.

**Three slice types for domain behavior:**

- **STATE_CHANGE** — user initiates a write: Screen → Command → Event (including error paths). One command per slice.
- **STATE_VIEW** — system displays data: Events → Read Model → Screen. Never omit STATE_VIEW slices for queries.
- **AUTOMATION** — system reacts: Event → Processor → Command → Event (no user involvement).

**Design order:** understand aggregates → sketch high-level model → define slice details with fields and business rules → convert to executable fixtures.

Anti-patterns: circular dependencies between elements, combining multiple commands in one STATE_CHANGE, writing validation specs instead of capturing business rules.

---

## 13. API evolution

When making breaking changes, use the **expand-contract** pattern to maintain zero downtime.

**Three phases:**

1. **Expand** — add new implementation alongside the old; write to both paths simultaneously (dual-write).
2. **Migrate** — gradually move readers/consumers to the new path (feature flags, canary); keep dual-write active as safety.
3. **Contract** — stop writing to the old path only after confirming ZERO usage (verified via logs/monitoring over an extended period); then remove legacy code.

**Applies to:** database column renames, data type conversions, API field changes, service replacements, library migrations.

**Never:** big bang migrations, premature removal of legacy paths, skipping dual-write, moving to contract phase without monitoring evidence.

---

*Last updated: 2026-04-07*
*Owner: Tech Lead*
*Version: 1.7.2*
