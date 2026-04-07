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
  ├─ pr-comments pending
  ├─ [SPEC_REVIEW]  → consolidate-spec → (then auto-proceeds to PLAN_PENDING)
  ├─ [PLAN_PENDING] → plan
  └─ [PLAN_REVIEW]  → consolidate-plan → (then auto-proceeds to BUILD_READY)

build
  ├─ tasks            (if tasks not yet generated)
  ├─ checklist        (if checklists not yet generated)
  ├─ implement        (if code not yet generated)
  └─ speckit.verify-tasks  (re-entry shortcut only)

submit
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
  ├─ praxis.event-modeling         (if event-driven signals detected)
  ├─ speckit.plan
  ├─ praxis.complexity-review
  ├─ praxis.backend-architecture   (if backend work detected)
  ├─ praxis.frontend-architecture  (if frontend work detected)
  ├─ pr-comments write             (for technical decisions)
  └─ speckit.retro

tasks
  └─ speckit.tasks

implement
  ├─ pr-comments read-answers
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
  ├─ speckit.clarify               (if [NEEDS CLARIFICATION] markers remain)
  ├─ pr-comments write
  ├─ pr-comments resolve
  └─ speckit.retro

consolidate-plan
  ├─ pr-comments pending
  ├─ pr-comments read-answers
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
| `build` | PR exists; `- [x] Plan generated` marked; feature directory exists |
| `submit` | On a feature branch; PR exists; `- [x] Code generated` marked |
| `deploy-to-stage` | PR approved by team |
| `plan` | `- [x] Spec created` marked; no pending UNANSWERED comments |
| `tasks` | `plan.md` and `spec.md` exist in FEATURE_DIR |
| `implement` | `- [x] Tasks generated` marked; no UNANSWERED comments |
| `checklist` | `spec.md` exists in FEATURE_DIR |
| `consolidate-spec` | `- [x] Spec created` marked; pending comments exist |
| `consolidate-plan` | `- [x] Plan generated` marked; pending comments exist |
| `speckit.specify` | `.specify/scripts/bash/create-new-feature.sh` executable |
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
