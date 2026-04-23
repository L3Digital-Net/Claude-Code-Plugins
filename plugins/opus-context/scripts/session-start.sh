#!/bin/bash
# Inject opus-context rules into AI context via SessionStart additionalContext.
# Claude Code reads stdout as JSON when the SessionStart hook emits
# hookSpecificOutput.additionalContext — that string becomes baseline context
# for every turn of the session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SKILL_FILE="$PLUGIN_ROOT/skills/deep-context/SKILL.md"

if [[ ! -r "$SKILL_FILE" ]]; then
    echo "opus-context: SKILL.md not readable at $SKILL_FILE, context injection skipped" >&2
    exit 0
fi

# Terminal-visible confirmation (stderr stays out of AI context).
echo "opus-context: 1M context rules injected into session context" >&2

python3 - "$SKILL_FILE" <<'PYEOF'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    raw = f.read()

# Strip the YAML frontmatter block at the top of the file.
body = re.sub(r"^---\n.*?\n---\n+", "", raw, count=1, flags=re.DOTALL).strip()

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": body,
    }
}))
PYEOF
