---
description: "Manages PR comment lifecycle."
user-invocable: false
model: haiku
context: fork
effort: low
---

## Purpose

Single source of truth for comment processing state. Any skill that reads or resolves PR comments uses this skill.

**Local decisions log:** Every question posted to the PR is also written to `specs/<branch>/decisions.md`. This file is the durable, offline record of all questions, possible answers, AI decisions, user responses, and current status — it persists even if the PR is deleted.

**Enforcement:** All bot PR comments MUST go through the `write` operation — never call `gh pr comment` directly. This guarantees every comment is numbered, marked, and saved to `decisions.md`.

**Status marker:** Every bot comment embeds `<!-- id:q<N> type:<type> status:<status> -->` as an invisible first-line marker, where:
- `id:q<N>` — sequential question number, globally unique within the PR (e.g. `q1`, `q2`)
- `type` — `technical` or `product`
- `status` — `UNANSWERED` or `ANSWERED`

**User response format:** To answer or override a bot comment, the user adds a **new top-level comment** to the PR referencing the question number. The format is flexible:
```
Question <N>. Answer: [letter or text]
Q<N>: [text]                         ← shorthand
Question <N> - Answer: [text]        ← dash separator also valid
```
Multiple responses for the same question number are allowed — the **last one chronologically** wins. A single comment may answer multiple questions, one per line.

---

## Operations

### `write`

Writes a single bot comment to the PR with the correct marker, user instruction, and auto-incremented question number.

**Used by:** every skill that needs to post a bot comment to the PR.

**Input (`$ARGUMENTS`):**
- `type` — `technical` or `product`
- `status` — `ANSWERED` or `UNANSWERED`
- `body` — the comment content (plain text, without marker or user instruction)

**Technical decision body format:**
- `ANSWERED`:
  ```
  **Technical question detected:** "[identified question]"

  **Proposed answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  **Autonomously chosen answer:** We chose "[chosen option]" because "[brief reasoning]"
  ```
- `UNANSWERED`:
  ```
  **Technical question detected:** "[identified question]"

  **Possible answers:** A. "[option A]" B. "[option B]" C. "[option C]"

  ⚠️ **Unresolved — requires input from the development team.**
  ```

#### Execution

0. Acquire the comment lock:

```bash
BRANCH=$(git branch --show-current)
LOCK_DIR="specs/$BRANCH/.comment-lock"

LOCK_ACQUIRED=false
for i in $(seq 1 10); do
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=true
    break
  fi
  # Check if lock is stale (> 30 seconds) and forcibly clear it
  LOCK_TIME=$(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$((NOW - LOCK_TIME))
  if [ "$AGE" -gt 30 ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  else
    sleep 3
  fi
done

if [ "$LOCK_ACQUIRED" = false ]; then
  echo "ERROR: Could not acquire comment lock after 30 seconds. Another session may be writing to this PR. Try again in a moment."
  exit 1
fi
```

If lock acquisition fails: propagate the error and **STOP**. Do not proceed.

1. Determine the next question number `<N>`:

```bash
gh pr view --json comments \
  -q '[.comments[].body | scan("id:q([0-9]+)") | tonumber] | if length == 0 then 0 else max end'
```

Add 1 to the result (use 1 if the command returns 0 or fails).

2. Build the user instruction line based on `status`:
   - `ANSWERED`: `> 💬 To change this decision, add a new comment: \`Question <N>. Answer: [letter or answer]\``
   - `UNANSWERED`: `> 💬 To answer, add a new comment: \`Question <N>. Answer: [letter or answer]\``

3. Post the comment:

```bash
gh pr comment --body "<!-- id:q<N> type:<type> status:<status> -->
**Question <N> · Type: <type> · Status: <status>**

<body>

<user instruction line>"
```

If posting fails: release the lock (`rmdir "$LOCK_DIR" 2>/dev/null || true`) and propagate the error. **STOP.**

Release the lock immediately after the comment is posted — before writing to `decisions.md`:

```bash
rmdir "$LOCK_DIR" 2>/dev/null || true
```

4. Append to `specs/<branch>/decisions.md` (create with header `# Decisions Log\n\n` if it does not exist):

```markdown
<!-- q<N> type:<type> status:<status> -->
## Question <N> · Type: <type> · Status: <status>

<body>

**User responses:**
_(none)_

---
```

Do not commit — the calling skill's `git add specs/` will include this file.

5. Output: the comment ID and the `<N>` used. If `status` is `UNANSWERED`, also show:

```
💬 A question has been added to the PR awaiting your reply.
   🔗 <PR_URL>
```

---

### `pending`

Returns the list of bot comments that are still `UNANSWERED`.

