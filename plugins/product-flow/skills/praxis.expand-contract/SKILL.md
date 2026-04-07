---
description: "Zero-downtime expand-contract pattern for breaking changes."
user-invocable: false
icon: 🔄
model: haiku
effort: low
---

# Expand-Contract

Pattern for making breaking changes safely with zero downtime. The system supports both old and new throughout the migration.

## The 3 Phases

### 1. Expand (add new alongside old)
- Add new implementation/column/field/service alongside the old
- Implement dual-write: write to BOTH old and new
- Deploy and verify both paths work in production
- Backfill existing data to new format if needed

Zero users are affected. System continues working with old.

### 2. Migrate (switch to new)
- Update readers/consumers to use new path
- Deploy incrementally (feature flag, canary, percentage rollout)
- Monitor for errors and performance issues
- Keep dual-write active as safety net

System now uses new, but still maintains old as backup.

### 3. Contract (remove old)
- Stop writing to old path
- Deploy and monitor — verify old path has ZERO usage for days/weeks
- Remove old code/column/service
- Clean up migration/compatibility code

Only remove after old path has confirmed zero usage.

## When to Apply

| Change | Example | Expand | Migrate | Contract |
|--------|---------|--------|---------|----------|
| Rename DB column | `email` → `email_address` | Add new column + dual-write | Switch reads to new | Drop old column |
| Change data type | String → JSON object | Add new column + parse/backfill | Switch to new format | Drop old column |
| API field rename | `userName` → `username` | Return both fields | Deprecate old, notify consumers | Remove old field |
| Replace service | SendGrid → AWS SES | Add new service + dual-call | Route traffic % to new | Remove old service |
| Replace library | Lodash → Native JS | Add new code alongside old | Migrate callers incrementally | Remove old library |
| Refactor logic | `calculate_v1` → `calculate_v2` | Implement new alongside old | Compare outputs, migrate callers | Remove old function |

## Phase Transition Criteria

Before moving to **Migrate**:
- Dual-write is working (data going to both old and new)
- New path is fully functional in production
- Monitoring shows both paths are healthy
- Rollback plan is clear

Before moving to **Contract**:
- Old path has ZERO usage (verified via logs/monitoring)
- New path has been stable for days/weeks
- No errors related to old path

## Anti-Patterns

- **Big bang migration** — Switching everything at once instead of gradually
- **Premature contract** — Removing old path before confirming zero usage
- **Missing dual-write** — Only writing to new, losing data if rollback needed
- **Skipping monitoring** — Not verifying both paths work before migrating

---

**Attribution:** Adapted from Praxis by Antonio Acuña (https://github.com/acunap/praxis), MIT License.
