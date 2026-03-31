---
description: "Challenges a technical proposal against 30 complexity dimensions."
user-invocable: false
icon: 📐
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
6. **Open Questions** — assumptions that need data before the design is locked

End with a recommendation: proceed with original / proceed with simplified /
gather more data before deciding.

---

**Attribution:** Adapted from Praxis by Antonio Acuña (https://github.com/acunap/praxis), MIT License.
