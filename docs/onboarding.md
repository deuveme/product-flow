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

- You just started something → **Your computer**
- You ran `/submit` → **Review room**
- The team approved and you ran `/deploy-to-stage` → **Internal testing**
- The team published → **The real world**

---

## The commands

These are the only commands you need. Type them in Claude Code exactly as they appear here.

### `/start`
**When to use it:** When you want to start working on something new.

Type `/start` followed by a description of what you want to build. Claude takes care of everything else: creates your workspace, opens the review room and prepares the spec.

```
/start I want users to be able to reset their password
```

---

### `/continue`
**When to use it:** Every time the team has commented on the PR and you want to advance to the next step, or when you want to move forward after the spec is ready.

Claude reads the current state of your feature and automatically does what's needed: integrate spec feedback, generate the technical plan, integrate plan feedback, or let you know you can build. You can run it as many times as needed.

---

### `/build`
**When to use it:** When the team has approved the technical plan and you want Claude to write the code.

Claude generates all the feature code. Requires the plan to be approved — if it isn't, it will let you know.

---

### `/submit`
**When to use it:** When you want the team to see the code Claude has generated.

Sends everything to the review room and notifies the team. You can run it as many times as you want — each time, the team sees the most recent changes.

---

### `/deploy-to-stage`
**When to use it:** When the team has approved the code and you want to send it to internal testing.

The team will be able to see and test your feature in the testing environment before publishing it to real users. Requires the PR to be approved — if it isn't, it will let you know.

---

### `/status`
**When to use it:** When you're not quite sure where you are or what you have pending.

Tells you, in plain language, where you are in the workflow and what the next step is.

---

### `/context`
**When to use it:** When you want to know how much memory Claude has left in this session.

---

## How PR comments work

When you leave comments on the PR, Claude reads them all when you run `/continue` and classifies each one automatically:

**Your comments (product)** — questions about business intent, priorities, user flows, terminology, or functional scope. Claude will **always ask you** before making any decision. It will never resolve these autonomously.

**Dev team comments** — questions about architecture, security, integrations, data model, or technical constraints. Claude resolves these autonomously without bothering you, and records each decision as a comment on the PR so the team can see the reasoning.

If Claude cannot resolve a technical question on its own, it posts it in the PR marked as unresolved so the dev team can answer it directly.

### What you might see after running `/continue`

Claude may post comments on the PR like this:

> **Technical question detected:** "Which caching strategy should we use?"
>
> **Autonomously chosen answer:** We chose Redis with TTL of 5 minutes because…
>
> 💬 If you want to change this decision, reply with: `Correction: [your answer]`

You don't need to act on these unless you want to change the decision.

---

## How multiple people collaborate on the same spec

### The rounds model

The spec is not written by everyone at once. It advances in rounds:

```
Round 1 ── The person who opens the feature writes the initial spec draft with /start
               ↓
Round 2 ── The team reads and leaves comments in the review room
           (never edit the file directly)
               ↓
Round 3 ── /continue merges all the comments
               ↓
Round 4 ── Final review before moving to the technical plan
```

### In practice

- **You write the spec** → notify the team on Slack with the link to the PR
- **You receive the notification** → go to the review room on GitHub → leave your comments
- **Once everyone has commented** → whoever opened the feature runs `/continue`
- **Final review** → the team approves on GitHub before continuing

---

## The complete feature lifecycle

```
/start "description"
        ↓
   /continue (repeat as needed)
   — integrates team feedback on the spec
   — generates the technical plan once the spec is ready
   — integrates team feedback on the plan
        ↓
/build → code generated
        ↓
/submit → review room exits DRAFT
        ↓
   Team does code review and approves  ← mandatory checkpoint
        ↓
/deploy-to-stage → feature in internal testing → published
```

---

## What is the spec, the plan, and the tasks?

Each feature goes through three documents before any code is written. You will see them referenced in the review room checklist.

**Spec** — What we want to build, in product language. Describes the feature from the user's perspective: what problem it solves, what the user can do, what the expected behaviour is. This is written in the first round and is the document you review and give feedback on.

**Plan** — How we are going to build it, in technical language. Generated by Claude from the spec once it is ready. Describes the architecture, the data model, the APIs, and the technical decisions. The dev team reviews this.

**Tasks** — The list of development steps to implement the plan. Generated automatically from the plan. Each task maps to a specific piece of code. You don't need to review these.

```
Spec      → What & why    (written with /start, refined with /continue)
Plan      → How           (generated with /continue, reviewed by dev team)
Tasks     → Step by step  (generated with /build, not reviewed)
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

If you're not sure where you are, look at the checklist in your review room or run `/status`.

---

## Frequently asked questions

**Can I lose work?**
No. Everything you submit is saved forever with date and time. Even if something goes wrong, it can be recovered.

**What do I do if Claude tells me there is a "conflict"?**
Contact the development team. It's the only situation where you need their direct technical help.

**Can I work on two features at the same time?**
Yes, but it's better to finish one before starting another. If you need to do it, notify the development team first.

**How do I know if the team has reviewed what I submitted?**
`/status` will tell you. You can also look at your review room on GitHub — the team's comments appear there.

**What is GitHub?**
It's the site where the review room lives. You don't need to go there directly — Claude manages it for you — but if you want to see the status of your feature, you can find it at github.com/[project-name].

---

*Something unclear? Ask the development team before continuing. It's better to ask than to assume.*
