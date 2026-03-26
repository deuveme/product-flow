---
description: "Internal — Manages PR comment lifecycle. Detects unprocessed bot comments and marks them as resolved."
---

## Purpose

Single source of truth for comment processing state. Any skill that reads or resolves PR comments uses this skill.

**Status marker:** Every bot comment embeds `<!-- id:q<N> type:<type> status:<status> -->` as an invisible first-line marker, where:
- `id:q<N>` — sequential question number, globally unique within the PR (e.g. `q1`, `q2`)
- `type` — `technical` or `product`
- `status` — `UNANSWERED` or `ANSWERED`

**User response format:** To answer or correct a bot comment, the user adds a **new top-level comment** to the PR referencing the question number. The format is flexible:
```
Question <N>. Answer: [letter or text]
Question <N>. Correction: [letter or text with explanation]
Q<N>: [text]                         ← shorthand, treated as Answer
Question <N> - Correction: [text]    ← dash separator also valid
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

#### Execution

1. Determine the next question number `<N>`:

```bash
gh pr view --json comments \
  -q '[.comments[].body | scan("id:q([0-9]+)") | tonumber] | if length == 0 then 0 else max end'
```

Add 1 to the result (use 1 if the command returns 0 or fails).

2. Build the user instruction line based on `status`:
   - `ANSWERED`: `> 💬 To change this decision, add a new comment: \`Question <N>. Correction: [letter or answer]\``
   - `UNANSWERED`: `> 💬 To answer, add a new comment: \`Question <N>. Answer: [letter or answer]\``

3. Post the comment:

```bash
gh pr comment --body "<!-- id:q<N> type:<type> status:<status> -->
<body>

<user instruction line>"
```

4. Output: the comment ID and the `<N>` used.

---

### `pending`

Returns the list of bot comments that are still `UNANSWERED`.

**Used by:** `/continue`, `/plan`, `/tasks`, `/implement` to check for blocking comments.

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

**Used by:** `/consolidate-spec` and `/consolidate-plan` after applying changes.

**Input (`$ARGUMENTS`):** A list of comment IDs to mark as resolved.

#### Execution

1. Run the `pending` operation. If `NO_PENDING_COMMENTS`: stop silently.

2. For each comment ID in `$ARGUMENTS`, edit the comment replacing `status:UNANSWERED` with `status:ANSWERED` in the marker (keep `id` and `type` intact):

```bash
# Get repo info
gh pr view --json number,headRepositoryOwner,headRepository \
  -q '{number: .number, owner: .headRepositoryOwner.login, repo: .headRepository.name}'

# Edit the comment (replace only the status token in the marker)
gh api repos/{owner}/{repo}/issues/comments/{comment_id} \
  -X PATCH \
  -f body="<updated body with status:UNANSWERED replaced by status:ANSWERED>"
```

3. Output: number of comments resolved.

---

### `read-answers`

Reads all user responses to bot comments and returns the last answer per question number.

**Used by:** any skill that needs to apply `Answer:` or `Correction:` responses before proceeding.

#### Execution

1. Fetch all PR comments in chronological order:

```bash
gh pr view --json comments \
  -q '[.comments[] | {id: .id, body: .body, createdAt: .createdAt}] | sort_by(.createdAt)'
```

2. For each comment, scan the body for lines matching this flexible pattern (case-insensitive):

   ```
   (Question|Q)\s*<N>[.:\s-]+(Answer|Correction|Fix|Resp(uesta)?)?[.:\s-]*<text>
   ```

   Concretely, a line is a match if it:
   - Starts with `Question` or `Q` (case-insensitive)
   - Followed by one or more digits (the question number N)
   - Followed by any separator: `.` `:` `-` or whitespace (one or more)
   - Optionally followed by a keyword (`Answer`, `Correction`, `Fix`, `Respuesta`, `Resp`) and another separator
   - Followed by the response text

   Examples that all match as valid responses to question 1:
   ```
   Question 1. Answer: B
   Question 1. Correction: use option A instead
   question 1: b
   Q1 - answer: go with B
   Question 1. B
   Q1: Correction use A, it fits better
   ```

   If the keyword is `Correction`, `Fix`, or a synonym → type = `Correction`.
   If the keyword is `Answer`, `Respuesta`, `Resp` or absent → type = `Answer`.

3. A single comment may contain responses to multiple questions (one per line). Extract all of them.

4. Group all matches by question number `N`. For each group, keep only the **last** entry (highest `createdAt`, then last line within the same comment).

5. Return a map of: `{ qN: { type: "Answer"|"Correction", text: "<response text>", commentId: "<id>" } }`

6. If no matches found: return `NO_USER_RESPONSES`.
