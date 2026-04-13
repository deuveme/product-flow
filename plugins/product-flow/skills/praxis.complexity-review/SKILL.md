---
description: "Challenges a technical proposal against 30 complexity dimensions."
user-invocable: false
icon: 📐
model: opus
effort: high
---

## User Input

```text
$ARGUMENTS
```

If the user provides a proposal or describes a design, evaluate that. Otherwise, ask:
"What technical proposal or design should I review?"

---

## Complexity Review Framework

Evaluate the proposal against 30 complexity dimensions across 6 categories. For each
dimension that applies, ask: **"Do we have data showing we need this?"**

### Category 1 — Data Volume and Nature
- Expected data volume at launch vs. in 12 months
- Read/write ratio
- Data structure variability (structured vs. unstructured)
- Retention and archiving requirements
- Privacy and regulatory constraints

### Category 2 — Interaction and Frequency
- Request frequency (req/s at p50 and p99)
- Latency requirements (is <500ms sufficient, or is <50ms needed?)
- Batch vs. real-time processing
- Synchronous vs. asynchronous interactions
- Peak load patterns

### Category 3 — Consistency, Order, Dependencies
- Strong consistency requirement vs. eventual consistency acceptable
- Event ordering requirements
- Distributed transaction needs
- Rollback and compensating transaction needs
- Cross-service dependency chains

### Category 4 — Resilience and Fault Tolerance
- Acceptable downtime (99.9% vs. 99.999%)
- Failure modes and recovery paths
- Data loss tolerance (RPO/RTO)
- Circuit breaker and retry requirements
- Disaster recovery requirements

### Category 5 — Integration and External Dependencies
- Number of external services/APIs
- Versioning and compatibility constraints
- Vendor lock-in risk
- Integration testing surface area
- SDK/library maturity and maintenance risk

### Category 6 — Efficiency and Maintainability
- Team familiarity with proposed stack
- Operational complexity (monitoring, alerting, deployments)
- Onboarding cost for new engineers
- Debugging and observability difficulty
- Long-term evolution flexibility

### Category 7 — Delivery Risk
- **Incremental delivery**: Can the feature be split into phases (e.g. MVP → full) where each phase delivers independent value? If yes, identify the natural cut point.
- **Delivery risks**: Are there unresolved technical unknowns, missing external contracts, or ambiguous requirements that could block implementation mid-sprint?
- **Reversibility**: If the feature fails in production, can it be rolled back cleanly? Consider: feature flags, backward-compatible data migrations, stateless vs. stateful changes, blast radius of a rollback.

---

## Basal Cost Analysis

For each major component proposed (e.g., a message broker, a separate service, a
caching layer), estimate its **basal cost**: the ongoing team capacity consumed
simply by its existence, independent of feature work.

Ask:
- How many hours/week does this component consume in monitoring, incidents, and
  maintenance?
- Does this push team capacity into the "complexity trap" (>70% on maintenance)?

---

## Simplification Challenge

Propose **three progressively simpler alternatives**:

1. **Simplest** — deployable in 1-3 days, sufficient for current known load
2. **Moderate** — adds one layer of sophistication, justified by a specific data point
3. **Original** — the proposed design, with its complexity fully justified

For common over-engineering patterns, apply these alternatives:

| Proposed | Challenge with |
|---|---|
| Kafka / message broker | PostgreSQL + polling, pg_notify, or a simple job queue |
| Microservices | Modular monolith with clear package boundaries |
| Event sourcing | Standard CRUD with an audit log table |
| Redis cache | DB query optimization + indexed reads |
| Real-time WebSockets | Polling every N seconds |
| Separate service | Module within the existing FastAPI app |

---

## Deferral Candidates

Identify components that can be **deferred** until usage patterns are observed:

- List each deferrable element
- State what signal (metric, load, user feedback) would justify introducing it
- Estimate when that signal would realistically be reached

---

## Output Format

Produce:

1. **Complexity Score** — a brief assessment (Low / Medium / High / Very High) with
   a one-sentence rationale
2. **Top 3 Complexity Drivers** — the dimensions that contribute most risk
3. **Basal Cost Summary** — estimated weekly team burden per major component
4. **Recommended Alternative** — which of the three simplified alternatives you
   recommend, and why
5. **Deferral List** — components that can be added later with clear triggers
6. **Delivery Risk** — one of: `LOW` / `MEDIUM` / `HIGH`, with:
   - Incremental delivery: proposed phase cut (or "ships as a single unit")
   - Delivery risks: list of blockers/unknowns, or "none identified"
   - Reversibility: `clean` / `partial` / `risky` with a one-line rationale
7. **Open Questions** — assumptions that need data before the design is locked

End with a recommendation: proceed with original / proceed with simplified /
gather more data before deciding.

---

## Question Handling

After producing the output, resolve all Open Questions before finishing:

**Technical** (architecture, performance, infrastructure, data model, security):
1. Resolve autonomously using project context, existing code, and industry standards.
2. Post a PR comment via `/product-flow:pr-comments write` with `type: technical`, `status: ANSWERED`, including the chosen answer and reasoning. If it cannot be resolved: post with `status: UNANSWERED`.
3. Record the decision in `specs/<branch>/research.md` (create if needed) under a `## Complexity Review Decisions` section.

**Product** (business priorities, scope, user requirements, feature boundaries):
1. Collect all product open questions and ask the PM in a **single AskUserQuestion call** (one entry per question).
2. Post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`, recording the question and the PM's answer.
3. Record the decision in `specs/<branch>/research.md` under `## Complexity Review Decisions`.

Never ask the user a technical question. Never silently drop a decision without a PR comment.

---

**Attribution:** Adapted from Praxis by Antonio Acuña (https://github.com/acunap/praxis), MIT License.
