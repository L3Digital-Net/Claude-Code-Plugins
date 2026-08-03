---
title: Hooks Reference
category: automation
target_platform: linux
audience: ai_agent
keywords: [hooks, lifecycle, events, automation, triggers]
---

# Hooks Reference

Use the official [hooks reference](https://code.claude.com/docs/en/hooks) for the complete event list and input/output contracts. This repository keeps hook configuration at `hooks/hooks.json` in the plugin root.

## Checked-In Pattern

```json
{
	"hooks": {
		"PostToolUse": [
			{
				"matcher": "Write|Edit|MultiEdit|NotebookEdit",
				"hooks": [
					{
						"type": "command",
						"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/post-write-hook.sh"
					}
				]
			}
		]
	}
}
```

`home-assistant-dev` uses this `PostToolUse` dispatcher, `up-docs` observes `Bash` calls, and `uv-strict-python` uses `SessionStart` for its PATH-shim setup. Keep hook scripts inside the plugin and resolve them via `${CLAUDE_PLUGIN_ROOT}`.

## Develop and Verify

1. Keep `hooks` as an object keyed by event name.
2. Use a specific matcher and a small dispatcher script when multiple files need different handling.
3. Parse tool data from the documented hook input instead of relying on undocumented shell variables.
4. Run `claude plugin validate <plugin-directory>` and reload the plugin before testing the event.

## Related Reference

- [Plugin development guide](./guides/plugins.md)
- [Plugins technical reference](./plugins-reference.md)
- [MCP](./mcp.md)
