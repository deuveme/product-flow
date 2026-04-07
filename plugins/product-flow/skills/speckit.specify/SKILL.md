---
description: "Creates or updates the feature spec from a natural language description."
user-invocable: false
model: sonnet
effort: high
handoffs:
  - label: Build Technical Plan
    agent: speckit.plan
    prompt: Create a technical plan for the spec.
  - label: Clarify Spec Requirements
    agent: speckit.clarify
    prompt: Clarify specification requirements
    send: true
  - label: Analyze Split
    agent: speckit.split
    prompt: Analyze if this spec should be split
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

The text the user typed after `/product-flow:speckit.specify` in the triggering message **is** the feature description. Assume you always have it available in this conversation even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

Given that feature description, do this:

1. **Generate a concise short name** (2-4 words) for the branch:
   - Analyze the feature description and extract the most meaningful keywords
   - Create a 2-4 word short name that captures the essence of the feature
   - Use action-noun format when possible (e.g., "add-user-auth", "fix-payment-bug")
   - Preserve technical terms and acronyms (OAuth2, API, JWT, etc.)
   - Keep it concise but descriptive enough to understand the feature at a glance
   - Examples:
     - "I want to add user authentication" → "user-auth"
     - "Implement OAuth2 integration for the API" → "oauth2-api-integration"
     - "Create a dashboard for analytics" → "analytics-dashboard"
     - "Fix payment processing timeout bug" → "fix-payment-timeout"

2. **Check for existing branches before creating new one**:

   **FIRST**: Run `git branch --show-current`. If the current branch already matches the feature branch pattern `^[0-9]+-[a-z]` (e.g., `001-user-auth`, `042-fix-payments`):
   - Set `BRANCH_NAME` = current branch name
   - Set `SPEC_FILE` = `specs/$BRANCH_NAME/spec.md`
   - **Skip steps 2a–2d entirely** and go directly to step 3.

   Otherwise, continue with branch creation:

   a. First, fetch all remote branches to ensure we have the latest information:

      ```bash
      git fetch --all --prune
      ```

   b. Find the highest feature number across all sources:
      - Remote branches: `git ls-remote --heads origin | grep -E 'refs/heads/[0-9]+-'`
      - Local branches: `git branch | grep -E '^[* ]*[0-9]+-'`
      - Specs directories: Check for directories matching `specs/[0-9]+-`

   c. Determine the next available number:
      - Extract all numbers from all three sources
      - Find the highest number N
      - Use N+1 for the new branch number, zero-padded to 3 digits: `printf "%03d" $((N+1))`
      - If no existing branches/directories found, use `001`

   d. Run the script `.specify/scripts/bash/create-new-feature.sh --json "$ARGUMENTS"` with the calculated number and short-name:
      - Pass `--number NNN` (zero-padded, e.g. `005`) and `--short-name "your-short-name"` along with the feature description
      - Example: `.specify/scripts/bash/create-new-feature.sh --json "$ARGUMENTS" --number 005 --short-name "user-auth"`
      - If the script exits with a non-zero code, output is empty, or the output cannot be parsed as valid JSON with `jq`, stop immediately with: ERROR "create-new-feature.sh failed or returned invalid output: <error details>. Check the script and try again."
      - Validate the parsed JSON contains both `BRANCH_NAME` and `SPEC_FILE` fields before proceeding.

   **IMPORTANT**:
   - Check all three sources (remote branches, local branches, specs directories) to find the highest number
   - Only match branches/directories with the exact short-name pattern
   - Branch names always use a zero-padded 3-digit number: `001-user-auth`, `042-fix-payments`
   - You must only ever run this script once per feature
   - The JSON is provided in the terminal as output - always refer to it to get the actual content you're looking for
   - The JSON output will contain BRANCH_NAME and SPEC_FILE paths
   - For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot")

3. Load `.specify/templates/spec-template.md` to understand required sections.

3.5. **Detect redesign intent**:

Scan the feature description for visual or UX redesign signals. Keywords include: "redesign", "rediseño", "new look", "new design", "visual overhaul", "UI revamp", "rework the UI", "rework the UX", "visual refresh", "new interface", "change the look", "change the UI", "new layout".

