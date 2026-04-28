# Skill Dependency Graph

This document maps which skills call which other skills, the required preconditions for each, and known architectural limitations.

---

## PM Command → Sub-skill Map

```
start-feature
  ├─ praxis.collaborative-design   (if feature description is vague)
  ├─ speckit.specify
  ├─ pr-comments write             (for technical decisions)
  └─ speckit.retro

start-improvement
  ├─ speckit.specify.improvement   (lean spec, ~1 page + integrated self-validation)
  └─ pr-comments write             (for technical decisions, if any)

continue
  ├─ inbox-sync                              (internal inbox orchestration)
  │
  │  ── Feature flow (flow === "feature" or absent) ──
  ├─ [SPEC_CREATED, SPLIT_PREPLAN_ANALIZED absent, has_comments]      → consolidate-spec → speckit.split (auto-proceed)
  ├─ [SPEC_CREATED, SPLIT_PREPLAN_ANALIZED absent, no comments]       → speckit.split → plan (auto-proceed)
  ├─ [SPEC_CREATED, SPLIT_PREPLAN_ANALIZED, PLAN_GENERATED absent]     → speckit.clarify → plan
  ├─ [PLAN_GENERATED, SPLIT_POSTPLAN_ANALIZED absent, has_comments]   → consolidate-plan → speckit.split (post-plan)
  ├─ [PLAN_GENERATED, SPLIT_POSTPLAN_ANALIZED absent, no comments]    → speckit.split (post-plan)
  ├─ [SPLIT_POSTPLAN_ANALIZED, TASKS_GENERATED absent, has_comments]  → consolidate-plan
  ├─ [SPLIT_POSTPLAN_ANALIZED, TASKS_GENERATED absent, no comments]   → tasks → checklist (auto-proceed)
  ├─ [TASKS_GENERATED, CHECKLIST_DONE absent, has_comments] → consolidate-plan
  ├─ [TASKS_GENERATED, CHECKLIST_DONE absent, no comments]  → checklist
  ├─ [CHECKLIST_DONE, CODE_WRITTEN absent, has_comments]    → consolidate-plan (clears CHECKLIST_DONE)
  ├─ [CHECKLIST_DONE, CODE_WRITTEN absent, no comments]     → ready for /build
  │
  │  ── Improvement flow (flow === "improvement") ──
  ├─ [SPEC_CREATED, PLAN_GENERATED absent, has_comments]    → consolidate-spec
  ├─ [SPEC_CREATED, PLAN_GENERATED absent, no comments]     → speckit.plan.improvement
  ├─ [PLAN_GENERATED, TASKS_GENERATED absent, has_comments] → consolidate-plan
  ├─ [PLAN_GENERATED, TASKS_GENERATED absent, no comments]  → tasks
  ├─ [TASKS_GENERATED, CODE_WRITTEN absent, has_comments]   → consolidate-plan
  └─ [TASKS_GENERATED, CODE_WRITTEN absent, no comments]    → ready for /build  (no checklist phase)

build
  ├─ inbox-sync                        (internal inbox orchestration)
  ├─ pr-comments pending               (pre-implement gate: resolve UNANSWERED before code)
  ├─ implement           (if code not yet generated)
  ├─ speckit.verify-tasks              (mandatory after implement; re-entry shortcut if code already written)
  ├─ speckit.verify                    (verification gate after verify-tasks)
  └─ speckit.reconcile                 (optional, if spec/plan need updating after verify)

submit
  └─ inbox-sync                        (internal inbox orchestration)

fix
  ├─ inbox-sync                        (internal inbox orchestration)
  ├─ pr-comments new-comments          (surface unprocessed review feedback)
  ├─ pr-comments write                 (post confirmed diagnosis summary)
  ├─ speckit.implement.withTDD [IDs]   (filtered mode — fix-tasks only)
  ├─ speckit.verify-tasks [IDs]        (filtered mode — fix-tasks only)
  ├─ speckit.verify                    (full verification gate)
  ├─ speckit.retro                     (gap retrospective)
  └─ context

deploy
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
  ├─ bugmagnet
  ├─ speckit.retro
  └─ speckit.verify-tasks          (mandatory after implement)

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

inbox-sync
  ├─ pr-comments read-answers
  ├─ pr-comments mark-processed
  ├─ pr-comments new-comments
  ├─ pr-comments mark-comments-processed
  └─ pr-comments write
```

---

## Precondition Table

| Skill | Required preconditions |
|-------|----------------------|
| `start-feature` | Clean working tree; on main/master (or resumption mode: on existing feature branch) |
| `start-improvement` | Clean working tree; on main/master |
| `continue` | On a feature/improvement branch; PR exists |
| `build` | PR exists; `TASKS_GENERATED` in status.json; if `flow !== "improvement"`: also `CHECKLIST_DONE`; feature directory exists |
| `submit` | On a feature/improvement branch; PR exists; `CODE_VERIFIED` in status.json |
| `fix` | On a feature/improvement branch; PR exists; `CODE_VERIFIED` or `IN_REVIEW` in status.json |
| `deploy` | `IN_REVIEW` in status.json; PR approved by team |
| `plan` | `SPEC_CREATED` in status.json; no pending UNANSWERED comments |
| `tasks` | `SPEC_CREATED` + `PLAN_GENERATED` in status.json; `plan.md` and `spec.md` exist in FEATURE_DIR |
| `implement` | `TASKS_GENERATED` in status.json OR `tasks.md` exists in FEATURE_DIR; no UNANSWERED comments |
| `checklist` | `spec.md` exists in FEATURE_DIR |
| `consolidate-spec` | `SPEC_CREATED` in status.json; pending comments exist |
| `consolidate-plan` | `PLAN_GENERATED` in status.json; pending comments exist |
| `speckit.specify` | On a feature branch, or on main with clean working tree |
| `speckit.specify.improvement` | On an improvement branch; `improvement-context.md` exists in FEATURE_DIR |
| `speckit.plan` | `spec.md` exists in FEATURE_DIR |
| `speckit.plan.improvement` | `spec.md` + `improvement-context.md` exist in FEATURE_DIR |
| `speckit.tasks` | `plan.md` and `spec.md` exist in FEATURE_DIR |
| `speckit.implement.withTDD` | `tasks.md`, `plan.md` exist in FEATURE_DIR |
| `speckit.verify` | `spec.md`, `plan.md`, `tasks.md` exist in FEATURE_DIR |
| `speckit.verify-tasks` | `spec.md`, `plan.md`, `tasks.md` exist; at least one `[X]` task |
| `speckit.reconcile` | `spec.md`, `plan.md` exist in FEATURE_DIR; non-empty gap report |
| `speckit.checklist` | `spec.md` exists in FEATURE_DIR |
| `speckit.retro` | Active feature branch |
| `praxis.*` | Input artifacts passed by caller |
| `inbox-sync` | Active PR (`gh pr view` succeeds) |
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
| `bugmagnet` | [gojko/bugmagnet](https://github.com/gojko/bugmagnet) | Adapted as an internal skill; freely modifiable. |
| PM commands & orchestrators | This repo | Freely modifiable following the constitution. |
