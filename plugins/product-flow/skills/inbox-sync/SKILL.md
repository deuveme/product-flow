---
description: "Synchronizes PR inbox state: answers and new comments."
user-invocable: false
model: haiku
effort: low
---

## Purpose

Single internal entry point to process PR inbox activity consistently across workflow commands.

## Execution

1. Show: `📬 Checking for new activity...`

2. **Part A — Answers to bot questions**
   - Invoke `/product-flow:pr-comments read-answers`.
   - For each new answer found:
     - If clear: apply directly.
     - If ambiguous/incomplete:
       - `type: technical` → resolve autonomously using project context.
       - `type: product` → ask the PM using **AskUserQuestion** (one entry for this question only).
     - Show:
       - `⏳ Question <N> — <one-line summary> → applying to <artifact>...`
       - `✅ Question <N> — applied.`
   - Invoke `/product-flow:pr-comments mark-processed` with all applied question numbers.

3. **Part B — New user comments**
   - Invoke `/product-flow:pr-comments new-comments`.
   - If `NO_NEW_COMMENTS`: skip this part silently.
   - For each new comment, classify:
     - **Technical**: architecture, security, performance, data model, infrastructure, integration patterns.
     - **Product**: business intent, scope, user flow, acceptance criteria, terminology.
     - **Ambiguous**: default to product and ask the PM.
     - **Incomprehensible**: post UNANSWERED clarification request via `/product-flow:pr-comments write` and continue.
   - Act:
     - Technical → resolve autonomously; write via `/product-flow:pr-comments write` (`ANSWERED` or `UNANSWERED`).
     - Product (and ambiguous) → ask PM via **AskUserQuestion**, apply, then write via `/product-flow:pr-comments write` (`ANSWERED`).
   - Invoke `/product-flow:pr-comments mark-comments-processed` with processed comment IDs.

4. Final output
   - If anything was handled: `✅ Inbox processed — <N> answer(s) applied, <M> comment(s) evaluated.`
   - If nothing to process: `✅ Inbox clear.`
