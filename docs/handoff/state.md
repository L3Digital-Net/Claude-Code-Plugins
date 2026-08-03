# Handoff State

## Current focus

- Run the `spec-pipeline` live smoke test after plugin installation and cache sync.
- Obtain the user's decision on deprecating the two source skills in `agent-configs`.
- Work the remaining `docs/TODO.md` queue: uv-strict-python LSP verification and HA MCP CI.

## Active incidents

- Home Assistant MCP end-to-end CI remains red because the test container loads no demo entities;
  - 13 tests pass and 10 entity assertions fail.
- Agent Handoff validation and drift checking are unavailable because the selected package is not reconciled.
