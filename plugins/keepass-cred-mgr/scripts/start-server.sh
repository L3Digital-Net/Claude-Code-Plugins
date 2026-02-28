#!/usr/bin/env bash
# MCP server launcher — resolves dependencies via uv and starts the FastMCP server.
# Called by Claude Code via .mcp.json; stdout is reserved for the MCP protocol.
# If scripts/fake-tools/ exists (PTH testing), those binaries shadow the real ones.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

export KEEPASS_CRED_MGR_CONFIG="${KEEPASS_CRED_MGR_CONFIG:-${HOME}/.config/keepass-cred-mgr/config.yaml}"

# Prepend fake tools to PATH when the directory exists (used during PTH sessions)
FAKE_TOOLS_DIR="${PLUGIN_ROOT}/scripts/fake-tools"
if [[ -d "$FAKE_TOOLS_DIR" ]]; then
    export PATH="${FAKE_TOOLS_DIR}:${PATH}"
fi

exec uv run --directory "$PLUGIN_ROOT" --with "mcp,structlog,pyyaml,filelock" python3 -m server.main
