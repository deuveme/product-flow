#!/usr/bin/env bash
# .claude/hooks/security-guard.sh
# PreToolUse hook — boundary enforcement for file operations.
#
# POLICY
#   Inside the project repository  → read, write, create, delete — allowed.
#   Outside the project repository → READ-ONLY. Write / edit / delete → BLOCKED.
#
# HARD BLOCKS (exit 2 — cannot be bypassed)
#   Edit, Write, NotebookEdit → exact path check.
#   Bash: rm, rmdir, mv, cp (destination), tee, sed -i, awk -i,
#         truncate, shred, and shell output redirections (> >>).
#
# SOFT CHECKS (asks user — ambiguous risk patterns in Bash)
#   • Inline interpreter scripts  (python -c, node -e, ruby -e, perl -e)
#   • Global installers           (npm -g/--global, pip install, brew install)
#   • Shell variable paths        ($HOME, ~/, $VAR, $(…) before write commands)
#
# KNOWN RESIDUAL LIMITATIONS
#   • Variable paths that aren't caught by the regex patterns below.
#   • eval, process substitution, or fully dynamic command construction.
#   These require human review during code approval.

JQ=$(command -v jq 2>/dev/null || command -v /usr/local/bin/jq 2>/dev/null || command -v /opt/homebrew/bin/jq 2>/dev/null || command -v /usr/bin/jq 2>/dev/null)
[ -z "$JQ" ] && { echo "product-flow: jq not found — hook skipped." >&2; exit 0; }

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | $JQ -r '.tool_name // empty')
[[ -z "$TOOL_NAME" ]] && exit 0

# Resolve project root via git
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "security-guard: cannot resolve git root — boundary check skipped." >&2
  exit 0
}
PROJECT_ROOT="${PROJECT_ROOT%/}"

