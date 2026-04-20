# Handoff

**Session handoff document for LLM consumption.** Read this first at the start of every session.

## Last Updated

- 2026-04-20 — Released up-docs 0.4.0 (sub-agent architecture), home-assistant-dev 2.2.6 (version sync), plugin-test-harness 0.7.4 (TypeScript config fixes), and qdev 1.2.1 (first release); added repo docs scaffold (handoff.md, conventions.md).

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Replace placeholder sections with repo-specific state as work progresses.

## Specs & Plans

- None recorded yet. Add design and implementation artifacts under `docs/specs/` and `docs/plans/` with ISO-8601-prefixed filenames.

## What Is Deployed

| Plugin | Version | Status |
|--------|---------|--------|
| up-docs | 0.4.0 | Released; sub-agent architecture active (Haiku propagators + Sonnet drift audit). GitHub release tag: `up-docs/v0.4.0` |
| home-assistant-dev | 2.2.6 | Released; stale version refs in DESIGN_DOCUMENT.md fixed. GitHub release tag: `home-assistant-dev/v2.2.6` |
| plugin-test-harness | 0.7.4 | Released; TypeScript config fixes (tsconfig types, jest transform). 50 tests now pass. GitHub release tag: `plugin-test-harness/v0.7.4` |
| qdev | 1.2.1 | Released; first-ever release (no prior tags). Added `missing_tests` waiver. GitHub release tag: `qdev/v1.2.1` |

## What Remains

- Verify up-docs sub-agents propagate correctly in next session (test `/up-docs:all` on a real repo with known changes).
- Monitor plugin-test-harness CI stability after TypeScript config fixes (jest transform improvements may affect other test suites).
- qdev requires ongoing maintenance (low activity, no tests, marked as markdown-only) — consider if it should be kept or archived.

## Bugs Found And Fixed

1. 2026-04-20 — home-assistant-dev DESIGN_DOCUMENT.md had stale version refs (2.2.2 vs 2.2.6). Fixed and released in 2.2.6.
2. 2026-04-20 — plugin-test-harness TypeScript config missing @types/jest in tsconfig types array; jest transform pointed at wrong config. Fixed and released in 0.7.4 (50 tests now pass, was 0).

## Architecture

**up-docs 0.4.0 (new architecture):**
- Orchestrator (main agent) receives session-change summary and dispatches three Haiku propagators in parallel: repo, wiki, notion.
- Each propagator runs in isolated context window with `model: haiku` frontmatter override; reads pages, applies targeted edits, returns markdown summary.
- Drift auditor (Sonnet) receives session-change summary after propagators complete; checks for contradictions in propagator output; emits convergence loop phases.
- Parallel dispatch reduces wall time to `max(repo, wiki, notion)` + drift; sequential phases protect consistency.

**All plugins:** follow plugin-marketplace canonical structure (plugin.json, CHANGELOG.md, README.md from template, optional agents/hooks/skills). 17 plugins total in marketplace.

## Credentials

- None required for plugin marketplace development (no external services, no OAuth, no API keys).
- CI uses standard GitHub token (GITHUB_TOKEN) for releases and MCP server publishing.

## Gotchas

- **Branch protection:** `main` branch is protected; direct pushes rejected. All development on `testing` branch; merge via `git merge testing --no-ff` when ready for release.
- **Marketplace cache:** `~/.claude/plugins/marketplaces/l3digitalnet-plugins/` is a git clone. Editing source repo `.claude-plugin/marketplace.json` does NOT auto-update cache — manually `git fetch && git reset --hard origin/main` or re-add the marketplace.
- **Plugin removal requires three updates:** `settings.json` (enabledPlugins), `installed_plugins.json` (load source of truth), and plugin cache directory. Editing settings.json alone leaves the plugin loaded.
- **MCP server .mcp.json is flat format, not wrapped:** `{"server-name": {"command": "..."}}` not `{"mcpServers": {"server-name": ...}}`. Incorrect format causes "invalid mcp" errors.
- **TypeScript plugins must `npm run build`** before testing — plugin install does not run npm/pip automatically.
- **Release pipeline expects matching versions:** plugin.json version and marketplace.json version must match. Validation catches these mismatches.
