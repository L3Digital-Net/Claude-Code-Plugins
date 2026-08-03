---
title: Plugin Marketplace Creation
category: distribution
target_platform: linux
audience: ai_agent
keywords: [marketplace, distribution, publishing, catalog]
---

# Plugin Marketplace Creation

See the official [plugin marketplaces guide](https://code.claude.com/docs/en/plugin-marketplaces) for source formats, marketplace schema, and installation options. Keep this repository's catalogue in `.claude-plugin/marketplace.json`.

## Current Repository Catalog

| Plugin               | Version  | Source                         |
| -------------------- | -------- | ------------------------------ |
| `home-assistant-dev` | `2.2.11` | `./plugins/home-assistant-dev` |
| `qt-suite`           | `0.3.4`  | `./plugins/qt-suite`           |
| `up-docs`            | `0.13.1` | `./plugins/up-docs`            |
| `uv-strict-python`   | `0.2.1`  | `./plugins/uv-strict-python`   |
| `spec-pipeline`      | `0.2.0`  | `./plugins/spec-pipeline`      |

`qdev` remains in the working tree but is intentionally not offered by this marketplace.

## Validate Before Publishing

```bash
# Claude Code validates the marketplace or plugin directory.
claude plugin validate .

# Repository-specific catalogue and source-parity checks.
./scripts/validate-marketplace.sh
```

`claude plugin validate .` is the authoritative interface validation. Add `--strict` when unrecognized manifest fields must fail instead of warn.

## Install and Reload

```text
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install <plugin>@l3digitalnet-plugins
/reload-plugins
```

An installation affects the active session only after `/reload-plugins` (or a restart). Choose the installation scope deliberately: project scope records `enabledPlugins` in `.claude/settings.json`, while local scope uses `.claude/settings.local.json`.

## Release Discipline

For a released plugin, keep its marketplace entry and `plugin.json` version in sync, then follow the manual release sequence in `AGENTS.md`: commit, tag `<name>/vX.Y.Z`, push, and create the GitHub release. A routine documentation or catalogue edit is not a release.

## Related Reference

- [Plugins technical reference](./plugins-reference.md)
- [Plugin development guide](./guides/plugins.md)
- [Plugin discovery](./guides/discover-plugins.md)
