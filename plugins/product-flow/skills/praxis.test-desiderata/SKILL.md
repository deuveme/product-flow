---
description: "Analyzes test quality using Kent Beck's 12 Test Desiderata properties."
user-invocable: false
icon: 🧪
---

## User Input

```text
$ARGUMENTS
```

If the user points to a file or test suite, analyze that. If no argument is provided,
ask: "Which test file or directory should I analyze?"

---

## Analysis Workflow

1. Read the test code thoroughly
2. Evaluate each file against the 12 properties below
3. Identify tradeoffs between conflicting properties
4. Prioritize improvements by impact
5. Suggest specific, actionable changes with exact file locations

---

## The 12 Test Desiderata Properties

### 1. Isolated
Tests return the same results regardless of execution order. No shared mutable state,
database state dependencies, or external ordering issues.

**Detect:** shared fixtures mutated across tests, missing teardown, tests that pass
only when run in a specific order.

### 2. Composable
Test different dimensions of variability separately and combine results. Break complex
scenarios into independent, reusable components.

**Detect:** monolithic tests that verify 5+ behaviors at once, duplicated setup code
that could be extracted into a shared fixture.

### 3. Deterministic
If nothing changes, test results don't change. No randomness, timing dependencies,
or environmental variation.

**Detect:** `random`, `uuid`, `datetime.now()` in assertions without mocking, flaky
tests that fail intermittently, external service calls without mocks.

### 4. Fast
Tests run quickly, enabling frequent execution during development.

**Detect:** unnecessary `sleep`, unneeded DB round-trips, heavy I/O in unit tests,
missing use of in-memory alternatives.

### 5. Writable
Tests are cheap to write relative to the code being tested.

**Detect:** excessive boilerplate per test, complex manual mock setup that a fixture
or factory could replace, tests that require intimate knowledge of internals to write.

### 6. Readable
Tests are comprehensible and clearly express their intent.

**Detect:** unclear test names (test_1, test_func), magic numbers without explanation,
missing Arrange/Act/Assert structure, obscure assertion messages.

### 7. Behavioral
Tests are sensitive to behavior changes — failures indicate actual regressions.

**Detect:** tests passing despite broken functionality, assertions only on return
types not return values, missing edge case and error path coverage.

### 8. Structure-insensitive
Tests don't break when code is refactored without changing behavior.

**Detect:** mocking private methods or internal functions, asserting on internal
state rather than observable output, tests coupled to class names or module paths.

### 9. Automated
Tests run without human intervention.

**Detect:** `print` statements requiring visual inspection, interactive prompts,
manual setup steps documented in comments, tests skipped by default.

### 10. Specific
When a test fails, the root cause is obvious.

**Detect:** multiple unrelated assertions in one test, generic error messages,
overly broad `try/except` in test bodies, assertion without a descriptive message.

### 11. Predictive
If all tests pass, the code is suitable for production.

**Detect:** missing scenarios for known error conditions, no integration tests for
critical paths, untested configuration branches, missing authentication/authorization
test cases.

### 12. Inspiring
Passing tests inspire confidence in the system.

**Detect:** trivial tests that only verify `assert True`, low coverage on critical
paths, missing edge cases for known tricky logic, tests that exist only for coverage
metrics.

---

## Tradeoff Analysis

After evaluating properties, identify active tradeoffs:

**Supporting pairs** (improving one helps the other):
- Isolated + Deterministic → reliability
- Fast + Automated → frequent feedback
- Readable + Specific → easier debugging

**Conflicting pairs** (improving one hurts the other):
- Predictive vs. Fast — comprehensive coverage often means slower suites
- Fast vs. Isolated — full isolation sometimes requires more setup overhead
- Writable vs. Predictive — simple tests may not cover enough scenarios

Note any tradeoffs in the output and explain the recommended balance for this
project's context based on the detected tech stack.

---

## Prioritization Order

Address issues in this order:

1. **Safety** — Isolated and Deterministic first (flaky tests destroy team trust)
2. **Feedback loop** — Fast (slow tests stop being run)
3. **Maintainability** — Readable and Structure-insensitive (long-term health)
4. **Confidence** — Predictive and Inspiring (production readiness)

---

## Output Format

Produce:

1. **Property Scores** — a table rating each property: ✅ Good / ⚠️ Issues / ❌ Problems
2. **Top Issues** — the 3-5 most impactful problems, each with:
   - File path and line number
   - Which property is violated
   - Concrete fix with example code
3. **Tradeoffs** — any active tradeoffs and the recommended balance
4. **Quick Wins** — changes fixable in <15 minutes
5. **Deferred Improvements** — larger refactors to log in `lessons-learned.md`

---

**Attribution:** Adapted from Praxis by Antonio Acuña (https://github.com/acunap/praxis).
Test Desiderata framework by Kent Beck (https://testdesiderata.com/). MIT License.
