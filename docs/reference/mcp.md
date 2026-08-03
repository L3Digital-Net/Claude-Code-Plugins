---
title: MCP Integration Reference
category: integration
target_platform: linux
audience: ai_agent
keywords: [mcp, model-context-protocol, external-tools, integrations]
---

# MCP Integration Reference

Use the official [Plugins reference: MCP servers](https://code.claude.com/docs/en/plugins-reference#mcp-servers) and [Model Context Protocol documentation](https://modelcontextprotocol.io) for the current transport and server schema. Plugin-side MCP configuration belongs in `.mcp.json` at the plugin root.

## Repository Examples

`home-assistant-dev` uses a direct server map:

```json
{
	"ha-dev-mcp": {
		"command": "node",
		"args": ["${CLAUDE_PLUGIN_ROOT}/mcp-server/dist/server.bundle.cjs"]
	}
}
```

`qt-suite` uses an `mcpServers` wrapper and starts its bundled server through a shell script. Match the configuration form supported by the Claude Code version you target, then validate and reload the plugin.

```bash
claude plugin validate ./plugins/qt-suite
```

## Runtime Rules

- Keep executable code and configuration inside the plugin directory.
- Use `${CLAUDE_PLUGIN_ROOT}` for bundled paths.
- Reference credentials by environment-variable name; never put secret values in `.mcp.json` or repository documentation.
- Run `/reload-plugins` after editing an installed plugin.

## Related Reference

- [Plugins technical reference](./plugins-reference.md)
- [Plugin development guide](./guides/plugins.md)
- [Hooks](./hooks.md)