If any are found, set `REDESIGN_MODE = true` and apply these rules for the rest of this skill:
- The **goal** is a new target visual/UX state, not new functionality.
- The fact that functionality already exists is the **starting baseline** — it does NOT reduce scope or mean there is nothing to do.
- Functional requirements must describe **what changes** in the user experience (interactions, layout, flows, visual outcomes) — not re-describe how the current system behaves.
- Success criteria must be UX/visual outcomes (e.g., "users complete the task in X fewer steps", "the interface follows the new design system", "task completion rate improves by X%").
- Do NOT write a spec that merely restates the current system's behavior.

3.6. **Normalize input — separate functional intent from technical detail**:

Scan the feature description for technical implementation signals: framework or library names (React, Django, Postgres, Redis…), method or class names (camelCase, PascalCase), API endpoints (`/api/…`), SQL or data-layer terms (JOIN, migration, schema, foreign key…), architectural patterns (REST, microservices, event sourcing…), infrastructure terms (Docker, Kubernetes, S3…).

If technical signals are detected:
- Extract the **functional intent**: what the user wants to achieve, for whom, and why.
- Write the extracted technical details to `specs/$BRANCH_NAME/technical-context.md` in this format:
  ```markdown
  # Technical Context

  > Extracted from the original feature description. Use this as a starting point for research.md in the planning phase — do not copy it into the spec.

  ## Details provided by the user

  <bullet list of technical details extracted>
  ```
- Use only the functional intent as input for writing the spec from this point forward.
- Do NOT ask the user to re-explain — infer the functional intent from the description as written.

If no technical signals are detected: proceed normally.

3.6b. **Clarify business terminology**:

Scan the feature description for terms that are central to the feature logic AND whose exact meaning could vary by business context. These include — but are not limited to:

- Financial terms: payment states, debt, interest, fees, balances, amortization schedules, refunds, charges
- Operational states: approval, rejection, cancellation, expiry, suspension, activation
- Business-specific statuses or flows that name a concept without defining it (e.g. "mora", "vencimiento", "liquidación", "anticipo")
- Any term that appears to be an internal company concept (proper nouns, acronyms, compound nouns not found in general dictionaries)

For each such term found that is **central to the feature** (drives logic, conditions, or data):

1. Do NOT assume you know the definition — even if the term exists in general language, the business meaning may differ.
2. Collect all ambiguous terms (max 3, prioritised by how central they are to the feature logic).
3. Ask the user via **AskUserQuestion** — one question per term, all in a single call:
   - `question`: "What does '[term]' mean in your context?" with a brief explanation of why it matters for the spec.
   - `header`: the term itself (max 12 chars)
   - `options`: 2–3 plausible interpretations as starting points, with a "None of these / I'll describe it" option last.
   - `multiSelect`: false
4. Wait for answers. Use them as authoritative definitions when writing the spec — do not reinterpret or override them.

If no ambiguous terms are found: proceed without asking.

3.7. **Fill gaps and confirm understanding before writing**:

First, assess whether the description contains the three essential elements:
- **Actor**: who performs the action (user, admin, system…)
- **Action**: what they want to do
- **Outcome**: why — what value or result it produces

If any element is missing or too vague to infer, ask for it directly before continuing. Use **AskUserQuestion**, one question per missing element (max 3), all in a single call:
- `question`: ask specifically for the missing element with a brief example.
- `header`: "Actor", "Action", or "Outcome"
- `options`: 2–3 plausible answers as starting points, plus a "Let me describe it" option last.
- `multiSelect`: false

Wait for the user's answers before continuing.

Then, show a one-paragraph summary of what you understood:

```
📋 Here's what I understood:

**Goal:** <functional intent in one sentence — who does what and why>
<if technical details were extracted:>
**Technical details:** set aside for the planning phase (saved to technical-context.md)

Does this look right? (yes to continue / correct me if something is off)
```

Wait for the user's response:
- If **yes** or equivalent: proceed to step 4.
- If the user corrects something: update your understanding and show the summary again. Repeat until confirmed.

