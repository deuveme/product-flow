---
description: "Implements tasks from tasks.md using strict TDD with ZOMBIES ordering."
user-invocable: false
context: fork
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

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

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
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

   2. Update the Dev Checklist block in the PR body: find the row for this task in the table and change its Status from `TO DO` to `DONE`. Replace the entire `<!-- dev-checklist -->` ... `<!-- /dev-checklist -->` block with the updated content.

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

   Count total tasks from `tasks.md`. Update the Dev Checklist block in the PR body: replace the Implementation line with the completed count and mark it checked.

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
