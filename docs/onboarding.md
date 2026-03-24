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
**When to use it:** Every time the team has done something (commented, approved) and you want to advance to the next step.

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

## How multiple people collaborate on the same spec

### The rounds model

The spec is not written by everyone at once. It advances in rounds:

```
Round 1 ── The person who opens the feature writes the initial spec draft with /start
               ↓
Round 2 ── The others read and leave comments in the review room
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
   /continue (repeat until the plan is approved)
   — integrates team feedback
   — generates the technical plan once the spec is approved
        ↓
   Team approves the plan  ← mandatory checkpoint
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

## Review room status

Each review room has a checklist that indicates which phase it's in:

```
- [x] Spec created
- [x] Spec approved by the development team
- [x] Plan generated
- [ ] Plan approved by the development team     ← waiting here
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
