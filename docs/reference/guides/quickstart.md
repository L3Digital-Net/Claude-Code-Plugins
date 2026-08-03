---
title: Claude Code Quickstart
category: getting-started
target_platform: linux
audience: ai_agent
keywords: [installation, setup, authentication, basic-usage]
---

# Quickstart

Install and authenticate Claude Code using the current [official quickstart](https://code.claude.com/docs/en/quickstart). This repository documents its plugin workflow below rather than duplicating version-sensitive installation or authentication steps.

## Use a Local Plugin

```bash
claude --plugin-dir ./my-plugin
```

After changing an installed or locally loaded plugin, run `/reload-plugins` in the active session.

## Install from This Marketplace

```text
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install <plugin>@l3digitalnet-plugins
/reload-plugins
```

Use `/plugin` to inspect installed plugins and errors. Project-scope installs write `enabledPlugins` to `.claude/settings.json`; local-scope installs use `.claude/settings.local.json`.

## Verify a Plugin Checkout

```bash
claude plugin validate .
```

Use `--strict` if unrecognized manifest fields must fail validation.

## Further Reading

- [Plugin discovery](./discover-plugins.md)
- [Plugin development](./plugins.md)
- [Troubleshooting](./troubleshooting.md)
- [Plugins technical reference](../plugins-reference.md)
