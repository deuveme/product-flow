---
description: "Shows how much context memory Claude has left in this session."
model: haiku
effort: low
---

## Execution

### 1. Read the actual session context

Estimate the percentage of context used based on the length and complexity of the current conversation history. Consider: number of messages, message length, tool use, files read, command outputs, etc.

- Empty or very short conversation → ~2–5%
- Short conversation (few exchanges) → ~5–15%
- Medium conversation (active work) → ~20–50%
- Long conversation with many tools → ~50–80%
- Very long conversation with large outputs → ~80–95%

### 2. Determine level

| % used | Level | Emoji |
|---------|-------|-------|
| < 50%   | You can continue | 🟢 |
| 50–79%  | Finish the current step | 🟡 |
| 80–89%  | Run /clear soon | 🟠 |
| ≥ 90%   | Run /clear NOW | 🔴 |

### 3. Show report

Show ONLY: the visual bar, the percentage and the recommendation. Example for 🟠:

```
[████████████████░░░░]  83% used

🟠  Run /clear soon to free up context
```

The recommendation is mandatory and is always shown below the bar.

### 4. Show current branch

Show the current branch and PR URL (if on a feature branch) so that after a `/clear` the user knows what to run:

```bash
git branch --show-current
gh pr view --json url -q '.url' 2>/dev/null || echo "(no PR)"
```

Output format:
```
🌿 Branch: <branch-name>
🔗 PR: <PR_URL>   ← omit this line if no PR
```

If on `main`, show: `📍 main · no active feature`
