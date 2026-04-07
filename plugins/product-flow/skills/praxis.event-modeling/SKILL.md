---
description: "Decomposes event-driven features into independently testable slices."
user-invocable: false
icon: 📊
model: sonnet
effort: high
---

# Event Modeling

A set of vertical slices that fully describe a system's behavior. Each slice is independently implementable and testable. The model uses business language throughout — no infrastructure or technical terms.

## Slice Types

Three types. Every behavior in the system fits one:

**STATE_CHANGE** — user does something
- Screen → Command → Event
- Command produces one or more events
- May have error events for failure paths

**STATE_VIEW** — system shows something
- Events → Read Model → Screen
- Read model aggregates data from one or more events

**AUTOMATION** — system reacts to something
- Event → Processor → Command → Event
- Background process, no user interaction

## Design Process

1. **Understand the domain** — Identify aggregates (core business entities), actors, and high-level use cases. Ask about business processes, not technical implementation.
2. **High-level model** — Draft all slices without field details. Show the flow between them — which events feed which read models, which screens lead to which commands. Format as markdown with one section per slice.
3. **Slice detail** — Walk through one slice at a time. Define fields with types and example values. Identify business rules (real domain rules, not simple validations). Write specifications as Given/When/Then scenarios.
4. **Executable specifications** — Turn specifications into approval fixture files using the `bdd-with-approvals` skill. The event model specs (Given events / When command / Then events) map naturally to the approved fixture pattern.

**Existing codebases:** Read the code to extract domain concepts. Map operations to slice types (writes → STATE_CHANGE, reads → STATE_VIEW, background → AUTOMATION). Extract specs from unit tests and comments.

## Output Format

Produce markdown. Design for human readability.

Write model artifacts to `specs/<BRANCH_NAME>/event-model.md`. Derive `BRANCH_NAME` from `git branch --show-current`. Update the file as the model evolves.

**High-level model:**

```markdown
# [System Name] Event Model

## Aggregates
- Owner — pet owners who use the clinic
- Pet — animals registered to owners

## Slices

### Register Owner [STATE_CHANGE]
Aggregate: Owner
Screen: Owner Registration Form
Command: Register Owner → Event: Owner Registered
Error: → Owner Registration Failed

### View Owner Profile [STATE_VIEW]
Aggregate: Owner
Events: Owner Registered, Pet Registered → Read Model: Owner Profile
Screen: Owner Profile

### Notify Vet of New Patient [AUTOMATION]
Trigger: Pet Registered → Processor: New Patient Notifier
Command: Send Notification → Event: Vet Notified
```

**Detailed slice:**

```markdown
## Register Owner [STATE_CHANGE]
Aggregate: Owner

### Command: Register Owner
  firstName: String — "George"
  lastName: String — "Franklin"
  address: String — "110 W. Liberty St."
  city: String — "Madison"
  telephone: String — "6085551023"

### Event: Owner Registered
  ownerId: UUID — <generated>
  firstName: String — "George"
  ...

### Specifications

#### Successfully register with valid data
Given: (no prior state)
When: Register Owner
  firstName: George, lastName: Franklin
Then: Owner Registered
  ownerId: <generated>, firstName: George

#### Business rules
- All fields mandatory: firstName, lastName, address, city, telephone
- Telephone must be numeric, max 10 digits
```

## Question Handling

Any time a question or decision arises during this session, classify it before acting:

**Technical** — architecture, integration patterns, infrastructure, data storage, performance, security:
1. Resolve using project context: existing code, `.agents/rules/base.md`, detected stack, industry standards.
2. Post a PR comment via `/product-flow:pr-comments write` with `type: technical`, `status: ANSWERED`, including the chosen answer and reasoning.
3. Continue without asking the user.
4. If it cannot be resolved with available context: post with `status: UNANSWERED` and continue.

**Product** — business rules, domain terminology, actor responsibilities, slice scope, acceptance criteria:
1. Ask the user directly in chat. One question at a time.
2. Once answered, post a PR comment via `/product-flow:pr-comments write` with `type: product`, `status: ANSWERED`, recording the question and the user's answer.
3. Continue with the confirmed decision.

Never ask the user a technical question. Never silently drop a decision without a PR comment.

## Anti-Patterns

- Technical language in element names ("insertOwnerRecord" → "Register Owner")
- Skipping STATE_VIEW slices — every query/display is a slice
- Circular dependencies between elements
- Specs that test simple validation instead of business rules
- Jumping to fixture format before the model is understood
- Combining multiple commands in one slice — one command per STATE_CHANGE

---

**Attribution:** Adapted from Praxis by Antonio Acuña (https://github.com/acunap/praxis), MIT License.
