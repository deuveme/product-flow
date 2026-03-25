---
description: "UTILITY — Checks the context and, if it is high, clears automatically."
---

## Execution

### 1. Estimate current context

Use the same logic as `/context` to calculate the percentage used.

### 2. Branch by level

#### If < 50% (🟢)

Show only:

```
[████░░░░░░░░░░░░░░░░]  22% used

🟢  All good, you can continue.
```

Done. Do nothing more.

#### If 50–79% (🟡)

Show status only:

```
[████████████░░░░░░░░]  65% used

🟡  Moderate context. Finish the current step before continuing.
```

Done. Do not execute anything.

#### If 80–89% (🟠)

Show status and warning:

```
[████████████████░░░░]  83% used

🟠  Context is high. Open a new session before the next command.
```

Done. Do not execute anything.

#### If ≥ 90% (🔴)

**Show status and instructions:**

```
[████████████████████]  92% used

🔴  Critical context. You must run /clear before continuing.

Run: /clear

When you restart, Claude will automatically show the workflow status.
```

**STOP.** Do not execute any further actions.
