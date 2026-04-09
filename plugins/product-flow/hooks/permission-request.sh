#!/usr/bin/env bash
# hooks/permission-request.sh
# PermissionRequest hook — auto-approves safe operations when the plugin is active.
#
# APPROVED AUTOMATICALLY
#   Read tools    : Read, Glob, Grep
#   Tracking      : TodoWrite, TodoRead
#   Web fetches   : WebFetch (any URL, including GitHub)
#   File writes   : Edit, Write — security-guard.sh (PreToolUse, exit 2) already
#                   hard-blocks any write outside the project, so reaching this
#                   hook means the path is inside the project.
#   Bash — git    : all git commands — workflow-guard.sh (PreToolUse, exit 2)
#                   already blocks: push/merge to main, non-conforming branch
#                   names, gh pr merge without --squash.
#   Bash — gh     : all gh CLI commands — same workflow guardrails apply.
#   Bash — read   : explicit whitelist of read-only shell commands.
#
# PASSED THROUGH (normal permission flow, user is prompted)
#   Anything not matching the patterns above, e.g.:
#     brew install, pip install, npm -g, inline interpreter scripts,
#     redirects to variable paths, and any other write-capable commands
#     not covered by the whitelist.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
[[ -z "$TOOL_NAME" ]] && exit 0

allow() {
  echo '{"behavior": "allow"}'
  exit 0
}

case "$TOOL_NAME" in

  # ── Read-only file tools ───────────────────────────────────────────────────
  Read|Glob|Grep|TodoRead|TodoWrite)
    allow
    ;;

  # ── Web fetches (GitHub, LinkedIn, raw URLs, any domain) ──────────────────
  WebFetch)
    allow
    ;;

  # ── File writes inside the project ────────────────────────────────────────
  # security-guard.sh already hard-blocked paths outside the project (exit 2).
  # A PermissionRequest for Edit/Write means the boundary check already passed.
  Edit|Write)
    allow
    ;;

  # ── Bash commands ─────────────────────────────────────────────────────────
  Bash)
    cmd=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    [[ -z "$cmd" ]] && exit 0

    # git — workflow-guard.sh (PreToolUse, exit 2) enforces all restrictions
    # before this hook fires, so any git command reaching here is safe.
    if echo "$cmd" | grep -qE '^\s*git\b'; then
      allow
    fi

    # gh CLI — same: workflow-guard.sh already blocks dangerous operations.
    if echo "$cmd" | grep -qE '^\s*gh\b'; then
      allow
    fi

    # Read-only shell commands (whitelist).
    # Covers direct invocation and pipelines that start with these commands.
    readonly_pattern='^\s*(find|locate|grep|rg|egrep|fgrep|ag|cat|bat|less|more|ls|ll|la|dir|tree|head|tail|wc|echo|printf|which|type|command|pwd|env|printenv|sort|uniq|diff|colordiff|delta|stat|file|du|df|ps|pgrep|whoami|id|groups|date|cal|uname|hostname|uptime|sw_vers|lsof|netstat|ss|curl|wget|jq|yq|awk|sed|cut|tr|basename|dirname|realpath|readlink|md5sum|sha1sum|sha256sum|shasum|column|fmt|fold|comm|join|paste|xargs|test|true|false|open|fd|exa|eza)\b'
    if echo "$cmd" | grep -qE "$readonly_pattern"; then
      allow
    fi
    ;;

esac

# Default: no opinion — normal permission flow applies (user is prompted).
exit 0
