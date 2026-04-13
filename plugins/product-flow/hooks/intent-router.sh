#!/usr/bin/env bash
# hooks/intent-router.sh
# UserPromptSubmit hook — maps ambiguous short phrases to the correct product-flow skill.
#
# WHEN IT FIRES
#   Only on short messages (≤ 6 words) that do not already contain a /product-flow: command.
#   Long messages (feature descriptions, questions, conversations) pass through untouched.
#
# HOW IT WORKS
#   1. Normalize the prompt (lowercase, strip punctuation).
#   2. Match against keyword groups:
#      a. Clear-intent keywords → route directly (no state needed).
#      b. Ambiguous continuation keywords → read status.json, derive the correct skill.
#   3. Output a routing instruction that Claude will follow before doing anything else.

JQ=$(command -v jq 2>/dev/null || command -v /usr/local/bin/jq 2>/dev/null || command -v /opt/homebrew/bin/jq 2>/dev/null || command -v /usr/bin/jq 2>/dev/null)
[ -z "$JQ" ] && { echo "product-flow: jq not found — hook skipped." >&2; exit 0; }

set -uo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | $JQ -r '.prompt // empty')

# ── Guard: skip if already a product-flow command ────────────────────────────
if echo "$PROMPT" | grep -qE '^\s*/product-flow:'; then
  exit 0
fi

# ── Guard: skip long messages (> 6 words) ────────────────────────────────────
# Feature descriptions, questions, and freeform chat are never routed.
WORD_COUNT=$(echo "$PROMPT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -gt 6 ]; then
  exit 0
fi

# ── Normalize ─────────────────────────────────────────────────────────────────
NORM=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' | sed 's/  */ /g' | sed 's/^ //;s/ $//')

# ── Helper: emit routing instruction and exit ─────────────────────────────────
route() {
  local skill="$1"
  local reason="$2"
  cat <<EOF
[product-flow router — ACTION REQUIRED]

The user's message ("$PROMPT") is a workflow navigation request.
$reason

Invoke /product-flow:$skill now. Do not respond with plain text instead.
EOF
  exit 0
}

# ── Group A: clear-intent keywords (state-independent) ───────────────────────

if echo "$NORM" | grep -qE '\b(status|estado|progreso|progress|donde estamos|where are we)\b'; then
  route "status" "Keyword matched: status check."
fi

if echo "$NORM" | grep -qE '\b(build|construir|implementar|implement)\b'; then
  route "build" "Keyword matched: build/implement."
fi

if echo "$NORM" | grep -qE '\b(submit|guardar|push|enviar|send for review|save)\b'; then
  route "submit" "Keyword matched: submit/save."
fi

if echo "$NORM" | grep -qE '\b(deploy|merge|publish|publicar|mergear|ship|desplegar)\b'; then
  route "deploy-to-stage" "Keyword matched: deploy/merge/publish."
fi

# ── Group B: ambiguous continuation keywords (state-dependent) ───────────────
# These only match when the entire message is one of these phrases.

if echo "$NORM" | grep -qE '^(seguir|continuar|siguiente|continue|next|go on|adelante|ok|listo|ya esta|done|finished|ready|siguiente paso|what now|que hago|que sigue|go|venga|dale|vamos)$'; then

  BRANCH=$(git branch --show-current 2>/dev/null || echo "")

  # Not on a feature branch → show status
  if [ -z "$BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    route "status" "Ambiguous keyword on main branch — no active feature."
  fi

  STATUS_FILE="specs/$BRANCH/status.json"

  # No status.json → show status
  if [ ! -f "$STATUS_FILE" ]; then
    route "status" "Ambiguous keyword but no status.json found for branch '$BRANCH'."
  fi

  # Read flags
  SPEC_CREATED=$($JQ -r    '.SPEC_CREATED    // empty' "$STATUS_FILE" 2>/dev/null)
  PLAN_GENERATED=$($JQ -r  '.PLAN_GENERATED  // empty' "$STATUS_FILE" 2>/dev/null)
  TASKS_GENERATED=$($JQ -r '.TASKS_GENERATED // empty' "$STATUS_FILE" 2>/dev/null)
  CODE_VERIFIED=$($JQ -r   '.CODE_VERIFIED   // empty' "$STATUS_FILE" 2>/dev/null)
  IN_REVIEW=$($JQ -r       '.IN_REVIEW       // empty' "$STATUS_FILE" 2>/dev/null)

  # Filesystem fallback for tasks (covers bug #2: tasks.md committed before flag)
  TASKS_DONE=""
  if [ -n "$TASKS_GENERATED" ] || [ -f "specs/$BRANCH/tasks.md" ]; then
    TASKS_DONE="yes"
  fi

  # State → skill mapping
  if [ -n "$IN_REVIEW" ]; then
    SKILL="deploy-to-stage"
    REASON="State: in_review set → PR is ready to merge."
  elif [ -n "$CODE_VERIFIED" ]; then
    SKILL="submit"
    REASON="State: code_verified set, not yet in review → submit the code."
  elif [ -n "$PLAN_GENERATED" ] && [ -n "$TASKS_DONE" ]; then
    SKILL="build"
    REASON="State: plan + tasks generated, code not yet verified → build."
  elif [ -n "$SPEC_CREATED" ]; then
    SKILL="continue"
    REASON="State: spec created, plan not yet generated (or tasks missing) → continue."
  else
    SKILL="status"
    REASON="State: spec not created yet — showing status to orient."
  fi

  route "$SKILL" "Ambiguous keyword on branch '$BRANCH'. $REASON"
fi

exit 0
