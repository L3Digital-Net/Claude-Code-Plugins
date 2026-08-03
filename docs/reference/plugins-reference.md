---
title: Plugins Technical Reference
category: reference
target_platform: linux
audience: ai_agent
keywords: [reference, schema, manifest, cli, debugging]
---

# Plugins Technical Reference

Use the official [Plugins reference](https://code.claude.com/docs/en/plugins-reference) for the complete, versioned Claude Code interface. This page records the short, stable rules needed to work in this repository.

## File Layout

| Component | Default location | Repository example |
| --- | --- | --- |
| Manifest | `.claude-plugin/plugin.json` (optional) | every catalogued plugin |
| Skills | `skills/<name>/SKILL.md` | `home-assistant-dev` |
| Commands | `commands/*.md` | `qt-suite` |
| Agents | `agents/*.md` | `up-docs` |
| Hooks | `hooks/hooks.json` | `uv-strict-python` |
| MCP | `.mcp.json` | `home-assistant-dev`, `qt-suite` |
| LSP | `.lsp.json` | `uv-strict-python` |

When `plugin.json` is omitted, Claude Code discovers components at their default locations and derives the plugin name from the directory name. Add a manifest when the plugin needs metadata or non-default component paths.

## Manifest

`name` is the only required manifest field. Common metadata fields are `displayName`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, and `defaultEnabled`. Unknown top-level fields warn by default; validate with `--strict` when they must fail validation.

```json
{
	"name": "my-plugin",
	"displayName": "My Plugin",
	"version": "1.0.0",
	"description": "A concise description.",
	"repository": "https://github.com/example/my-plugin",
	"license": "MIT",
	"keywords": ["example"],
	"defaultEnabled": true
}
```

Use [the official manifest schema](https://code.claude.com/docs/en/plugins-reference#plugin-manifest-schema) for component-path fields and newer capabilities.

## Local Development and Validation

```bash
# Load a plugin from its source directory.
claude --plugin-dir ./my-plugin

# Validate a marketplace or plugin directory.
claude plugin validate .

# Enforce warnings as validation failures when needed.
claude plugin validate ./my-plugin --strict
```

After installing or editing a plugin, run `/reload-plugins` in the active Claude Code session to activate the change.

## Installation Scope and Cache

| Scope     | Settings file                 | Use                             |
| --------- | ----------------------------- | ------------------------------- |
| `user`    | `~/.claude/settings.json`     | personal, cross-project plugins |
| `project` | `.claude/settings.json`       | shared repository plugins       |
| `local`   | `.claude/settings.local.json` | personal repository plugins     |

Project-scope installation writes the plugin to `enabledPlugins` in `.claude/settings.json`. Marketplace installs are cached under `~/.claude/plugins/cache` in versioned install directories; do not reference files outside the installed plugin directory.

## Repository Checks

The repository's `scripts/validate-marketplace.sh` additionally checks the catalogue's source paths and version parity. Use it alongside the Claude Code validator when changing `.claude-plugin/marketplace.json`.

## Related Reference

- [Plugin development guide](./guides/plugins.md)
- [Plugin marketplaces](./plugin-marketplaces.md)
- [Skills](./skills.md), [sub-agents](./sub-agents.md), [hooks](./hooks.md), and [MCP](./mcp.md)