Skip this step if `collaborative-design.md` was loaded in step 3.8 — in that case the intent has already been validated through the design session.

3.8. **Load collaborative design context (if available)**:

   ```bash
   cat specs/$BRANCH_NAME/collaborative-design.md 2>/dev/null
   ```

   If the file exists, read it and use its content (scenarios, decisions, vertical slices) as primary context when writing the spec. The collaborative design captures decisions already agreed with the user — do not contradict or re-ask about them.

4. Follow this execution flow:

    1. Parse user description from Input
       If empty: ERROR "No feature description provided"
    2. Extract key concepts from description
       Identify: actors, actions, data, constraints
    3. For unclear aspects:
       - Make informed guesses based on context and industry standards
       - Only mark with [NEEDS CLARIFICATION: specific question] if:
         - The choice significantly impacts feature scope or user experience
         - Multiple reasonable interpretations exist with different implications
         - No reasonable default exists
       - Ask every question that genuinely needs asking — do not guess to avoid asking. The filter is quality, not quantity.
       - Prioritize clarifications by impact: scope > security/privacy > user experience > technical details
    4. Fill User Scenarios & Testing section
       If no clear user flow: ERROR "Cannot determine user scenarios"
    5. Generate Functional Requirements
       Each requirement must be testable
       Use reasonable defaults for unspecified details (document assumptions in Assumptions section)
    6. Define Success Criteria
       Create measurable, technology-agnostic outcomes
       Include both quantitative metrics (time, performance, volume) and qualitative measures (user satisfaction, task completion)
       Each criterion must be verifiable without implementation details
    7. Identify Key Entities (if data involved)
    8. Return: SUCCESS (spec ready for planning)

5. Write the specification to SPEC_FILE using the template structure, replacing placeholders with concrete details derived from the feature description (arguments) while preserving section order and headings.

6. **Specification Quality Validation**: After writing the initial spec, validate it against quality criteria:

   a. **Create Spec Quality Checklist**: Generate a checklist file at `FEATURE_DIR/checklists/requirements.md` using the checklist template structure with these validation items:

      ```markdown
      # Specification Quality Checklist: [FEATURE NAME]

      **Purpose**: Validate specification completeness and quality before proceeding to planning
      **Created**: [DATE]
      **Feature**: [Link to spec.md]

      ## Content Quality

      - [ ] No implementation details (languages, frameworks, APIs)
      - [ ] Focused on user value and business needs
      - [ ] Written for non-technical stakeholders
      - [ ] All mandatory sections completed

      ## Requirement Completeness

      - [ ] No [NEEDS CLARIFICATION] markers remain
      - [ ] Requirements are testable and unambiguous
      - [ ] Success criteria are measurable
      - [ ] Success criteria are technology-agnostic (no implementation details)
      - [ ] All acceptance scenarios are defined
      - [ ] Edge cases are identified
      - [ ] Scope is clearly bounded
      - [ ] Dependencies and assumptions identified

      ## Feature Readiness

      - [ ] All functional requirements have clear acceptance criteria
      - [ ] User scenarios cover primary flows
      - [ ] Feature meets measurable outcomes defined in Success Criteria
      - [ ] No implementation details leak into specification

      ## Notes

      - Items marked incomplete require spec updates before `/product-flow:speckit.clarify` or `/product-flow:speckit.plan`
      ```

   b. **Run Validation Check**: Review the spec against each checklist item:
      - For each item, determine if it passes or fails
      - Document specific issues found (quote relevant spec sections)

   c. **Handle Validation Results**:

      - **If all items pass**: Mark checklist complete and proceed to step 6

      - **If items fail (excluding [NEEDS CLARIFICATION])**:
        1. List the failing items and specific issues
        2. Update the spec to address each issue
        3. Re-run validation until all items pass (max 3 iterations)
        4. If still failing after 3 iterations, document remaining issues in checklist notes and warn user

      - **If [NEEDS CLARIFICATION] markers remain**:
        1. Extract all [NEEDS CLARIFICATION: ...] markers from the spec
        2. **Classify each marker** as Technical or Product:
           - **Technical** (authentication, authorisation, security, compliance, data retention, integration patterns, infrastructure): resolve autonomously using project context, `.agents/rules/base.md`, and industry standards. For each, invoke `/product-flow:pr-comments write`:
             - Resolved: `type: technical`, `status: ANSWERED`, body with chosen answer and reasoning.
             - Unresolved: `type: technical`, `status: UNANSWERED`, body with possible options.
             - Do NOT include technical markers in the AskUserQuestion call.
           - **Product** (business intent, functional scope, user flows, terminology, acceptance criteria): collect all of them and present via **AskUserQuestion** in a single call:
             - `question`: the specific question from the marker, with brief context prepended if needed. Must end with "?"
             - `header`: short topic label max 12 chars (e.g. "Scope", "User roles", "Auth")
             - `options`: 2–4 suggested answers. Place the best-practice default **first** and append `" (Recommended)"` to its label. Each option's `description` = implications for the feature.
             - `multiSelect`: false
             - The tool adds "Other" automatically for custom answers.
        4. Wait for the user's answers via the tool response (product questions only).
        5. Update the spec by replacing each [NEEDS CLARIFICATION] marker with the resolved answer (auto or user-provided).
        6. Re-run validation after all clarifications are resolved

   d. **Update Checklist**: After each validation iteration, update the checklist file with current pass/fail status

