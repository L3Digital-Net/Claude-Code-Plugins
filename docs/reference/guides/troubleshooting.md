---
title: Troubleshooting Guide
category: troubleshooting
target_platform: linux
audience: ai_agent
keywords: [debugging, errors, diagnostics, issues]
---

# Troubleshooting

For Claude Code diagnostics and installation recovery, use the official [troubleshooting guide](https://code.claude.com/docs/en/troubleshooting). Use the steps below for plugin and marketplace issues in this repository.

## Plugin Does Not Load

```bash
# Validate the repository marketplace or a standalone plugin directory.
claude plugin validate .
claude plugin validate ./plugins/qt-suite --strict
```

Then open `/plugin` and inspect its Errors view. Fix reported JSON or YAML frontmatter errors, then run `/reload-plugins` in the active session.

## Plugin Changes Are Not Active

Run `/reload-plugins` after installation or source changes. Restarting Claude Code has the same effect, but reload is faster for an active development loop.

## Plugin Is Installed in the Wrong Place

| Scope   | Settings file                 |
| ------- | ----------------------------- |
| User    | `~/.claude/settings.json`     |
| Project | `.claude/settings.json`       |
| Local   | `.claude/settings.local.json` |

Project scope records the plugin in `enabledPlugins` in `.claude/settings.json`. Move or reinstall the plugin with the intended scope rather than editing cache contents directly.

## Files Cannot Be Found After Installation

Marketplace installations are stored under `~/.claude/plugins/cache` in versioned directories. Keep every runtime file inside the plugin directory and reference bundled files with `${CLAUDE_PLUGIN_ROOT}` where applicable.

## Marketplace Does Not Validate

Confirm `.claude-plugin/marketplace.json` exists, then run:

```bash
claude plugin validate .
./scripts/validate-marketplace.sh
```

The Claude Code command is the public-interface validator. The repository script adds source-path and version-parity checks for this catalogue.

## Related Reference

- [Plugin discovery](./discover-plugins.md)
- [Plugin marketplaces](../plugin-marketplaces.md)
- [Plugins technical reference](../plugins-reference.md)
