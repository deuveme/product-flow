---
description: "Implements tasks from tasks.md using strict TDD with ZOMBIES ordering."
user-invocable: false
context: fork
model: sonnet
effort: high
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

   Derive `FEATURE_DIR` = `$REPO_ROOT/specs/$CURRENT_BRANCH`.

   Validate:
   - If `$FEATURE_DIR/plan.md` does not exist: ERROR "plan.md not found. Run /product-flow:plan first." and stop.
   - If `$FEATURE_DIR/tasks.md` does not exist: ERROR "tasks.md not found. Run /product-flow:build first." and stop.

   Build `AVAILABLE_DOCS` list (optional files present in `FEATURE_DIR`):
   - `gathered-context.md` if it exists — load it first; contains visual assets, external docs, and decisions from kick-off
   - `research.md` if it exists
   - `data-model.md` if it exists
   - `contracts/` if the directory exists and is non-empty
   - `quickstart.md` if it exists
   - `tasks.md` (always included)
   - `images/` if it exists and is non-empty — visual assets (wireframes, mockups) available as reference during implementation
   - `docs/` if it exists and is non-empty — documents (PDFs, API specs, requirements) available as reference

   ```bash
   cat $FEATURE_DIR/gathered-context.md 2>/dev/null
   ls $FEATURE_DIR/images/ 2>/dev/null
   cat $FEATURE_DIR/images/sources.md 2>/dev/null
   ls $FEATURE_DIR/docs/ 2>/dev/null
   cat $FEATURE_DIR/docs/sources.md 2>/dev/null
   ```

