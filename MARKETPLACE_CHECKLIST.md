# Marketplace Checklist

This checklist reflects this marketplace's checked-in structure. Use the Claude Code validator for the current runtime schema; `scripts/validate-marketplace.sh` is the repository's supplemental consistency check.

## Required Files ✓

- [x] `.claude-plugin/marketplace.json` - Marketplace catalog
- [x] `README.md` - Installation and usage instructions
- [x] `LICENSE` - License file

## Marketplace JSON Structure ✓

Required root fields in `.claude-plugin/marketplace.json`:

- [x] `name` - Marketplace identifier
- [x] `owner` - Object containing at least `name`
- [x] `plugins` - Array of plugin entries

Do not add these root fields; the checked schema rejects them:

- `version`
- `homepage`
- `repository`
- `license`

## Plugin Entries ✓

Each plugin in the `plugins` array must have:

- [x] `name` - Plugin identifier (matches plugin manifest)
- [x] `description` - Brief description
- [x] `source` - Relative plugin path or external-source object

Optional:

- [x] `version` - Must match the local `plugin.json` when both are present
- [x] `author` - Object containing plugin-author information
- [x] `homepage` - Plugin documentation URL

Do not use `displayName`, `keywords`, or `license` in a marketplace entry; the checked schema rejects them.

## Plugin Structure

Each active marketplace entry must point to a plugin directory containing:

- [x] `.claude-plugin/plugin.json` (or the legacy `manifest.json`)
- [x] `README.md` - Plugin documentation
- [ ] At least one component (commands/, skills/, agents/, hooks/)

The active catalog contains:

- `home-assistant-dev`
- `qt-suite`
- `up-docs`
- `uv-strict-python`
- `spec-pipeline`

The retired `plugins/qdev/` source is intentionally retained but is not a marketplace entry.

## Validation Commands

```bash
# Validate the marketplace with the installed Claude Code runtime
claude plugin validate .

# Check this repository's marketplace entries, local manifests, names, and versions
./scripts/validate-marketplace.sh
```

## Testing Installation

```bash
# Add marketplace locally
/plugin marketplace add /path/to/Claude-Code-Plugins

# Install an active plugin
/plugin install home-assistant-dev@l3digitalnet-plugins

# Verify plugin loaded
/plugin list
```

## Distribution

Once pushed to GitHub, users can install with:

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install home-assistant-dev@l3digitalnet-plugins
```

## Updating the Marketplace

When adding or updating plugins:

1. Update plugin files in `plugins/`
2. Update plugin entry in `.claude-plugin/marketplace.json`
3. Keep the marketplace and plugin manifest versions identical when the marketplace entry includes a version.
4. Update the relevant README and CHANGELOG.
5. Run `./scripts/validate-marketplace.sh`.
6. Commit and push to GitHub.
