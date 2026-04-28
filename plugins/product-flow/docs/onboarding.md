# Working guide — How everything works

Welcome to the team. This guide explains how we work, where the work you create lives, and how we collaborate without stepping on each other's toes.

You don't need to know anything about programming or git to follow this guide.

---

## The four boxes

All work exists in one of these four places. At any given moment you can know exactly where what you're working on is.

```
🖥️  YOUR COMPUTER       🔄  REVIEW ROOM            🧪  INTERNAL TESTING     🌍  THE REAL WORLD
    (local)                  (GitHub PR)                 (staging)                 (production)

  Your work              What you've               What you test             What users
  in progress            shared for the            together before           see
                         team to review            publishing

  Only you see it        The team and you see it   The whole team sees it    Everyone sees it
```

### Where is my work right now?

- You just ran `/product-flow:start-feature` or `/product-flow:start-improvement` → **Review room** (in DRAFT — team can see and comment, but not yet asked to approve)
- You ran `/product-flow:submit` → **Review room** (out of DRAFT — team is notified for formal code review)
- The team approved and you ran `/product-flow:deploy` → **Internal testing**
- The team published → **The real world**

---

## The commands

These are the only commands you need. Type them in Claude Code exactly as they appear here.

### `/product-flow:start-feature`
**When to use it:** When you want to build something new — a feature that doesn't exist yet.

Type `/product-flow:start-feature` followed by a description of what you want to build. Claude takes care of everything else: creates your workspace, opens the review room as a **DRAFT**, and prepares the spec.

```
/product-flow:start-feature I want users to be able to reset their password
```

After this, share the review room link with the team on Slack so they can read and comment on the spec.

---

### `/product-flow:start-improvement`
**When to use it:** When something already exists in production and you want to make a small change to it — a redesign, a copy update, a behaviour fix, or a UX tweak.

Type `/product-flow:start-improvement` followed by a description of what you want to change. Claude uses a lighter process than `start-feature`: no event modeling, no architecture review, no checklist phase. The result is still a PR with a spec and plan for the team to review.

```
/product-flow:start-improvement The empty state on the dashboard needs better copy and a call-to-action button
```

If Claude determines the change is actually a new feature (too large for an improvement), it will tell you and suggest switching to `/product-flow:start-feature` instead.

After this, share the review room link with the team on Slack so they can read and comment on the spec.

---

### `/product-flow:continue`
**When to use it:** Every time the team has commented on the spec or plan and you want to move forward.

Claude reads the current state of your feature and automatically does what's needed:
- If there are comments on the spec → integrates feedback, asks you product questions
- If the spec is ready → generates the technical plan
- If there are comments on the plan → integrates feedback
- If the plan is ready → tells you to run `/product-flow:build`

You can run it as many times as needed. The review room stays in **DRAFT** throughout.

---

### `/product-flow:build`
**When to use it:** When `/product-flow:continue` tells you the plan is ready and you want Claude to write the code.

Claude generates all the feature code. The review room is still in **DRAFT** while this runs. Requires the plan to be approved — if it isn't, it will let you know.

---

### `/product-flow:submit`
**When to use it:** When the code is generated and you want the team to do a formal code review.

The first time you run this, the review room **exits DRAFT** and the team receives a notification to review the code. You can run it as many times as you want if you need to iterate — each time, the team sees the most recent changes.

---

### `/product-flow:fix`
**When to use it:** When you test the feature and find something that doesn't work as expected — or when the team's code review finds issues that need correcting.

Claude walks you through the diagnosis: what's wrong, where in the spec or plan it comes from, and why it happened. Once you confirm, it fixes the code using the same TDD standards as the original build and re-verifies everything. You can run it as many times as needed — one fix cycle per issue. When all fixes are done, run `/product-flow:submit` to update the team.

Can be called after `/product-flow:build` (before submitting) or after `/product-flow:submit` (if the team found issues during review).

---

### `/product-flow:deploy`
**When to use it:** When the team has approved the code and you want to send it to internal testing.

The team will be able to see and test your feature in the testing environment before publishing it to real users. Requires the PR to be approved — if it isn't, it will let you know.

---

### `/product-flow:status`
**When to use it:** When you're not quite sure where you are or what you have pending.

Tells you, in plain language, where you are in the workflow and what the next step is.

---

### `/product-flow:context`
**When to use it:** When you want to know how much memory Claude has left in this session.

---

## How PR comments work

### Leaving feedback

