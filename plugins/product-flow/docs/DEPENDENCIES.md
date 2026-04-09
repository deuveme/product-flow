# Skill Dependency Graph

This document maps which skills call which other skills, the required preconditions for each, and known architectural limitations.

---

## PM Command → Sub-skill Map

```
start
  ├─ praxis.collaborative-design   (if feature description is vague)
  ├─ speckit.specify
  ├─ pr-comments write             (for technical decisions)
  └─ speckit.retro

continue
  ├─ pr-comments read-answers          (inbox: apply pending answers)
  ├─ pr-comments mark-processed        (inbox: record applied answers + react 👍)
  ├─ pr-comments new-comments          (inbox: detect new user comments)
  ├─ pr-comments mark-comments-processed (inbox: react 👍 + record processed IDs)
  ├─ pr-comments write                 (inbox: record decisions from new comments)
  ├─ [SPEC_REVIEW]  → consolidate-spec → (then auto-proceeds to PLAN_PENDING)
  ├─ [PLAN_PENDING] → plan
  └─ [PLAN_REVIEW]  → consolidate-plan → (then auto-proceeds to READY_TO_BE_BUILT)

build
  ├─ pr-comments read-answers          (inbox: apply pending answers)
  ├─ pr-comments mark-processed        (inbox: record applied answers + react 👍)
  ├─ pr-comments new-comments          (inbox: detect new user comments)
  ├─ pr-comments mark-comments-processed (inbox: react 👍 + record processed IDs)
  ├─ pr-comments write                 (inbox: record decisions from new comments)
  ├─ pr-comments pending               (pre-implement gate: resolve UNANSWERED before code)
  ├─ tasks            (if tasks not yet generated)
  ├─ checklist        (if checklists not yet generated)
  ├─ implement        (if code not yet generated)
  └─ speckit.verify-tasks  (re-entry shortcut only)

submit
  ├─ pr-comments read-answers          (inbox: apply pending answers)
  ├─ pr-comments mark-processed        (inbox: record applied answers + react 👍)
  ├─ pr-comments new-comments          (inbox: detect new user comments)
  ├─ pr-comments mark-comments-processed (inbox: react 👍 + record processed IDs)
  ├─ pr-comments write                 (inbox: record decisions from new comments)
  ├─ speckit.verify
  └─ speckit.reconcile  (optional, if user chooses option B)

deploy-to-stage
  (no sub-skill calls — direct git/gh operations)

status
  └─ pr-comments pending  (implicitly, via gh pr list)
  └─ context              (if session has significant context)
```

---

## Orchestrator → Engine Map

```
plan
  ├─ pr-comments read-answers      (apply pending user answers before planning)
  ├─ pr-comments mark-processed    (record applied answers + react on GitHub)
  ├─ praxis.event-modeling         (if event-driven signals detected)
  ├─ speckit.plan
  ├─ praxis.complexity-review
  ├─ praxis.backend-architecture   (if backend work detected)
  ├─ praxis.frontend-architecture  (if frontend work detected)
  ├─ pr-comments write             (for technical decisions)
  └─ speckit.retro

tasks
  ├─ pr-comments read-answers      (apply pending user answers before generating tasks)
  ├─ pr-comments mark-processed    (record applied answers + react on GitHub)
  └─ speckit.tasks

implement
  ├─ pr-comments read-answers
  ├─ pr-comments mark-processed    (record applied answers + react on GitHub)
  ├─ pr-comments pending
  ├─ praxis.bdd-with-approvals     (TypeScript/JavaScript only)
  ├─ speckit.implement.withTDD
  │     └─ praxis.code-simplifier  (called per task within withTDD)
  ├─ praxis.test-desiderata
  ├─ speckit.retro
  └─ speckit.verify-tasks          (optional, user choice)

checklist
  └─ speckit.checklist

consolidate-spec
  ├─ pr-comments pending
  ├─ pr-comments read-answers
  ├─ pr-comments mark-processed    (record applied answers + react on GitHub)
  ├─ speckit.clarify               (if [NEEDS CLARIFICATION] markers remain)
  ├─ pr-comments write
  ├─ pr-comments resolve
  └─ speckit.retro

consolidate-plan
  ├─ pr-comments pending
  ├─ pr-comments read-answers
  ├─ pr-comments mark-processed    (record applied answers + react on GitHub)
  ├─ pr-comments write
  ├─ pr-comments resolve
  └─ speckit.retro

pr-comments
  (leaf node — calls no other skills)
```

---

## Precondition Table

| Skill | Required preconditions |
|-------|----------------------|
| `start` | Clean working tree; on main/master |
| `continue` | On a feature branch; PR exists |
| `build` | PR exists; `plan_generated` in status.json; feature directory exists |
| `submit` | On a feature branch; PR exists; `code_verified` in status.json |
| `deploy-to-stage` | `in_review` in status.json; PR approved by team |
| `plan` | `spec_created` in status.json; no pending UNANSWERED comments |
| `tasks` | `spec_created` + `plan_generated` in status.json; `plan.md` and `spec.md` exist in FEATURE_DIR |
| `implement` | `tasks_generated` in status.json OR `tasks.md` exists in FEATURE_DIR; no UNANSWERED comments |
| `checklist` | `spec.md` exists in FEATURE_DIR |
| `consolidate-spec` | `spec_created` in status.json; pending comments exist |
| `consolidate-plan` | `plan_generated` in status.json; pending comments exist |
| `speckit.specify` | On a feature branch, or on main with clean working tree |
| `speckit.plan` | `spec.md` exists in FEATURE_DIR |
| `speckit.tasks` | `plan.md` and `spec.md` exist in FEATURE_DIR |
| `speckit.implement.withTDD` | `tasks.md`, `plan.md` exist in FEATURE_DIR |
| `speckit.verify` | `spec.md`, `plan.md`, `tasks.md` exist in FEATURE_DIR |
| `speckit.verify-tasks` | `spec.md`, `plan.md`, `tasks.md` exist; at least one `[X]` task |
| `speckit.reconcile` | `spec.md`, `plan.md` exist in FEATURE_DIR; non-empty gap report |
| `speckit.checklist` | `spec.md` exists in FEATURE_DIR |
| `speckit.retro` | Active feature branch |
| `praxis.*` | Input artifacts passed by caller |
| `pr-comments` | Active PR (`gh pr view` succeeds) |

---

## Known Limitations

### Boot-time skill path validation (issue #24)
`plugin.json` lists skill paths as relative strings (`./skills/<name>`). There is no validation at plugin load time that these directories actually exist. If a skill directory is accidentally deleted or renamed, the skill will silently become unavailable. **Mitigation**: run `/product-flow:status` after any manual changes to the plugin directory to surface missing skills early.

### Concurrent PR comment IDs (issue #21)
The `pr-comments write` operation determines the next question number by querying the current max `id:q<N>` value in the PR and adding 1. If two Claude sessions write comments to the same PR concurrently, both may compute the same number and create duplicate question IDs. **Mitigation**: avoid running multiple sessions against the same PR simultaneously.

---

## Upstream Sources

| Skill prefix | Upstream | Fork rules |
|---|---|---|
| `speckit.*` | [github/spec-kit](https://github.com/github/spec-kit) | Do NOT modify upstream skills. New forks use `withX` suffix (e.g., `speckit.implement.withTDD`). |
| `praxis.*` | [acunap/praxis](https://github.com/acunap/praxis) | Same rule — do not modify; fork with `withX` suffix if needed. |
| PM commands & orchestrators | This repo | Freely modifiable following the constitution. |
