---
description: "Adversarial coverage pass using exploratory testing heuristics to find untested cases."
user-invocable: false
icon: 🐛
model: sonnet
context: fork
effort: medium
---

## User Input

```text
$ARGUMENTS
```

If the user points to specific files, analyze those. Otherwise use the feature branch context.

---

## Analysis Workflow

1. Load feature context (spec, implementation files, existing tests)
2. Apply the 7 heuristic categories below to identify missing test cases
3. Classify each missing case as technical or product, and by priority: HIGH / MEDIUM / LOW
4. Resolve technical cases autonomously and post a PR comment per case
5. Escalate product cases to the PM via AskUserQuestion and post a PR comment per case

---

## Setup

```bash
BRANCH=$(git branch --show-current)
FEATURE_DIR="specs/$BRANCH"
```

Read:
- `$FEATURE_DIR/spec.md` — acceptance criteria and edge cases defined by the product
- `$FEATURE_DIR/data-model.md` — entities, fields, validation rules, state transitions
- `$FEATURE_DIR/contracts/` — interface contracts (API endpoints, command schemas, etc.)
- All test files touched or created during the current feature implementation (use `git diff origin/main --name-only` to identify them)
- The implementation files under test

---

## Heuristic Categories

For each category, identify cases that are **not covered** by the existing tests.

### 1. Boundary Values
- Numeric: zero, one, max, max+1, min, min-1, negative
- String: empty string, single character, max length, max+1 length
- Collections: empty list, single item, exact limit, limit+1
- Dates: epoch, far future, leap day, timezone boundaries

### 2. Error Conditions
- Null / undefined / missing required fields
- Wrong type (string where int expected, etc.)
- Malformed input (invalid format, partial data)
- Duplicate submissions (idempotency)
- Expired tokens, stale references

### 3. State Transitions
- Invalid state transitions (e.g., cancelling an already-cancelled order)
- Skipping states (e.g., moving from DRAFT to PUBLISHED without REVIEW)
- Concurrent modifications to the same entity
- Re-applying an operation that should only run once

### 4. Authorization
- Unauthenticated access to authenticated endpoints
- User A accessing User B's resources (horizontal privilege escalation)
- Low-privilege role performing high-privilege action (vertical privilege escalation)
- Accessing resources after permission has been revoked

### 5. CRUD Matrix
For each entity in `data-model.md`, verify that these cases are tested:
- **Create**: valid payload, duplicate, missing required field, invalid field value
- **Read**: existing record, non-existent ID, soft-deleted record, unauthorized access
- **Update**: valid update, partial update, immutable field update, optimistic lock conflict
- **Delete**: existing record, non-existent ID, cascading effects, soft vs. hard delete

### 6. Data Quality
- Special characters in string fields (quotes, backslashes, newlines, null bytes)
- Unicode edge cases (emoji, RTL text, zero-width characters)
- SQL/NoSQL injection strings if the data reaches a query
- Extremely long strings in free-text fields
- Leading/trailing whitespace where trimming is expected

### 7. Concurrency
- Two requests creating the same unique resource simultaneously
- Read-modify-write race conditions
- Optimistic locking violations
- Retry storms on transient failures

### 8. Security
Apply only to code that handles external input, sensitive data, or HTTP responses.

- **Injection**: user-controlled input reaching a query, shell command, or template without sanitization (SQL, NoSQL, command injection)
- **Secrets in code or logs**: hardcoded API keys, tokens, passwords, or connection strings; sensitive fields (password, token, card number) appearing in log output
- **Sensitive data in API responses**: endpoints returning fields that should not be exposed (password hashes, internal IDs, PII not required by the caller)
- **XSS** *(frontend only)*: user-supplied content rendered as raw HTML without escaping
- **CSRF** *(frontend only)*: state-changing requests (POST/PUT/DELETE) missing CSRF token or SameSite cookie protection
- **Secure headers** *(HTTP handlers only)*: missing `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options` on responses that serve HTML or sensitive data

Skip this category entirely for pure domain logic, in-memory utilities, or code with no external input or HTTP surface.

---

## Case Classification

For each missing test case identified, classify it along two dimensions:

**Type:**
- **Technical** — implementation detail: boundary values, error conditions, state transitions, authorization rules, CRUD edge cases, data quality, concurrency, security. Resolved autonomously.
- **Product** — depends on business intent: expected behavior for an undocumented edge case, priority of covering a scenario, acceptable data range not specified in the spec. Escalated to the PM.

**Priority:**
- **HIGH** — likely to cause a production bug or security issue (authorization failures, state transition violations, boundary overflows, missing error handling for known failure modes, injection, secrets exposure, sensitive data leaks)
- **MEDIUM** — important for correctness, lower immediate risk (CRUD edge cases, data quality, duplicate submission handling)
- **LOW** — nice-to-have (extreme boundary values, non-critical concurrency, cosmetic data formatting)

---

## Resolution

### Technical cases — resolve autonomously

For each technical missing case (HIGH, MEDIUM, or LOW):

1. Write the test following the same conventions as the existing test suite (naming, structure, assertion style, fixture usage). Co-locate with the implementation file or use the existing test directory for that module.
2. Add a comment above the test: `// bugmagnet: <heuristic category> — <one-line description of what this tests>`
3. Do **not** modify existing tests. Only add new ones.
4. Post a PR comment via `/product-flow:pr-comments write`:
   - `type: technical`, `status: ANSWERED`
   - Body:
     ```
     **Bugmagnet — [heuristic category] ([priority])**

     **Gap identified:** [one-line description of the untested case]
     **Resolution:** Test written at [file:line]
     ```

### Product cases — escalate to PM

Collect all product cases and ask the PM in a **single AskUserQuestion call** (one entry per case). For each, ask what the expected behavior is.

After receiving the PM's answers:
1. Write the test implementing the confirmed behavior
2. Post a PR comment via `/product-flow:pr-comments write`:
   - `type: product`, `status: ANSWERED`
   - Body:
     ```
     **Bugmagnet — [heuristic category] ([priority])**

     **Gap identified:** [one-line description of the untested case]
     **PM answer:** [answer received]
     **Resolution:** Test written at [file:line]
     ```

If a product case cannot be resolved (PM answer is unclear or deferred): post with `status: UNANSWERED` and skip writing the test.

---

## User feedback

Show progress and results to the user:

```
🐛 Running bugmagnet coverage analysis...

[if analyzing] ⏳ Analyzing [module/file]...
[after each case resolved] ✅ [Category] [priority] — [one-line case] → test written

---

✅ Bugmagnet complete

Found N cases: M HIGH (written), L MEDIUM (written), K LOW (written) [security: S cases]
[if product cases escalated: P product cases — awaiting PM answers]

All tests written. PR comments posted.
```

If no missing cases found:
```
✅ Bugmagnet complete

No coverage gaps detected — all heuristics satisfied.
```

---

## Key Rules

- Never modify existing tests — only add new ones
- Tests must be real failing tests, not stubs or skipped tests
- Follow exactly the same test conventions as the surrounding test suite
- If no test files exist yet for a module, create the file following project conventions
- Do not invent scenarios not grounded in the spec or data-model — every case must trace back to a real entity, field, endpoint, or acceptance criterion
- Use repo-relative paths in all generated content

---

**Attribution:** Inspired by [Bugmagnet](https://github.com/gojko/bugmagnet) by Gojko Adzic. MIT License.