**Used by:** `/product-flow:continue`, `/product-flow:plan`, `/product-flow:tasks`, `/product-flow:implement` to check for blocking comments.

#### Execution

1. Read all PR comments:

```bash
gh pr view --json comments -q '.comments[] | {id: .id, author: .author.login, body: .body}'
```

2. Filter comments whose body contains `status:UNANSWERED`.

3. For each match, extract: `id`, `question number` (from `id:q<N>`), `type` (from `type:<type>`), full body.

4. Output:
   - If none found: `NO_PENDING_COMMENTS`
   - If any found: return the list with id, question number, type, and full content

---

### `resolve`

Marks one or more bot comments as `ANSWERED` by editing them in place.

**Used by:** `/product-flow:consolidate-spec` and `/product-flow:consolidate-plan` after applying changes.

**Input (`$ARGUMENTS`):** A list of comment IDs to mark as resolved.

#### Execution

1. Run the `pending` operation. If `NO_PENDING_COMMENTS`: stop silently.

2. For each comment ID in `$ARGUMENTS`, edit the comment replacing `UNANSWERED` with `ANSWERED` in both the HTML marker and the visible bold line (keep `id` and `type` intact):

```bash
# Get repo info
gh pr view --json number,headRepositoryOwner,headRepository \
  -q '{number: .number, owner: .headRepositoryOwner.login, repo: .headRepository.name}'

# Edit the comment (replace UNANSWERED with ANSWERED in both the marker and the bold line)
gh api repos/{owner}/{repo}/issues/comments/{comment_id} \
  -X PATCH \
  -f body="<updated body with all occurrences of UNANSWERED replaced by ANSWERED>"
```

3. For each resolved comment, extract its question number N (from `id:q<N>` in the body) and update `specs/<branch>/decisions.md`:
   - Change `<!-- q<N> type:<type> status:UNANSWERED -->` → `<!-- q<N> type:<type> status:ANSWERED -->`
   - Change `## Question <N> · Type: <type> · Status: UNANSWERED` → `## Question <N> · Type: <type> · Status: ANSWERED`

```bash
BRANCH=$(git branch --show-current)
git add "specs/$BRANCH/decisions.md"
git commit -m "chore: mark question(s) as answered in decisions.md"
```

If the commit fails with a GPG or signing error: show the standard GPG fix message and **STOP**.

Invoke `/product-flow:safe-push`.

4. Output: number of comments resolved.

---

### `read-answers`

Reads all user responses to bot comments and returns the last answer per question number.

**Used by:** any skill that needs to apply `Answer:` responses before proceeding.

#### Execution

1. Fetch all PR comments in chronological order:

```bash
gh pr view --json comments \
  -q '[.comments[] | {id: .id, body: .body, createdAt: .createdAt}] | sort_by(.createdAt)'
```

2. For each comment, scan the body for lines matching this flexible pattern (case-insensitive):

   ```
   (Question|Q)\s*<N>[.:\s-]+(Answer|Resp(uesta)?)?[.:\s-]*<text>
   ```

   Concretely, a line is a match if it:
   - Starts with `Question` or `Q` (case-insensitive)
   - Followed by one or more digits (the question number N)
   - Followed by any separator: `.` `:` `-` or whitespace (one or more)
   - Optionally followed by a keyword (`Answer`, `Respuesta`, `Resp`) and another separator
   - Followed by the response text

   Examples that all match as valid responses to question 1:
   ```
   Question 1. Answer: B
   question 1: b
   Q1 - answer: go with B
   Question 1. B
   ```

   All matches are treated as type `Answer` regardless of keyword.

3. A single comment may contain responses to multiple questions (one per line). Extract all of them.

4. Group all matches by question number `N`. For each group, keep only the **last** entry (highest `createdAt`, then last line within the same comment).

4b. Load already-processed answer IDs from `status.json`:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null | jq -r '.processed_answers // [] | .[]'
```

Filter out any entries from step 4 whose question number `N` appears in this list. These have already been applied in a previous run.

5. Return a map of: `{ qN: { text: "<response text>", commentId: "<id>" } }` — containing only new, unprocessed answers.

6. If no new answers found: return `NO_USER_RESPONSES`.

---

### `mark-processed`

Marks processed answers in `status.json` (prevents re-processing in future runs) and adds a 👍 reaction to the user's answer comment on GitHub (visible signal to the team that the answer was applied).

**Used by:** every skill that applies `read-answers` results, immediately after applying them.

**Input (`$ARGUMENTS`):** Space-separated list of question numbers that were applied (e.g. `1 3 5`). Duplicates are silently ignored — the `unique` filter in step 3 ensures each question number is recorded only once.

#### Execution

1. Get repo info:

```bash
gh pr view --json number,headRepositoryOwner,headRepository \
  -q '{number: .number, owner: .headRepositoryOwner.login, repo: .headRepository.name}'
