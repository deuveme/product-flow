#!/usr/bin/env bash
# hooks/state-notifier.sh
# PostToolUse hook — shows a PM-friendly message whenever workflow state advances.
#
# WHEN IT FIRES
#   After any Bash tool call that writes a workflow state flag to status.json.
#   Ignores all other bash commands (processed_answers, processed_comment_ids, etc.).
#
# STATE FLAGS TRACKED
#   spec_created · plan_generated · tasks_generated · checklist_done
#   code_written · code_verified · in_review

set -uo pipefail

INPUT=$(cat)

# Extract the bash command that just ran
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only act on commands that write a known workflow state flag to status.json
if ! echo "$COMMAND" | grep -q 'status\.json'; then
  exit 0
fi

if ! echo "$COMMAND" | grep -qE '"(spec_created|plan_generated|tasks_generated|checklist_done|code_written|code_verified|in_review)"'; then
  exit 0
fi

# ── Detect which flag was just written ────────────────────────────────────────
FLAG=""
for F in spec_created plan_generated tasks_generated checklist_done code_written code_verified in_review; do
  if echo "$COMMAND" | grep -q "\"$F\""; then
    FLAG="$F"
    break
  fi
done

[ -z "$FLAG" ] && exit 0

# ── Deduplication: only notify once per flag per session ──────────────────────
# Uses a per-branch temp file so re-runs after GPG failures don't repeat messages.
BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-')
NOTIFIED_FILE="/tmp/product-flow-notified-${BRANCH}"

if grep -q "^${FLAG}$" "$NOTIFIED_FILE" 2>/dev/null; then
  exit 0
fi
echo "$FLAG" >> "$NOTIFIED_FILE"

# ── Build PM-friendly message ─────────────────────────────────────────────────
case "$FLAG" in
  spec_created)
    TITLE="📋 Spec created"
    BODY="The feature requirements have been written and the spec is ready for the team to review."
    NEXT="Share the PR with your team so they can read it. When they've reviewed it, run /product-flow:continue."
    ;;
  plan_generated)
    TITLE="🏗️ Technical plan ready"
    BODY="The team has designed how this feature will be built: research, data model, and contracts are all documented."
    NEXT="Review the plan on the PR. If it looks good, run /product-flow:continue to start building."
    ;;
  tasks_generated)
    TITLE="📝 Tasks ready"
    BODY="The feature has been broken down into development tasks, ordered by dependencies."
    NEXT="Run /product-flow:build to generate the code."
    ;;
  checklist_done)
    TITLE="✅ Requirements validated"
    BODY="All acceptance criteria have been reviewed and any critical gaps have been resolved."
    NEXT="Continuing to implementation..."
    ;;
  code_written)
    TITLE="💻 Code generated"
    BODY="The feature code has been written following the spec, plan, and tasks."
    NEXT="Running final quality check to confirm all tasks are truly complete..."
    ;;
  code_verified)
    TITLE="🔍 Code verified"
    BODY="All tasks have been confirmed as complete — no placeholders or unfinished work detected."
    NEXT="Run /product-flow:submit to save the code and send it for review."
    ;;
  in_review)
    TITLE="👀 PR ready for review"
    BODY="The code has been saved and the PR is now open for the development team."
    NEXT="When the team approves the PR, run /product-flow:deploy-to-stage."
    ;;
  *)
    exit 0
    ;;
esac

# ── Output instruction for Claude ─────────────────────────────────────────────
cat <<EOF
[product-flow — state transition: $FLAG]

Show the user this status update now, before continuing with any other step:

─────────────────────────────────────────
$TITLE

$BODY

➡️  $NEXT
─────────────────────────────────────────
EOF

exit 0
