#!/usr/bin/env python3
"""
SessionStart hook: emit lean startup context from docs/state.md +
git log + working-tree status. Target ≤4 KB additionalContext.

Exit codes:
  0 — always. Errors are embedded in the additionalContext payload as
      "(unavailable)" / "(failed)" markers; we never block session start.
"""
import json
import subprocess
import sys
import traceback
from pathlib import Path

STATE_FILE = Path("docs/state.md")
MAX_STATE_BYTES = 2048
MAX_STATUS_LINES = 10


def read_state() -> str:
    try:
        if not STATE_FILE.exists():
            return "(no docs/state.md — repo may not be migrated)"
        text = STATE_FILE.read_text(encoding="utf-8", errors="replace")
        if len(text) > MAX_STATE_BYTES:
            return text[:MAX_STATE_BYTES] + "\n\n... (truncated at 2 KB)"
        return text
    except Exception as e:
        return f"(failed to read docs/state.md: {e})"


def run(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(
            cmd, text=True, stderr=subprocess.DEVNULL, timeout=5
        ).strip()
    except Exception:
        return ""


def recent_commits() -> str:
    out = run(["git", "log", "--oneline", "-5", "--no-color"])
    return out or "(git log unavailable)"


def working_tree() -> str:
    out = run(["git", "status", "--short"])
    if not out:
        return "(clean)"
    lines = out.splitlines()
    if len(lines) > MAX_STATUS_LINES:
        return "\n".join(lines[:MAX_STATUS_LINES]) + \
               f"\n... +{len(lines) - MAX_STATUS_LINES} more"
    return out


def current_branch() -> str:
    return run(["git", "rev-parse", "--abbrev-ref", "HEAD"]) or "(unknown)"


def build_context() -> str:
    return (
        "=== SESSION START CONTEXT ===\n\n"
        f"## Branch\n{current_branch()}\n\n"
        f"## State (docs/state.md)\n{read_state()}\n\n"
        f"## Last 5 commits\n{recent_commits()}\n\n"
        f"## Working tree\n{working_tree()}\n\n"
        "## Pointers (read as needed)\n"
        "- docs/deployed.md — deployment truth\n"
        "- docs/architecture.md — system graph\n"
        "- docs/bugs/ — bug KB (grep by service or tag)\n"
        "- docs/sessions/ — historical log (grep by date)\n"
        "- docs/credentials.md — Bao path index\n"
        "- docs/conventions.md — pattern library\n\n"
        "=== END ==="
    )


def main() -> None:
    try:
        ctx = build_context()
    except Exception:
        # Last-resort guard so we never block session start on a hook bug.
        ctx = "(session_start.py failed: " + traceback.format_exc(limit=1) + ")"
    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": ctx,
        }
    }
    print(json.dumps(output))
    sys.exit(0)


if __name__ == "__main__":
    main()
