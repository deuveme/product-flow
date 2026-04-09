#!/usr/bin/env bash
# hooks/git-sync.sh
# UserPromptSubmit hook — syncs the repo with origin before any public product-flow skill.
#
# FLOW
#   1. Check if the submitted prompt is a public product-flow skill invocation.
#   2. Run git pull. If it succeeds, do nothing — skill proceeds normally.
#   3. If git pull fails and there are local changes:
#      a. Ask the user (via Claude) whether to discard or keep the local changes.
#      b. If DISCARD: Claude runs `git checkout . && git clean -fd`, then `git pull`.
#      c. If KEEP: Claude runs `git stash`, `git pull`, `git stash pop`.
#   4. If git pull fails with no local changes, warn and continue.
#
# PUBLIC SKILLS (user-invocable)
#   start · continue · build · submit · deploy-to-stage · status · context

set -uo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

# Only act when the user is invoking a public product-flow skill.
if ! echo "$PROMPT" | grep -qE '/product-flow:(start|continue|build|submit|deploy-to-stage|status|context)(\s|$)'; then
  exit 0
fi

# ── Step 1: Try git pull ──────────────────────────────────────────────────────
if git pull 2>/dev/null 1>/dev/null; then
  exit 0
fi

# ── Step 2: Pull failed — check if there are local changes ───────────────────
LOCAL_CHANGES=$(git status --porcelain 2>/dev/null)

if [ -z "$LOCAL_CHANGES" ]; then
  # No local changes — pull failed for another reason (network, server, etc.)
  printf '[GIT SYNC WARNING] Could not sync the repo (git pull failed; no local changes detected). This may be a network or server issue. Inform the user briefly in PM-friendly language and continue with the skill.\n'
  exit 0
fi

# ── Step 3: Local changes exist — delegate decision to Claude ─────────────────
cat <<'EOF'
[GIT SYNC — ACTION REQUIRED BEFORE STARTING THE SKILL]

git pull failed because there are local changes in the repo that conflict with the
remote. Do NOT start any skill step until you have resolved this with the user.

Follow these steps exactly:

1. Inform the user and ask a question using AskUserQuestion. Use friendly, non-technical
   language (no git jargon — speak as a PM-facing assistant):

   "Before I start, I noticed this project has some local changes that haven't been
   saved online yet, and they're preventing me from getting the latest updates.
   Would you like to discard those local changes so I can sync properly, or would
   you prefer to keep them?"

2. Wait for the user's answer.

   IF they want to DISCARD (yes / delete / discard / remove / get rid of them):
     a. Run: git checkout .
     b. Run: git clean -fd
     c. Run: git pull
     d. Proceed with the skill normally.

   IF they want to KEEP (no / keep / save / hold on to them):
     a. Run: git stash
     b. Run: git pull
     c. Run: git stash pop
     d. Proceed with the skill normally.
EOF
exit 0
