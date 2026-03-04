#!/bin/bash
# PreCompact hook: logs compaction event to its own file (NOT the ledger)
# and injects a reminder into the agent's context via stdout.
# Log is trimmed to the last 50 entries after each append to prevent unbounded growth.

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Log to compaction events file (append-only, read by lead between waves)
if [ -d ".claude/state" ]; then
  echo "$TIMESTAMP auto-compaction triggered" >> ".claude/state/compaction-events.log"
  # Trim to last 50 entries
  tail -50 ".claude/state/compaction-events.log" > ".claude/state/compaction-events.log.tmp" \
    && mv ".claude/state/compaction-events.log.tmp" ".claude/state/compaction-events.log"
fi

# stdout becomes context — remind the agent
echo "COMPACTION IMMINENT. Write your handoff note to .claude/state/<your-name>-handoff.md NOW. After compaction, read it to restore continuity."
