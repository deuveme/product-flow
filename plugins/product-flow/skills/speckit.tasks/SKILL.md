---
description: Generates a dependency-ordered tasks.md from design artifacts.
user-invocable: false
context: fork
model: sonnet
effort: medium
handoffs:
  - label: Build Feature
    agent: build
    prompt: Build the feature
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. **Setup**: Resolve feature paths and validate prerequisites:

   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
   CURRENT_BRANCH="${SPECIFY_FEATURE:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
   ```

   If `CURRENT_BRANCH` does not match `^[0-9]{3}-`: ERROR "Not on a feature branch. Run /product-flow:start first." and stop.

   Derive paths (all absolute):
   - `FEATURE_DIR` = `$REPO_ROOT/specs/$CURRENT_BRANCH`

   Validate:
   - If `FEATURE_DIR` does not exist: ERROR "Feature directory not found. Run /product-flow:start first." and stop.
   - If `$FEATURE_DIR/plan.md` does not exist: ERROR "plan.md not found. Run /product-flow:continue first." and stop.

   Build `AVAILABLE_DOCS` list (optional files present in `FEATURE_DIR`):
   - `research.md` if it exists
   - `data-model.md` if it exists
   - `contracts/` if the directory exists and is non-empty
   - `quickstart.md` if it exists

2. **Validate existing task format** (if `tasks.md` already exists): Before generating, scan for any existing task lines. If they use a different ID format than `T###` (e.g., `T-001`, `task-1`, `1.1`), warn the user:

   ```
   ⚠️  Existing tasks.md uses a non-standard ID format (<detected format>).
   New tasks will use the standard T### format (T001, T002…).
   This may cause mixed formats in the file. Proceed? (yes / no)
   ```

   Use the `AskUserQuestion` tool to ask this. If the user says "no", stop. If "yes" or if tasks.md does not exist, continue.

3. **Load design documents**: Read from FEATURE_DIR:
   - **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
   - **Optional**: data-model.md (entities), contracts/ (interface contracts), research.md (decisions), quickstart.md (test scenarios)
   - Note: Not all projects have all documents. Generate tasks based on what's available.

4. **Execute task generation workflow**:
   - Load plan.md and extract tech stack, libraries, project structure
   - Load spec.md and extract user stories with their priorities (P1, P2, P3, etc.)
   - If data-model.md exists: Extract entities and map to user stories
   - If contracts/ exists: Map interface contracts to user stories
   - If research.md exists: Extract decisions for setup tasks
   - Generate tasks organized by user story (see Task Generation Rules below)
   - Generate dependency graph showing user story completion order
   - Create parallel execution examples per user story
   - Validate task completeness (each user story has all needed tasks, independently testable)

4b. **Detect observability signals**: Before generating tasks, scan the loaded documents for signals that require explicit observability tasks. For each signal found, record it — it will produce one or more tasks in the Polish phase.

   | Signal | Where to detect | Tasks to generate |
   |--------|----------------|-------------------|
   | External service call (payment, email, SMS, third-party API) | plan.md integrations, research.md, contracts/ | Structured logging on call + response (success and failure paths) |
   | Auth / authentication flow | spec.md user stories, contracts/ | Log auth failures with context (no credentials in log) |
   | Critical data mutation (CREATE/UPDATE/DELETE on a core entity) | data-model.md state transitions, spec.md | Log mutation entry + outcome with entity ID (no PII in payload) |
   | Background job or AUTOMATION slice | spec.md, event-model.md | Log job start, completion, and failure with correlation ID |
   | New service entry point (new Lambda, new HTTP handler) | plan.md file structure, contracts/ | Health check endpoint or readiness signal |

   If no signals are detected: skip observability tasks entirely — do not generate them.

5. **Generate tasks.md**: Use `$REPO_ROOT/.specify/templates/tasks-template.md` as structure if it exists (otherwise use the Task Generation Rules below as the canonical structure), fill with:
   - Correct feature name from plan.md
   - Phase 1: Setup tasks (project initialization)
   - Phase 2: Foundational tasks (blocking prerequisites for all user stories)
   - Phase 3+: One phase per user story (in priority order from spec.md)
   - Each phase includes: story goal, independent test criteria, tests (if requested), implementation tasks
   - Final Phase: Polish & cross-cutting concerns
   - All tasks must follow the strict checklist format (see Task Generation Rules below)
   - Clear file paths for each task
   - Dependencies section showing story completion order
   - Parallel execution examples per story
   - Implementation strategy section (MVP first, incremental delivery)