```

2. For each question number N, find the user's answer comment and add a 👍 reaction:

```bash
# Find the last comment from a non-bot author containing the answer pattern for question N
gh pr view --json comments \
  -q '[.comments[] | select(.body | test("(?i)(question|q)\\s*<N>[.:\\s-]"))] | last | .id'

# Add 👍 reaction to that comment
gh api repos/{owner}/{repo}/issues/comments/{comment_id}/reactions \
  -X POST -f content="+1"
```

If no matching comment is found: skip silently.

2b. For each question number N, append the user's response to the corresponding entry in `specs/<branch>/decisions.md`. Replace the `_(none)_` placeholder on first response, or append a new numbered line on subsequent responses:

```markdown
**User responses:**
1. <ISO timestamp> — "<response text>"
```

If the entry for question N does not exist in `decisions.md` (e.g. the question was posted before this file existed): skip silently.

3. Record processed question numbers in `status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --argjson nums '[<N1>, <N2>, ...]' \
  '.processed_answers = ((.processed_answers // []) + $nums | unique)' > "$STATUS_FILE"
```

4. Commit:

```bash
DECISIONS_FILE="specs/$BRANCH/decisions.md"
git add "$STATUS_FILE" "$DECISIONS_FILE"
git commit -m "chore: mark answers as processed"
```

If the commit fails with a GPG or signing error: show the standard GPG fix message and **STOP**.

Invoke `/product-flow:safe-push`.

5. Output: `✅ Marked <N> answer(s) as applied on the PR.`

---

### `new-comments`

Returns new user PR comments that are not bot-generated and have not been processed yet. Used by public commands to detect unseen feedback (general comments, code review comments, inline review notes).

**Used by:** every public command at startup (`/product-flow:continue`, `/product-flow:build`, `/product-flow:submit`).

#### Execution

1. Fetch all PR comments in chronological order:

```bash
gh pr view --json comments \
  -q '[.comments[] | {id: .id, author: .author.login, body: .body, createdAt: .createdAt}] | sort_by(.createdAt)'
```

Also fetch inline review comments (code-level):

```bash
gh pr view --json reviews \
  -q '[.reviews[] | {id: .id, author: .author.login, body: .body, state: .state, submittedAt: .submittedAt}] | sort_by(.submittedAt)'
```

2. Filter out bot comments: discard any comment whose body contains `<!-- id:q`.

3. Filter out already-processed comments: load processed IDs from `status.json`:

```bash
BRANCH=$(git branch --show-current)
cat "specs/$BRANCH/status.json" 2>/dev/null | jq -r '.processed_comment_ids // [] | .[]'
```

Discard any comment whose `id` appears in this list.

4. If nothing remains: return `NO_NEW_COMMENTS`.

5. Otherwise return the list of new comments: `{ id, author, body, createdAt }` sorted chronologically.

---

### `mark-comments-processed`

Marks general user comments as processed: adds a 👍 reaction to each and records their IDs in `status.json` to prevent re-processing.

**Used by:** public commands after evaluating new user comments via `new-comments`.

**Input (`$ARGUMENTS`):** Space-separated list of comment IDs to mark (e.g. `IC_abc123 IC_def456`).

#### Execution

1. Get repo info:

```bash
gh pr view --json number,headRepositoryOwner,headRepository \
  -q '{number: .number, owner: .headRepositoryOwner.login, repo: .headRepository.name}'
```

2. For each comment ID, add a 👍 reaction:

```bash
gh api repos/{owner}/{repo}/issues/comments/{comment_id}/reactions \
  -X POST -f content="+1"
```

If the comment is a review comment (not an issue comment), use the reviews endpoint instead:

```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions \
  -X POST -f content="+1"
```

If adding the reaction fails: skip silently.

3. Record processed IDs in `status.json`:

```bash
BRANCH=$(git branch --show-current)
STATUS_FILE="specs/$BRANCH/status.json"
EXISTING=$(cat "$STATUS_FILE" 2>/dev/null || echo "{}")
echo "$EXISTING" | jq --argjson ids '["<id1>", "<id2>", ...]' \
  '.processed_comment_ids = ((.processed_comment_ids // []) + $ids | unique)' > "$STATUS_FILE"
git add "$STATUS_FILE"
git commit -m "chore: mark user comments as processed"
```

If the commit fails with a GPG or signing error: show the standard GPG fix message and **STOP**.

Invoke `/product-flow:safe-push`.

4. Output: `✅ Marked <N> comment(s) as processed.`
