---
description: "Internal — Manages PR comment lifecycle. Detects unprocessed bot comments and marks them as resolved."
---

## Purpose

Single source of truth for comment processing state. Any skill that reads or resolves PR comments uses this skill.

**Status marker:** Every bot comment embeds `<!-- status:UNANSWERED -->` or `<!-- status:ANSWERED -->` as an invisible marker. Detection logic depends on this marker being present.

---

## Operations

### `pending`

Returns the list of bot comments that are still `UNANSWERED`.

**Used by:** `/continue` and `/plan` to determine whether there are blocking comments.

#### Execution

1. Read all PR comments:

```bash
gh pr view --json comments -q '.comments[] | {id: .id, author: .author.login, body: .body}'
```

2. Filter comments that:
   - Contain `<!-- status:UNANSWERED -->`

3. Output:
   - If none found: `NO_PENDING_COMMENTS`
   - If any found: return the list with id, author, and full content

---

### `resolve`

Marks a bot comment as `ANSWERED` by editing it in place.

**Used by:** `/consolidate-spec` and `/consolidate-plan` after applying changes.

**Input (`$ARGUMENTS`):** A list of comment IDs to mark as resolved.

#### Execution

1. Run the `pending` operation to get unresolved comments. If `NO_PENDING_COMMENTS`: stop silently.

2. For each comment ID in `$ARGUMENTS`, edit the comment replacing `<!-- status:UNANSWERED -->` with `<!-- status:ANSWERED -->`:

```bash
# Get repo info
gh pr view --json number,headRepositoryOwner,headRepository \
  -q '{number: .number, owner: .headRepositoryOwner.login, repo: .headRepository.name}'

# Edit the comment
gh api repos/{owner}/{repo}/issues/comments/{comment_id} \
  -X PATCH \
  -f body="<updated body with ANSWERED replacing UNANSWERED>"
```

3. Output: number of comments resolved.
