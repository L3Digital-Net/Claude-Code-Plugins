#!/bin/bash
# PostToolUse hook: counts file reads per session (keyed by parent PID).
# Warns at 10+ reads, critical alert at 15+ to enforce context discipline.
# Applies to all agents (lead + teammates).
# Uses project root for the counter file so worktree agents (CWD = .worktrees/<n>/)
# write to the same shared state as the lead.

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
COUNTER_FILE="$PROJECT_ROOT/.claude/state/.read-count-$PPID"

# Ensure state directory exists
mkdir -p "$(dirname "$COUNTER_FILE")"

# Read current count (default 0)
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ "$COUNT" -eq 10 ]; then
  echo "⚠ You have read 10 files in this session. Write your handoff note now and consider running /compact (the Claude Code compact command)."
elif [ "$COUNT" -eq 15 ]; then
  echo "⚠⚠ 15 file reads. Write a handoff note to .claude/state/<your-name>-handoff.md immediately, then run /compact (the Claude Code compact command)."
fi
