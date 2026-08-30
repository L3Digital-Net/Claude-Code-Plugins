#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: install the PATH shims that intercept bare
# python/pip/pipx/uv-pip invocations — but only when a project opts in.
#
# The shims are NOT the enforcement layer for direct agent commands. That job
# belongs to the python-command-guard PreToolUse hook deployed from
# agent-configs (~/.claude/hooks/python-command-guard), which inspects the
# command Claude is about to run and blocks it before execution. A PreToolUse
# guard sees exactly the agent's own invocation, so it can refuse a bare
# `python` without affecting anything else in the session.
#
# The shims remain available as an opt-in tripwire for the invocations the
# guard cannot see (a subshell, a Makefile, a test harness). Their known cost
# is that they impersonate the interpreter for the whole process tree: a
# `#!/usr/bin/env python3` shebang and any child process spawned from the
# session resolve to the shim, not to a real interpreter, so unrelated
# tooling breaks in ways whose cause is far from the shim. That cost is why
# they are off unless a project asks for them.
#
# Opt in per project via .claude/uv-strict-python.local.md frontmatter:
#   shims: always   # install the shims for this project
# Any other value, and the absence of the file, leaves them uninstalled.

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

mode="off"
settings_file="$project_dir/.claude/uv-strict-python.local.md"
if [[ -f "$settings_file" ]]; then
  parsed="$(awk -F': *' '$1 == "shims" {print $2; exit}' "$settings_file" | tr -d '"' || true)"
  [[ -n "$parsed" ]] && mode="$parsed"
fi

# Gate before the guards below, so a session that never opted in emits no
# diagnostics about uv or CLAUDE_ENV_FILE it has no reason to care about.
[[ "$mode" == "always" ]] || exit 0

# Guard: only activate when uv is available
command -v uv &>/dev/null || exit 0

# Guard: CLAUDE_ENV_FILE must be set by the runtime
if [[ -z "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "uv-strict-python: CLAUDE_ENV_FILE not set; shims will not be installed" >&2
  exit 0
fi

shims_dir="$(cd "$(dirname "$0")/shims" && pwd)" || {
  echo "uv-strict-python: shims directory not found" >&2
  exit 1
}

echo "export PATH=\"${shims_dir}:\${PATH}\"" >>"$CLAUDE_ENV_FILE"