# Returns 0 if a path is inside the project repository, 1 otherwise.
in_project() {
  local raw="$1"
  [[ "$raw" != /* ]] && raw="$PROJECT_ROOT/$raw"
  # /dev/* are kernel virtual devices (e.g. /dev/null) — always safe to write to.
  [[ "$raw" == /dev/* ]] && return 0
  local real
  real=$(realpath -m "$raw" 2>/dev/null) \
    || real=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$raw" 2>/dev/null) \
    || real="$raw"
  [[ "$real" == "$PROJECT_ROOT" || "$real" == "$PROJECT_ROOT/"* ]]
}

# Hard block — stops the tool call unconditionally.
block() {
  printf '[SECURITY BLOCK] %s\n  Flagged path : %s\n  Project root : %s\n  External files are read-only — writes/deletes outside the repository are not allowed.\n' \
    "$1" "$2" "$PROJECT_ROOT" >&2
  exit 2
}

# Soft check — asks the user for confirmation before proceeding.
ask() {
  local reason="$1"
  $JQ -n \
    --arg reason "$reason" \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: $reason
      }
    }'
  exit 0
}

# ── File tools (exact path) ───────────────────────────────────────────────────

case "$TOOL_NAME" in

  Edit)
    p=$(echo "$INPUT" | $JQ -r'.tool_input.file_path // empty')
    [[ -n "$p" ]] && ! in_project "$p" && \
      block "Edit is not allowed outside the project repository." "$p"
    ;;

  Write)
    p=$(echo "$INPUT" | $JQ -r'.tool_input.file_path // empty')
    [[ -n "$p" ]] && ! in_project "$p" && \
      block "Write is not allowed outside the project repository." "$p"
    ;;

  NotebookEdit)
    p=$(echo "$INPUT" | $JQ -r'.tool_input.notebook_path // empty')
    [[ -n "$p" ]] && ! in_project "$p" && \
      block "NotebookEdit is not allowed outside the project repository." "$p"
    ;;

# ── Bash: hard blocks ─────────────────────────────────────────────────────────

  Bash)
    cmd=$(echo "$INPUT" | $JQ -r'.tool_input.command // empty')
    [[ -z "$cmd" ]] && exit 0

    # Extract all absolute paths found in a string.
    # Uses printf to avoid echo misinterpreting metacharacters.
    abs_paths() {
      printf '%s\n' "$1" | grep -oE '(/[^[:space:];&|<>\\"\x27]+)' || true
    }

    # Check all absolute paths and block if any are outside the project.
    check_all_paths() {
      local label="$1"
      while IFS= read -r p; do
        [[ -n "$p" ]] && ! in_project "$p" && \
          block "$label on a path outside the project repository is not allowed." "$p"
      done < <(abs_paths "$cmd")
    }

    # rm / rmdir
    echo "$cmd" | grep -qE '\brm(dir)?\b' && check_all_paths "rm/rmdir"

    # mv — source (deleted) or destination outside the project both blocked
    echo "$cmd" | grep -qE '\bmv\b' && check_all_paths "mv"

    # cp — only the destination matters (last absolute path in the command)
    if echo "$cmd" | grep -qE '\bcp\b'; then
      dest=$(abs_paths "$cmd" | tail -1 || true)
      [[ -n "$dest" ]] && ! in_project "$dest" && \
        block "cp: writing to a destination outside the project repository is not allowed." "$dest"
    fi

    # tee
    echo "$cmd" | grep -qE '\btee\b' && check_all_paths "tee"

    # sed -i / awk -i (in-place edit)
    echo "$cmd" | grep -qE '\b(sed|awk)\b.*\s-[a-zA-Z]*i' && \
      check_all_paths "In-place edit (sed/awk -i)"

    # truncate / shred
    echo "$cmd" | grep -qE '\b(truncate|shred)\b' && check_all_paths "truncate/shred"

    # Shell output redirections (> or >>) pointing to an absolute path.
    # Handles unquoted paths (/abs/path) and double-quoted paths ("/abs/path with spaces").
    _redir_paths() {
      # Unquoted absolute paths
      printf '%s\n' "$1" | grep -oE '>{1,2}[[:space:]]*/[^[:space:];&|"]+' \
        | grep -oE '/[^[:space:];&|"]+' || true
      # Double-quoted absolute paths (may contain spaces)
      printf '%s\n' "$1" | grep -oE '>{1,2}[[:space:]]*"/[^"]*"' \
        | grep -oE '"/[^"]*"' | tr -d '"' || true
    }
    while IFS= read -r p; do
      [[ -n "$p" ]] && ! in_project "$p" && \
        block "Shell output redirection to a path outside the project repository is not allowed." "$p"
    done < <(_redir_paths "$cmd")

    # ── Bash: soft checks (ask user) ─────────────────────────────────────────

    # Inline interpreter scripts — can perform arbitrary file I/O
    if echo "$cmd" | grep -qE '\b(python3?|node|ruby|perl)\b\s+-(c|e)\s'; then
      ask "Inline interpreter script detected (python/node/ruby/perl -c/-e). It may write to files outside the project repository and those writes cannot be intercepted. Do you want to proceed?"
    fi

    # Global package installers — write outside the project by design
    if echo "$cmd" | grep -qE '\bnpm\s+(install|i)\b.*(--global|-g)\b|\bnpm\s+(--global|-g)\b.*\binstall\b'; then
      ask "Global npm install detected. This writes outside the project repository (global node_modules). Do you want to proceed?"
    fi
    if echo "$cmd" | grep -qE '\bpip3?\s+install\b'; then
      ask "pip install detected. This may write outside the project repository (site-packages). Do you want to proceed?"
    fi
    if echo "$cmd" | grep -qE '\bbrew\s+install\b'; then
      ask "brew install detected. This writes outside the project repository (/opt/homebrew or /usr/local). Do you want to proceed?"
    fi

    # Shell variable paths used with write-capable commands
    # Catches patterns like: rm $HOME/..., echo x > ~/file, tee $VAR, mv $(...) ...
    if echo "$cmd" | grep -qE '\b(rm|mv|tee|truncate|shred|sed|awk)\b.*(\$[A-Za-z_{(]|~/)'; then
      ask "Shell variable or home-relative path detected in a write/delete command (e.g. \$HOME, \$VAR, ~/…). The path cannot be resolved statically — it may point outside the project repository. Do you want to proceed?"
    fi
    if echo "$cmd" | grep -qE '>{1,2}\s*(\$[A-Za-z_{(]|~/)'; then
      ask "Shell output redirection to a variable or home-relative path detected (e.g. > \$VAR, > ~/file). The target cannot be resolved statically — it may be outside the project repository. Do you want to proceed?"
    fi

    ;;

esac

exit 0
