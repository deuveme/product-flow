---
description: "Internal — Manages PR comment lifecycle. Detects unprocessed team comments and acknowledges them after consolidation."
---

## Purpose

Single source of truth for comment processing state. Any skill that reads or acknowledges PR comments uses this skill.

**Bot comment signature:** Every acknowledgment posted by this skill embeds `<!-- bot:pr-comments:ack -->` as an invisible marker. Detection logic depends on this marker being present.

---

## Operations

### `pending`

Returns the list of human PR comments that have not yet been acknowledged.

**Used by:** `/continue` to determine `has_comments`.

#### Execution

1. Read all PR comments from two sources:

```bash
# General PR comments (conversation-level)
gh pr view --json comments -q '.comments[] | {author: .author.login, body: .body}'

# Inline review thread comments (line-level feedback left during code review)
gh api repos/{owner}/{repo}/pulls/{number}/comments --jq '.[] | {author: .user.login, body: .body}'
```

To get `{owner}`, `{repo}`, and `{number}`, run:
```bash
gh pr view --json number,headRepositoryOwner,headRepository -q '{number: .number, owner: .headRepositoryOwner.login, repo: .headRepository.name}'
```

Merge both lists, preserving chronological order (use `created_at` from the API response if available, otherwise append review comments after conversation comments).

2. Find the position of the last comment containing `<!-- bot:pr-comments:ack -->`.

3. Collect all comments posted **after** that position (or all comments if no ack exists) that are not bot comments. A comment is a bot comment if it:
   - Contains `<!-- bot:pr-comments:ack -->`
   - Starts with `**Technical question detected:**`

4. Output:
   - If none found: `NO_PENDING_COMMENTS`
   - If any found: return the list with author, source (`conversation` or `review-thread`), and full content

---

### `ack`

Acknowledges all pending comments by posting one reply per comment, quoting the original and describing what was done.

**Used by:** `/consolidate-spec` and `/consolidate-plan` after applying changes.

**Input (`$ARGUMENTS`):** A map of comment → action taken. Passed as a structured list by the calling skill.

#### Execution

1. Run the `pending` operation to get unprocessed comments. If `NO_PENDING_COMMENTS`: stop silently.

2. For each pending comment, post:

```bash
gh pr comment --body "<!-- bot:pr-comments:ack -->
✅ **Feedback integrated**

> \"[first 120 characters of the original comment]\"

[What was done: specific change applied, or reason it was not applied]"
```

3. Output: number of comments acknowledged.