7. Report completion with branch name, spec file path, checklist results, and readiness for the next phase (`/product-flow:speckit.clarify` or `/product-flow:speckit.plan`).

**NOTE:** The script creates and checks out the new branch and initializes the spec file before writing.

## Quick Guidelines

- Focus on **WHAT** users need and **WHY**.
- Avoid HOW to implement (no tech stack, APIs, code structure).
- Written for business stakeholders, not developers.
- DO NOT create any checklists that are embedded in the spec. That will be a separate command.

### Section Requirements

- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation

When creating this spec from a user prompt:

1. **Make informed guesses**: Use context, industry standards, and common patterns to fill gaps
2. **Document assumptions**: Record reasonable defaults in the Assumptions section
3. **Ask what genuinely needs asking**: Use [NEEDS CLARIFICATION] for any decision that:
   - Significantly impacts feature scope or user experience
   - Has multiple reasonable interpretations with different implications
   - Lacks any reasonable default
   Do not guess to avoid asking — ask every question that would change the spec if answered differently.
4. **Prioritize clarifications**: scope > security/privacy > user experience > technical details
5. **Think like a tester**: Every vague requirement should fail the "testable and unambiguous" checklist item
6. **Common areas needing clarification** (only if no reasonable default exists):
   - Feature scope and boundaries (include/exclude specific use cases)
   - User types and permissions (if multiple conflicting interpretations possible)
   - Security/compliance requirements (when legally/financially significant)

**Examples of reasonable defaults** (don't ask about these):

- Data retention: Industry-standard practices for the domain
- Performance targets: Standard web/mobile app expectations unless specified
- Error handling: User-friendly messages with appropriate fallbacks
- Authentication method: Standard session-based or OAuth2 for web apps
- Integration patterns: Use project-appropriate patterns (REST/GraphQL for web services, function calls for libraries, CLI args for tools, etc.)

### Success Criteria Guidelines

Success criteria must be:

1. **Measurable**: Include specific metrics (time, percentage, count, rate)
2. **Technology-agnostic**: No mention of frameworks, languages, databases, or tools
3. **User-focused**: Describe outcomes from user/business perspective, not system internals
4. **Verifiable**: Can be tested/validated without knowing implementation details

**Good examples**:

- "Users can complete checkout in under 3 minutes"
- "System supports 10,000 concurrent users"
- "95% of searches return results in under 1 second"
- "Task completion rate improves by 40%"

**Bad examples** (implementation-focused):

- "API response time is under 200ms" (too technical, use "Users see results instantly")
- "Database can handle 1000 TPS" (implementation detail, use user-facing metric)
- "React components render efficiently" (framework-specific)
- "Redis cache hit rate above 80%" (technology-specific)
