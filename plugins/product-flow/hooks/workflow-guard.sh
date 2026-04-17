#!/usr/bin/env bash
# plugins/product-flow/hooks/workflow-guard.sh
# PreToolUse hook — enforces product-flow workflow structure for git/gh operations.
#
# RULES
#   1. Branch names must follow NNN-kebab-name (e.g. 001-user-auth)
#      Blocks: git branch, git checkout -b, git switch -c with non-conforming names.
#   2. No direct commits to main/master. Feature branch commits are always allowed.
#   3. No direct push to main/master (from main or with explicit main/master target).
#      Use /product-flow:deploy-to-stage instead.
#   4. No git merge into main/master.
#      Use /product-flow:deploy-to-stage (gh pr merge --squash) instead.
#   5. gh pr merge must include --squash.
#      Use /product-flow:deploy-to-stage, which sets --squash --delete-branch.
#   6. gh pr create only allowed from a product-flow branch (NNN-kebab-name).
#      Use /product-flow:start to open a feature with the correct structure.
#
# INTENT
#   Every feature must start with /product-flow:start and end with
#   /product-flow:deploy-to-stage — raw git shortcuts that bypass the workflow
#   are blocked at the agent level.

JQ=$(command -v jq 2>/dev/null || command -v /usr/local/bin/jq 2>/dev/null || command -v /opt/homebrew/bin/jq 2>/dev/null || command -v /usr/bin/jq 2>/dev/null)
[ -z "$JQ" ] && { echo "product-flow: jq not found — hook skipped." >&2; exit 0; }

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | $JQ -r '.tool_name // empty')
[[ -z "$TOOL_NAME" ]] && exit 0
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

cmd=$(echo "$INPUT" | $JQ -r '.tool_input.command // empty')
[[ -z "$cmd" ]] && exit 0

# product-flow branch convention: NNN-kebab-name  (e.g. 001-user-auth)
BRANCH_PATTERN='^[0-9]{3}-[a-z][a-z0-9-]+$'

block() {
  printf '[WORKFLOW GUARD] %s\n' "$1" >&2
  exit 2
}

current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# ── Rule 1: Branch names must follow NNN-kebab-name ──────────────────────────

check_branch_name() {
  local name="$1"
  [[ -z "$name" ]] && return 0
  if ! echo "$name" | grep -qE "$BRANCH_PATTERN"; then
    block "Branch '$name' does not follow the product-flow naming convention (NNN-kebab-name, e.g. 001-user-auth).
  Use /product-flow:start to create a properly named feature branch."
  fi
}

# Strip surrounding single or double quotes from a branch name extracted by grep.
strip_quotes() {
  local s="$1"
  s="${s#\"}" ; s="${s%\"}"
  s="${s#\'}" ; s="${s%\'}"
  echo "$s"
}

# git branch <name> [start-point]
if echo "$cmd" | grep -qE '\bgit[[:space:]]+branch[[:space:]]+[^-]'; then
  raw=$(echo "$cmd" | grep -oE 'git[[:space:]]+branch[[:space:]]+[^[:space:]]+' | awk '{print $NF}')
  name=$(strip_quotes "$raw")
  check_branch_name "$name"
fi

# git checkout -b <name>  or  git checkout -B <name>
if echo "$cmd" | grep -qE '\bgit[[:space:]]+checkout[[:space:]].*-[bB][[:space:]]'; then
  raw=$(echo "$cmd" | grep -oE '\-[bB][[:space:]]+[^[:space:]]+' | awk '{print $NF}')
  name=$(strip_quotes "$raw")
  check_branch_name "$name"
fi

# git switch -c <name>  or  git switch -C <name>
if echo "$cmd" | grep -qE '\bgit[[:space:]]+switch[[:space:]].*-[cC][[:space:]]'; then
  raw=$(echo "$cmd" | grep -oE '\-[cC][[:space:]]+[^[:space:]]+' | awk '{print $NF}')
  name=$(strip_quotes "$raw")
  check_branch_name "$name"