6. **Report**: Output a brief summary:
   - Total task count
   - Number of phases
   - Format validation: Confirm ALL tasks follow the checklist format (checkbox, ID, labels, file paths)

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story to enable independent implementation and testing.

**Tests are MANDATORY**: Always generate test tasks for every user story. Implementation follows `speckit.implement.withTDD` — tests must be generated as part of each story phase.

**🚫 NEVER generate review, validation, or approval tasks** (e.g. "Review implementation", "Validate with PM", "User acceptance review"). The workflow already has explicit review steps (checklist, verify-tasks, submit). Adding them as tasks creates redundancy and noise.

### Checklist Format (REQUIRED)

Every task MUST strictly follow this format:

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

**Format Components**:

1. **Checkbox**: ALWAYS start with `- [ ]` (markdown checkbox)
2. **Task ID**: Sequential number (T001, T002, T003...) in execution order
3. **[P] marker**: Include ONLY if task is parallelizable (different files, no dependencies on incomplete tasks)
4. **[Story] label**: REQUIRED for user story phase tasks only
   - Format: [US1], [US2], [US3], etc. (maps to user stories from spec.md)
   - Setup phase: NO story label
   - Foundational phase: NO story label
   - User Story phases: MUST have story label
   - Polish phase: NO story label
5. **Description**: Clear action with exact file path

**Examples**:

- ✅ CORRECT: `- [ ] T001 Create project structure per implementation plan`
- ✅ CORRECT: `- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py`
- ✅ CORRECT: `- [ ] T012 [P] [US1] Create User model in src/models/user.py`
- ✅ CORRECT: `- [ ] T014 [US1] Implement UserService in src/services/user_service.py`
- ❌ WRONG: `- [ ] Create User model` (missing ID and Story label)
- ❌ WRONG: `T001 [US1] Create model` (missing checkbox)
- ❌ WRONG: `- [ ] [US1] Create User model` (missing Task ID)
- ❌ WRONG: `- [ ] T001 [US1] Create model` (missing file path)

### Task Organization

1. **From User Stories (spec.md)** - PRIMARY ORGANIZATION:
   - Each user story (P1, P2, P3...) gets its own phase
   - Map all related components to their story:
     - Models needed for that story
     - Services needed for that story
     - Interfaces/UI needed for that story
     - Tests specific to that story (always required)
   - Mark story dependencies (most stories should be independent)

2. **From Contracts**:
   - Map each interface contract → to the user story it serves
   - Each interface contract → contract test task [P] before implementation in that story's phase

3. **From Data Model**:
   - Map each entity to the user story(ies) that need it
   - If entity serves multiple stories: Put in earliest story or Setup phase
   - Relationships → service layer tasks in appropriate story phase

4. **From Setup/Infrastructure**:
   - Shared infrastructure → Setup phase (Phase 1)
   - Foundational/blocking tasks → Foundational phase (Phase 2)
   - Story-specific setup → within that story's phase

### Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Tests → Models → Services → Endpoints → Integration
  - Each phase should be a complete, independently testable increment
- **Final Phase**: Polish & Cross-Cutting Concerns
  - If observability signals were detected in step 4b: generate one task per signal, using the exact file paths from plan.md where the logging should be added. Follow the `.agents/rules/base.md` logging conventions if present; otherwise default to structured JSON logs.
  - Observability task rules:
    - One task per signal — do not group unrelated signals into a single task
    - Always reference the exact file path (use case, handler, or service where the log goes)
    - Task description must state: what to log, where, and what NOT to log (e.g. no PII, no credentials)
    - Example: `- [ ] T047 Add structured logging to PaymentUseCase entry and exit in src/components/billing/application/processPayment/processPaymentUseCase.ts — log amount and result status; never log card number or CVV`