You and the team leave feedback by adding comments in the review room on GitHub. Every time you run `/product-flow:continue`, `/product-flow:build`, or `/product-flow:submit`, Claude checks for new activity first — answers to existing questions and any new comments — and processes them before doing anything else.

Claude classifies each comment automatically:

**Your comments (product)** — questions about business intent, priorities, user flows, terminology, or functional scope. Claude will **always ask you** before making any decision. It will never resolve these autonomously.

**Dev team comments** — questions about architecture, security, integrations, data model, or technical constraints. Claude resolves these autonomously without bothering you, and records each decision as a comment on the PR so the team can see the reasoning.

If Claude cannot resolve a technical question on its own, it posts it in the PR marked as unresolved so the dev team can answer it directly.

Once a comment is processed, Claude adds a 👍 reaction to it on GitHub as a signal that it was seen and handled.

### What you might see after running any public command

Claude may post comments on the PR like this:

> **Technical question detected:** "Which caching strategy should we use?"
>
> **Autonomously chosen answer:** We chose Redis with TTL of 5 minutes because…
>
> 💬 To change this decision, add a new comment: `Question 3. Answer: [your answer]`

You don't need to act on these unless you want to change the decision. If you do, add a **new comment** to the PR (not a reply) with the question number. For example: `Question 3. Answer: I prefer option A`.

### Code review comments (after `/product-flow:submit`)

Once the review room exits DRAFT, the team does a formal code review. These comments are handled differently — they go directly to the developer or back to Claude for a new iteration. If you run `/product-flow:submit` again after fixing things, the team sees the updated code.

---

## How multiple people collaborate on the same spec

### The rounds model

The spec is not written by everyone at once. It advances in rounds:

```
Round 1 ── The person who opens the feature writes the initial spec draft with /product-flow:start-feature (or /product-flow:start-improvement)
               ↓
Round 2 ── The team reads and leaves comments in the review room
           (never edit the file directly)
               ↓
Round 3 ── /product-flow:continue merges all the comments
               ↓
Round 4 ── Final review before moving to the technical plan
```

### In practice

- **You write the spec** → notify the team on Slack with the link to the PR
- **You receive the notification** → go to the review room on GitHub → leave your comments
- **Once everyone has commented** → whoever opened the feature runs `/product-flow:continue`
- **Final review** → the team approves on GitHub before continuing

---

## The complete feature lifecycle

Each step shows what happens to the review room and when to comment.

```
/product-flow:start-feature "description"   (or /product-flow:start-improvement for small changes)
        ↓
   Review room opens as DRAFT ── team can comment on the spec
        ↓
   /product-flow:continue
   — reads comments, asks you product questions, resolves technical ones
   — repeat until the spec is ready, then generates the technical plan
   — repeat again if the team comments on the plan
        ↓
   Plan approved by team ── review room still in DRAFT
        ↓
/product-flow:build → code generated ── review room still in DRAFT
        ↓
/product-flow:submit → review room exits DRAFT, team is notified for code review
        ↓
   Team reviews code and approves  ← mandatory checkpoint
        ↓
/product-flow:deploy → feature in internal testing → published
```

### What "DRAFT" means

The review room is in **DRAFT** from the moment `/product-flow:start-feature` (or `/product-flow:start-improvement`) runs until you run `/product-flow:submit` for the first time. During this time:

- The team **can see the review room** and leave comments
- The team **is not asked to approve** anything yet
- All spec and plan work happens here

When you run `/product-flow:submit`, the review room exits DRAFT and the team receives a notification to do a formal code review.

### When to comment at each step

| Phase | Who comments | What to comment on |
|---|---|---|
| After `/product-flow:start-feature` or `/product-flow:start-improvement` | You and the whole team | The spec — does it describe the right thing? Is anything missing? |
| After plan is generated | Dev team | The technical plan — architecture, data model, APIs |
| After `/product-flow:submit` | Dev team | The code — logic, naming, edge cases |

You always add comments directly in the review room on GitHub. Never edit the spec or plan files directly — use comments so Claude can integrate them.

---

## What is the spec, the plan, and the tasks?

Each feature goes through three documents before any code is written. You will see them referenced in the review room checklist.

**Spec** — What we want to build, in product language. Describes the feature from the user's perspective: what problem it solves, what the user can do, what the expected behaviour is. This is written in the first round and is the document you review and give feedback on.

**Plan** — How we are going to build it, in technical language. Generated by Claude from the spec once it is ready. Describes the architecture, the data model, the APIs, and the technical decisions. The dev team reviews this.