fi

# ── Rule 2: No direct commits to main/master ─────────────────────────────────
# Feature branch commits are allowed at any workflow step.
# Only main/master is protected.

if echo "$cmd" | grep -qE '\bgit[[:space:]]+commit\b'; then
  branch=$(current_branch)
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    block "Direct commits to '$branch' are not allowed.
  Use /product-flow:deploy-to-stage to publish a feature to main."
  fi
fi

# ── Rule 3: No direct push to main/master ────────────────────────────────────
# Blocked if currently on main/master (covers git push, git push origin HEAD, etc.)
# Also blocked if an explicit main/master target is given from any branch.

if echo "$cmd" | grep -qE '\bgit[[:space:]]+push\b'; then
  branch=$(current_branch)
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    # Allow ref-deletion / branch-rename operations (git push origin :old new)
    # These are used by /product-flow:status when reordering branch numbers.
    if ! echo "$cmd" | grep -qE '\bgit[[:space:]]+push[[:space:]]+\S+[[:space:]]+:'; then
      # Allow deploy-to-stage post-merge housekeeping commits only.
      # Two conditions must both be true:
      #   1. Commit message matches a known deploy-to-stage pattern.
      #   2. Every file in the commit is within the expected path for that pattern.
      last_msg=$(git log -1 --format=%s 2>/dev/null || echo "")
      changed_files=$(git diff HEAD~1 --name-only 2>/dev/null || echo "")
      is_deploy_push=false

      # chore: record published in status.json — only specs/*/status.json allowed
      if echo "$last_msg" | grep -qE '^chore: record published in status\.json$'; then
        if [ -n "$changed_files" ] && ! echo "$changed_files" | grep -qvE '^specs/[^/]+/status\.json$'; then
          is_deploy_push=true
        fi
      fi

      # docs: add ADRs from <branch> — only docs/adr/ allowed
      if echo "$last_msg" | grep -qE '^docs: add ADRs from .+'; then
        if [ -n "$changed_files" ] && ! echo "$changed_files" | grep -qvE '^docs/adr/'; then
          is_deploy_push=true
        fi
      fi

      if ! $is_deploy_push; then
        block "Direct push from '$branch' is not allowed.
  Use /product-flow:deploy-to-stage to publish a feature to main."
      fi
    fi
  fi
  if echo "$cmd" | grep -qE '\bgit[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+(main|master)\b'; then
    block "Direct push to main/master is not allowed.
  Use /product-flow:deploy-to-stage to publish a feature to main."
  fi
fi

# ── Rule 4: No git merge into main/master ────────────────────────────────────

if echo "$cmd" | grep -qE '\bgit[[:space:]]+merge\b'; then
  branch=$(current_branch)
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    block "Direct merge into '$branch' is not allowed.
  Use /product-flow:deploy-to-stage to merge a feature (squash merge via gh pr merge)."
  fi
fi

# ── Rule 5: gh pr merge must use --squash ─────────────────────────────────────

if echo "$cmd" | grep -qE '\bgh[[:space:]]+pr[[:space:]]+merge\b'; then
  if ! echo "$cmd" | grep -qE '\-\-squash\b'; then
    block "gh pr merge requires --squash to follow the product-flow convention.
  Use /product-flow:deploy-to-stage, which merges with --squash --delete-branch."
  fi
fi

# ── Rule 6: gh pr create only from product-flow branches ─────────────────────

if echo "$cmd" | grep -qE '\bgh[[:space:]]+pr[[:space:]]+create\b'; then
  branch=$(current_branch)
  if ! echo "$branch" | grep -qE "$BRANCH_PATTERN"; then
    block "Pull requests can only be created from a product-flow branch (NNN-kebab-name, e.g. 001-user-auth).
  Use /product-flow:start to begin a feature with the correct workflow structure."
  fi
fi

exit 0
