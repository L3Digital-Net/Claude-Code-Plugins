#!/usr/bin/env bash
set -euo pipefail

# check-stale-commits.sh — Check 5 of 5: stale uncommitted file scanner
# Called from: /hygiene command (hygiene.md Step 1) in parallel with check-gitignore.sh,
#              check-manifests.sh, and check-orphans.sh.
# Output contract: JSON {check: "stale-commits", findings: [...]} to stdout.
#                  On error: JSON {check: "stale-commits", error: "<msg>", findings: []} to stdout + exit 1.
# findings entries: {severity: "warn", path, detail, auto_fix: false, fix_cmd: null}
# All findings are needs-approval — staging/committing requires user intent.

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

python3 - "$REPO_ROOT" << 'PYTHON_EOF'
import json, os, sys, subprocess, time

repo_root = sys.argv[1]
cutoff = time.time() - 86400  # 24 hours ago

try:
    result = subprocess.run(
        ["git", "-C", repo_root, "status", "--porcelain"],
        capture_output=True, text=True, check=True
    )
except Exception as e:
    print(json.dumps({"check": "stale-commits", "error": str(e), "findings": []}))
    sys.exit(1)

findings = []
for line in result.stdout.splitlines():
    if not line.strip():
        continue
    xy = line[:2]      # two-char status code
    filepath = line[3:].strip()

    # Handle renamed files: "old -> new"
    if " -> " in filepath:
        filepath = filepath.split(" -> ")[-1]

    # Prefer worktree status char (xy[1]); fall back to index char (xy[0])
    status_char = xy[1].strip() or xy[0].strip() or "?"

    abs_path = os.path.join(repo_root, filepath)
    if not os.path.exists(abs_path):
        continue  # deleted file — skip

    mtime = os.stat(abs_path).st_mtime
    if mtime < cutoff:
        age_secs = int(time.time() - mtime)
        age_h = age_secs // 3600
        age_d = age_h // 24
        age_str = f"{age_d}d {age_h % 24}h" if age_d > 0 else f"{age_h}h"

        findings.append({
            "severity": "warn",
            "path": filepath,
            "detail": f"Uncommitted '{status_char}' file last modified {age_str} ago",
            "auto_fix": False,
            "fix_cmd": None
        })

print(json.dumps({"check": "stale-commits", "findings": findings}))
PYTHON_EOF