**Tasks** — The list of development steps to implement the plan. Generated automatically from the plan. Each task maps to a specific piece of code. You don't need to review these.

```
Spec      → What & why    (written with /product-flow:start-feature (or start-improvement), refined with /product-flow:continue)
Plan      → How           (generated with /product-flow:continue, reviewed by dev team)
Tasks     → Step by step  (generated with /product-flow:build, not reviewed)
```

You only need to read and comment on the **spec**. The rest is for the development team.

---

## Review room status

Each review room has a checklist that indicates which phase it's in:

```
- [x] Spec created
- [x] Plan generated
- [ ] Tasks generated
- [ ] Code generated
- [ ] In code review
- [ ] Published
```

If you're not sure where you are, look at the checklist in your review room or run `/product-flow:status`.

---

## Frequently asked questions

**Can I lose work?**
No. Everything you submit is saved forever with date and time. Even if something goes wrong, it can be recovered.

**What do I do if Claude tells me there is a "conflict"?**
Contact the development team. It's the only situation where you need their direct technical help.

**After `/product-flow:build`, what is "verify-tasks"?**
It's a mandatory quality check that runs automatically after the code is generated. It confirms every completed task has real code behind it — not empty stubs or placeholders. It runs without any input from you and catches problems before the team reviews the code.

**During `/product-flow:build`, Claude is asking me questions before writing code. Is that normal?**
Yes. Before generating code, Claude runs a requirements quality check that may ask up to 5 clarification questions to make sure the spec, plan and tasks are clear and complete. Answer them as best you can — they are quick and help prevent implementation mistakes. Once the questions are done, code generation continues automatically.

**When should I use `start-feature` vs `start-improvement`?**
- Use `/product-flow:start-feature` when building something new — a capability that doesn't exist yet.
- Use `/product-flow:start-improvement` when something already exists in production and you want to make a small change: fix a label, redesign a screen, adjust a behavior. If Claude determines the change is actually bigger than an improvement, it will tell you and suggest switching.

**How much detail should I give when running `/product-flow:start-feature`?**
Write whatever you know, in your own words. You don't need to find the right level — Claude adjusts automatically:
- If your description is **vague or short**, Claude will ask you a few focused questions before writing the spec.
- If your description is **very detailed or technical**, Claude will extract the technical parts automatically and keep only the business intent for the spec. Nothing gets lost — the technical details are saved separately for the development team.

The only rule: describe **what you want to achieve and for whom**, not how to build it. The rest is handled for you.

**I want to refine the spec before sharing it with the team. How?**
Run `/product-flow:speckit.clarify` after `/product-flow:start-feature`. Claude will scan the spec, identify the most important ambiguities, and ask you up to 5 targeted questions to sharpen it. The spec is updated in place. You can then share the PR with the team as usual.

**The spec is covering too many things. Can I split it into two features?**
Yes. After `/product-flow:start-feature` writes the first spec, run `/product-flow:speckit.split`. Claude will analyze the spec, detect whether it covers independent deliverables or different user journeys, and propose a clean split. If you confirm, it trims the current spec and opens a new review room for the extracted feature — ready to continue from where the split happened.

**Can I work on two features at the same time?**
Yes, but it's better to finish one before starting another. If you need to do it, notify the development team first.

**I tested the feature and something doesn't work. What do I do?**
Run `/product-flow:fix`. Claude will ask you to describe what's wrong, cross-reference it with the spec and plan to understand where the gap is, and implement the correction using the same TDD standards as the original build. Everything is re-verified before finishing. When all fixes are done, run `/product-flow:submit` to update the team.

**How do I know if the team has reviewed what I submitted?**
`/product-flow:status` will tell you. You can also look at your review room on GitHub — the team's comments appear there.

**What is GitHub?**
It's the site where the review room lives. You don't need to go there directly — Claude manages it for you — but if you want to see the status of your feature, you can find it at github.com/[project-name].

**How do I install the plugin?**
Open your terminal, type `claude` and press Enter. Once it loads, run:

```
/plugin marketplace add https://github.com/deuveme/product-flow.git
```

Then, in the same session, run:

```
/plugin install product-flow@product-flow
```

Close the terminal and reopen Claude Code.

**How do I update the plugin?**
Open your terminal, type `claude` and press Enter. Once it loads, run:

```
/plugin update product-flow@product-flow
```

Close the terminal and reopen Claude Code.

---

*Something unclear? Ask the development team before continuing. It's better to ask than to assume.*
