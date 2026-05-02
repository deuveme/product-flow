#!/usr/bin/env bash
# hooks/language-enforcer.sh
# UserPromptSubmit hook — enforces English as the output language for all generated artifacts.
#
# Runs on every prompt so that all skills write spec, plan, tasks, and other
# artifacts in English regardless of the language used in the conversation.

cat <<'EOF'
[product-flow language rule] All generated artifacts (spec.md, plan.md, tasks.md, research.md, data-model.md, quickstart.md, gathered-context.md, improvement-context.md, collaborative-design.md, split-analysis.md, checklists, contracts, and any other file written to the specs/ directory) must be written in English, regardless of the language used in this conversation.
EOF

exit 0
