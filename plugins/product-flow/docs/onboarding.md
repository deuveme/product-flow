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

- You just ran `/product-flow:start` → **Review room** (in DRAFT — team can see and comment, but not yet asked to approve)
- You ran `/product-flow:submit` → **Review room** (out of DRAFT — team is notified for formal code review)
- The team approved and you ran `/product-flow:deploy-to-stage` → **Internal testing**
- The team published → **The real world**

---

## The commands

These are the only commands you need. Type them in Claude Code exactly as they appear here.

### `/product-flow:start`
**When to use it:** When you want to start working on something new.

Type `/product-flow:start` followed by a description of what you want to build. Claude takes care of everything else: creates your workspace, opens the review room as a **DRAFT**, and prepares the spec.

```
/product-flow:start I want users to be able to reset their password
```

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

### `/product-flow:deploy-to-stage`
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

You and the team leave feedback by adding comments in the review room on GitHub. When you run `/product-flow:continue`, Claude reads all the comments and classifies each one automatically:

**Your comments (product)** — questions about business intent, priorities, user flows, terminology, or functional scope. Claude will **always ask you** before making any decision. It will never resolve these autonomously.

**Dev team comments** — questions about architecture, security, integrations, data model, or technical constraints. Claude resolves these autonomously without bothering you, and records each decision as a comment on the PR so the team can see the reasoning.

If Claude cannot resolve a technical question on its own, it posts it in the PR marked as unresolved so the dev team can answer it directly.

### What you might see after running `/product-flow:continue`

Claude may post comments on the PR like this:

> **Technical question detected:** "Which caching strategy should we use?"
>
> **Autonomously chosen answer:** We chose Redis with TTL of 5 minutes because…
>
> 💬 To change this decision, add a new comment: `Question 3. Answer: [your answer]`

You don't need to act on these unless you want to change the decision. If you do, add a **new comment** to the PR (not a reply) with the question number. For example: `Question 3. Correction: I prefer option A`.

### Code review comments (after `/product-flow:submit`)

Once the review room exits DRAFT, the team does a formal code review. These comments are handled differently — they go directly to the developer or back to Claude for a new iteration. If you run `/product-flow:submit` again after fixing things, the team sees the updated code.

---

## How multiple people collaborate on the same spec

### The rounds model

The spec is not written by everyone at once. It advances in rounds:

```
Round 1 ── The person who opens the feature writes the initial spec draft with /product-flow:start
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
/product-flow:start "description"
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
/product-flow:deploy-to-stage → feature in internal testing → published
```

### What "DRAFT" means

The review room is in **DRAFT** from the moment `/product-flow:start` runs until you run `/product-flow:submit` for the first time. During this time:

- The team **can see the review room** and leave comments
- The team **is not asked to approve** anything yet
- All spec and plan work happens here

When you run `/product-flow:submit`, the review room exits DRAFT and the team receives a notification to do a formal code review.

### When to comment at each step

| Phase | Who comments | What to comment on |
|---|---|---|
| After `/product-flow:start` | You and the whole team | The spec — does it describe the right thing? Is anything missing? |
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
Spec      → What & why    (written with /product-flow:start, refined with /product-flow:continue)
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

**After `/product-flow:build`, Claude asks me something about "verify-tasks". What is that?**
It's an optional quality check that confirms every completed task has real code behind it — not empty stubs or placeholders. You can run it immediately, open a new session and run it later, or skip it. If you're unsure, choose "run now" — it only takes a moment and catches problems before the team reviews the code.

**During `/product-flow:build`, Claude is asking me questions before writing code. Is that normal?**
Yes. Before generating code, Claude runs a requirements quality check that may ask up to 5 clarification questions to make sure the spec, plan and tasks are clear and complete. Answer them as best you can — they are quick and help prevent implementation mistakes. Once the questions are done, code generation continues automatically.

**How much detail should I give when running `/product-flow:start`?**
Write whatever you know, in your own words. You don't need to find the right level — Claude adjusts automatically:
- If your description is **vague or short**, Claude will ask you a few focused questions before writing the spec.
- If your description is **very detailed or technical**, Claude will extract the technical parts automatically and keep only the business intent for the spec. Nothing gets lost — the technical details are saved separately for the development team.

The only rule: describe **what you want to achieve and for whom**, not how to build it. The rest is handled for you.

**I want to refine the spec before sharing it with the team. How?**
Run `/product-flow:speckit.clarify` after `/product-flow:start`. Claude will scan the spec, identify the most important ambiguities, and ask you up to 5 targeted questions to sharpen it. The spec is updated in place. You can then share the PR with the team as usual.

**The spec is covering too many things. Can I split it into two features?**
Yes. After `/product-flow:start` writes the first spec, run `/product-flow:speckit.split`. Claude will analyze the spec, detect whether it covers independent deliverables or different user journeys, and propose a clean split. If you confirm, it trims the current spec and opens a new review room for the extracted feature — ready to continue from where the split happened.

**Can I work on two features at the same time?**
Yes, but it's better to finish one before starting another. If you need to do it, notify the development team first.

**How do I know if the team has reviewed what I submitted?**
`/product-flow:status` will tell you. You can also look at your review room on GitHub — the team's comments appear there.

**What is GitHub?**
It's the site where the review room lives. You don't need to go there directly — Claude manages it for you — but if you want to see the status of your feature, you can find it at github.com/[project-name].

**How do I install the plugin?**
Open your terminal, type `claude` and press Enter. Once it loads, run:

```
/plugin marketplace add git@github.com:deuveme/product-flow.git
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
