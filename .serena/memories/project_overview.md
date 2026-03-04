# Claude-Code-Plugins: Project Overview

## Purpose
Claude Code plugin marketplace and development workspace.
- `main` branch: distribution (users install from here)
- `testing` branch: all development (permanent integration branch — never delete)
- GitHub blocks direct pushes to `main`

## Tech Stack
- **TypeScript** (primary): plugin-test-harness MCP server
- **Python**: home-assistant-dev, keepass-cred-mgr (pytest-based)
- **Bash**: scripts, hooks, linux-sysadmin skills
- **Zod**: marketplace schema validation

## Plugins (15 total)
- agent-orchestrator, design-assistant, docs-manager, github-repo-manager
- home-assistant-dev, keepass-cred-mgr, linux-sysadmin, plugin-review
- plugin-test-harness (TypeScript MCP server), qt-suite, python-dev
- release-pipeline, repo-hygiene, autonomous-refactor, qt-test-suite

## Key Files
- `.claude-plugin/marketplace.json` — marketplace catalog (Zod-validated, strict mode)
- `scripts/validate-marketplace.sh` — run before every merge to main
- `CLAUDE.md` — full design principles and workflow
- `docs/` — plugin dev reference docs
