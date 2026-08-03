---
title: Plugin Discovery and Installation
category: user-guide
target_platform: linux
audience: ai_agent
keywords: [plugins, installation, marketplace, discovery]
---

# Plugin Discovery and Installation

Use the official [Discover plugins](https://code.claude.com/docs/en/discover-plugins) guide to browse the current marketplace inventory. Marketplace catalogues change independently of this repository, so this guide does not duplicate them.

## Install This Marketplace

```text
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install <plugin>@l3digitalnet-plugins
/reload-plugins
```

`/reload-plugins` activates an installed plugin in the current session. Plugin commands are namespaced, for example `/qt-suite:run`.

## Choose a Scope

| Scope   | Intended use                 | Settings file                 |
| ------- | ---------------------------- | ----------------------------- |
| User    | personal, all projects       | `~/.claude/settings.json`     |
| Project | all repository collaborators | `.claude/settings.json`       |
| Local   | one user in one repository   | `.claude/settings.local.json` |

Project scope records the plugin under `enabledPlugins` in `.claude/settings.json`. Use local scope for a personal trial that should not be shared with collaborators.

## Troubleshooting

- Validate a local checkout with `claude plugin validate .`.
- Check plugin state with `/plugin`.
- Reload the active session after an install or source edit.
- Marketplace installations live in versioned directories under `~/.claude/plugins/cache`; plugins must not depend on paths outside their installed directory.

See [Troubleshooting](./troubleshooting.md) for the concise recovery path and the official guide for current marketplace commands.

## Related Reference

- [Plugin marketplaces](../plugin-marketplaces.md)
- [Plugin development](./plugins.md)
- [Plugins technical reference](../plugins-reference.md)
