---
description: Convert existing tasks into actionable, dependency-ordered GitHub issues for the feature based on available design artifacts.
user_invocable: false
tools: ['github/github-mcp-server/issue_write']
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g `'I'\''m Groot'`.

2. From the executed script, extract the path to **tasks**.

3. Get the Git remote:

   ```bash
   git config --get remote.origin.url
   ```

   > [!CAUTION]
   > ONLY PROCEED TO NEXT STEPS IF THE REMOTE IS A GITHUB URL

4. Get the current PR number:

   ```bash
   gh pr view --json number --jq '.number'
   ```

   Store it as `PR_NUMBER`. If there is no open PR, skip steps 6 and 7 (issue linking to PR is not possible without one, but issue creation still proceeds).

5. For each task in `tasks.md`:

   a. Skip tasks that already have a `(#N)` annotation — they were created in a previous run.

   b. Use the GitHub MCP server to create a new issue in the repository matching the Git remote. The issue title must match the task description. The issue body must include:
      - The task ID (e.g. `T001`)
      - A link to the PR: `Part of #PR_NUMBER`

   c. After the issue is created, **immediately update the task line in `tasks.md`** by appending `(#N)` where N is the new issue number. Example:

      Before: `- [ ] T001 [US1] Create user entity in src/domain/user.ts`
      After:  `- [ ] T001 [US1] Create user entity in src/domain/user.ts (#42)`

   d. Commit the updated `tasks.md` after every 5 issues (or at the end) to avoid losing progress if the run is interrupted:

      ```bash
      git add specs/
      git commit -m "docs: link issue numbers to tasks"
      git push origin HEAD
      ```

   > [!CAUTION]
   > UNDER NO CIRCUMSTANCES EVER CREATE ISSUES IN REPOSITORIES THAT DO NOT MATCH THE REMOTE URL

6. After all issues are created, update the PR body to add a linked-issues section. Append the following block to the PR body (after the existing content, before any trailing newlines):

   ```
   ### Linked issues
   <!-- linked-issues -->
   Closes #N1, closes #N2, closes #N3, ...
   <!-- /linked-issues -->
   ```

   Where N1, N2, N3... are all the issue numbers created in step 5, in task order.

   If a `<!-- linked-issues -->` block already exists (from a previous partial run), replace it entirely.

   ```bash
   gh pr edit PR_NUMBER --body "<updated body>"
   ```

7. Commit the final state of `tasks.md` (if not already committed in step 5d):

   ```bash
   git add specs/
   git commit -m "docs: link issue numbers to tasks"
   git push origin HEAD
   ```