2. **Check checklists status** (if FEATURE_DIR/checklists/ exists):
   - Scan all checklist files in the checklists/ directory
   - For each checklist, count (use case-insensitive matching — `[X]` and `[x]` are both complete):
     - Total items: All lines matching `- [ ]` or `- [xX]` (case-insensitive checkbox)
     - Completed items: Lines matching `- [xX]` (case-insensitive — `[X]` and `[x]` both count)
     - Incomplete items: Lines matching `- [ ]` (only empty checkbox; trim surrounding whitespace before matching)
   - Create a status table:

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | ✓ PASS |
     | test.md   | 8     | 5         | 3          | ✗ FAIL |
     | security.md | 6   | 6         | 0          | ✓ PASS |
     ```

   - Calculate overall status:
     - **PASS**: All checklists have 0 incomplete items
     - **FAIL**: One or more checklists have incomplete items

   - **If any checklist is incomplete**:
     - Display the table with incomplete item counts
     - **STOP** and ask: "Some checklists are incomplete. Proceed with implementation anyway, or stop to complete them first? (yes to proceed / no to stop)"
     - Wait for user response before continuing
     - If user says "no" or "stop", halt execution
     - If user says "yes" or "proceed" or "continue", proceed to step 3

   - **If all checklists are complete**:
     - Display the table showing all checklists passed
     - Automatically proceed to step 3

2b. **Detect redesign mode**: Scan FEATURE_DIR/spec.md for visual or UX redesign signals. Keywords: "redesign", "rediseño", "new look", "new design", "visual overhaul", "UI revamp", "rework the UI", "rework the UX", "visual refresh", "new interface", "change the look", "change the UI", "new layout".

If any are found, set `REDESIGN_MODE = true` and apply these rules throughout implementation:

- **Existing code is the baseline, not the deliverable.** If a component or function already exists, that does NOT mean the task is done — it means the current implementation must be evaluated against the target spec and modified or replaced if it doesn't match.
- **Do not skip tasks because the functionality exists.** Each task must be evaluated against the TARGET state described in the spec, not the current state of the code.
- When modifying existing code, treat the changes as intentional rewrites, not accidental overwrites.

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints. If `REDESIGN_MODE = true`, pay special attention to the `## Redesign Baseline` section — it defines the current vs target state delta that must be implemented.
   - **IF EXISTS**: Read quickstart.md for integration scenarios

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if .eslintrc* exists → create/verify .eslintignore
   - Check if eslint.config.* exists → ensure the config's `ignores` entries cover required patterns
   - Check if .prettierrc* exists → create/verify .prettierignore
   - Check if .npmrc or package.json exists → create/verify .npmignore (if publishing)
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Node.js/JavaScript/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
   - **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Ruby**: `.bundle/`, `log/`, `tmp/`, `*.gem`, `vendor/bundle/`
   - **PHP**: `vendor/`, `*.log`, `*.cache`, `*.env`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `*.prof*`, `.idea/`, `*.log`, `.env*`
   - **Kotlin**: `build/`, `out/`, `.gradle/`, `.idea/`, `*.class`, `*.jar`, `*.iml`, `*.log`, `.env*`
   - **C++**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.so`, `*.a`, `*.exe`, `*.dll`, `.idea/`, `*.log`, `.env*`
   - **C**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.a`, `*.so`, `*.exe`, `autom4te.cache/`, `config.status`, `config.log`, `.idea/`, `*.log`, `.env*`
   - **Swift**: `.build/`, `DerivedData/`, `*.swiftpm/`, `Packages/`
   - **R**: `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `*.Rproj`, `packrat/`, `renv/`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Tool-Specific Patterns**:
   - **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
   - **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
   - **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. Parse tasks.md structure and extract:
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task dependencies**: Sequential vs parallel execution rules
   - **Task details**: ID, description, file paths, parallel markers [P]
   - **Execution flow**: Order and dependency requirements

6. Execute implementation following the task plan with **mandatory TDD**:

   For **each task** (unless it is a setup/config task with no testable behavior):

   ### a. Plan tests (before writing any code)

   List test cases as single-line `[TEST]` comments. Walk through ZOMBIES explicitly:
   - **Z** — Zero: initial/empty state (no items, default values)
   - **O** — One: first item, first transition
   - **M** — Many: multiple items, complex scenarios
   - **B** — Boundary: transitions between states, both directions
   - **I** — Interface: let tests reveal method signatures and return types
   - **E** — Exceptions: error conditions; verify object still works after errors
   - **S** — Simple scenarios, simple solutions throughout

   Test data must always be anonymous. Never use real names, emails, or PII — use `user@example.com`, `John Doe`, etc.

   ### b. TDD cycle per test (Red → Green → Refactor → Commit)

   For each `[TEST]` comment:

   1. 🔴 Replace comment with a failing test in given/when/then format (empty lines separating sections)
   2. Predict what will fail
   3. Run tests → compilation error (class/method doesn't exist)
   4. Add minimal code to compile
   5. Predict assertion failure
   6. Run tests → assertion failure
   7. Add minimal code to pass — nothing more
   8. 🌱 Run tests → green
   9. Simplify: remove any code not required by a failing test
   10. 🌀 Refactor: improve expressiveness without adding behavior. Reflect on domain — is there a missing concept? An object to extract?
   11. Run tests after each refactoring step
   12. Commit: every green + refactored state = one commit

   ### c. Mark task complete and update PR

   After all tests for a task pass:

   1. Mark `[X]` in `tasks.md` for this task.

   2. Update the checklist block in the PR body: find the row for this task in the table and change its Status from `TO DO` to `DONE`. Replace the entire `<!-- dev-checklist -->` ... `<!-- /dev-checklist -->` block with the updated content.

      ```bash
      gh pr edit --body "<updated-body>"
      ```

7. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, configuration
   - **Tests before code**: Write tests for contracts, entities, and integration scenarios before implementing them
   - **Core development**: Implement models, services, CLI commands, endpoints — all TDD
   - **Integration work**: Database connections, middleware, logging, external services
   - **Polish and validation**: Final review pass using `/product-flow:praxis.code-simplifier`

8. Progress tracking and error handling:
   - Report progress after each completed task using a PM-friendly message: "✅ Step X of Y complete" — no file paths, task IDs, or technical detail in the chat
   - Halt execution if any non-parallel task fails
   - For parallel tasks [P], continue with successful tasks, report failed ones
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed
   - **IMPORTANT** For completed tasks, make sure to mark the task off as [X] in the tasks file.

9. Update PR — mark implementation complete

   Count total tasks from `tasks.md`. Update the checklist block in the PR body: replace the Implementation line with the completed count and mark it checked.

   ```
   - [x] **Implementation** — <N>/<N> tasks complete
   ```

   ```bash
   gh pr edit --body "<updated-body>"
   ```

10. Completion validation:
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - Run final evaluation: analyze tests for gaps, check nothing is hardcoded that shouldn't be
   - Report final status with summary of completed work.

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/product-flow:speckit.tasks` first to regenerate the task list.
