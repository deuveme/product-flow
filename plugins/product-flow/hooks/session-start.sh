#!/bin/bash
# Hook: SessionStart
# Runs /status and enforces workflow gates to prevent premature coding.

if [ -f /tmp/claude-resume-flag ]; then
  rm /tmp/claude-resume-flag
fi

echo "AUTOMATIC INSTRUCTION: At the start of this session, run /status to show the user where they are in the workflow and what to do next.

BEHAVIORAL GATES — Enforce these throughout the entire session:

1. WORKFLOW GATE: If the user asks to build, implement, add, or create a feature that involves multiple files, unclear requirements, or architectural decisions — and there is NO active feature branch/PR — recommend running /start first and wait for the user's decision. Do not generate code or create files.

2. IMPLEMENTATION GATE: If there is an active feature branch with an open PR that has pending workflow steps (spec not approved, plan not generated, tasks not created) — recommend using the appropriate workflow command (/continue, /build) rather than coding directly. Do not implement features outside the workflow. Wait for the user's decision.

These are guardrails, not hard blocks. If the user explicitly acknowledges and chooses to proceed outside the workflow, respect their decision."
