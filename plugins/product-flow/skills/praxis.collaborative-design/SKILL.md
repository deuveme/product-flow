---
description: "Explores ambiguous features through visual scenarios before the spec."
user-invocable: false
---
icon: 🎨

# Collaborative Design

Stay in design mode. Resist jumping to implementation. Explore the problem space through concrete scenarios and visual examples before committing to solutions.

## Show, Don't Tell

Show it visually. Before/after states, input/output pairs, workflow diagrams. Visual beats prose.

## Process

```
Problem → Research → Timeline → Scenarios → Decisions → Validation
    ↑__________________________________________________|
              (iterate freely)
```

1. **Clarify** — What are we building? Why? What does success look like? What constraints exist?
2. **Research** — Analyze existing patterns, check real-world examples, validate assumptions.
3. **Timeline** — Walk through what happens in order. What first? Then what? What triggers the next step? Each step becomes a scenario to explore.
4. **Scenarios** — Show the transformation or state change visually. Format depends on domain:
   - Config/data: before and after
   - UI: screen states and transitions
   - Pipelines: input → output
   - Workflows: steps with arrows
5. **Options** — Present several options with tradeoffs. Don't decide alone. Wait for input before proceeding.
6. **Validate** — POC for risky assumptions. Visual test cases. Document findings.
7. **Document** — Track what was decided and why. Update as design evolves.

## Story Splitting

Before slicing, check if the work is actually multiple things bundled together.

**Red flags** — words that signal a story is too big:
- **"and", "or"** — "upload and download files" → 2 stories
- **"manage", "handle"** — "manage users" hides create, edit, delete, list
- **"including", "also", "with"** — scope expansion, separate the extras
- **"before", "after", "then"** — sequential steps bundled together
- **"either/or", "optionally"** — multiple alternatives, each is a story
- **"except", "unless"** — base case + exception, split them

**Splitting heuristics:**
- Start with outputs — deliver specific outputs incrementally, not all at once
- Narrow customer segment — full functionality for a smaller group first
- Extract basic utility — bare minimum to complete the task, improve usability later
- Simplify outputs — CSV before PDF, console before UI, one format before many
- Split by capacity — support 1MB first, then 10MB, then unlimited

## Vertical Slicing

When a feature needs to be broken into deliverable pieces:

1. **Identify layers** — List 3-6 functional steps of the feature (e.g., "detect event", "notify user", "record status"). Layers describe what happens, not where it runs — avoid technical splits like "frontend/backend/database".
2. **Generate 4-5 options per layer** — From simplest to most complete, using the quality gradient: manual → scripted → automated → scalable → enterprise
3. **Compose the smallest slice** — Pick one option per layer (usually level 1-2) that together deliver value end-to-end

Force radical slicing by asking: "If you had to ship by tomorrow, what would you build?"

Distinguish learning steps (time-boxed research to reduce uncertainty) from earning steps (deliver working software). Learning before earning.

**Example** — "User uploads a document and receives a summary by email":

| Layer | Manual | Scripted | Automated | Scalable |
|-------|--------|----------|-----------|----------|
| Receive document | Copy file to folder | Web form | Form with validation | Upload with resume support |
| Extract content | Read plain text | Parse PDF with library | Multi-format extraction | OCR for scanned docs |
| Generate summary | Write it yourself | Hardcoded prompt to LLM | Tuned prompt with chunking | Fine-tuned model |
| Deliver result | Send email manually | Script sends email | SMTP service with template | Multi-channel with tracking |

Smallest slice: all manual except "hardcoded prompt to LLM" — ship in hours.

## Anti-Patterns

- Jumping to code before exploring the design space
- Describing scenarios in prose instead of showing them
- Showing one solution instead of options
- Making assumptions without checking real data
- Truncating examples — show complete data
- Deciding without discussing tradeoffs
- Steps that need more slicing — watch for: "then we also need to...", "while we're at it...", "first we have to...", or multiple verbs in one step

## Exit Criteria

- Problem is understood
- Key scenarios walked through visually
- Major decisions made and documented
- Risky assumptions validated

Then: hand off to `speckit.specify`.

---

**Attribution:** Adapted from Praxis by Antonio Acuña (https://github.com/acunap/praxis), MIT License.
