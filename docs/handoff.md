# Handoff

**Session handoff document for LLM consumption.** Read this first at the start of every session.

## Last Updated

- 2026-04-20 — Released up-docs 0.5.1 (fixed `up-docs-audit-drift` evidence fabrication — added `<verification_discipline>` block with sanctioned omit/unverifiable responses when verification commands fail; "unverifiable" confidence value added; template evidence-field guard strengthened).
- 2026-04-20 — Released up-docs 0.5.0 (mandatory handoff.md + conventions.md audit in propagate-repo; repo-doc human/LLM audience split codified; Handoff for Next Session brief emitted by `/up-docs:repo` and `/up-docs:all`). Added PLUGIN-001 convention (plugin-namespaced `subagent_type`) and expanded DOC-001 to make human/LLM audience split explicit.
- 2026-04-20 — Released up-docs 0.4.1 (fixed plugin-namespaced subagent_type in five skills to resolve "Agent type not found" errors). Prior: Released up-docs 0.4.0, home-assistant-dev 2.2.6, plugin-test-harness 0.7.4, qdev 1.2.1; added repo docs scaffold; ran `/up-docs:all` (verified sub-agent architecture + 3 drift fixes applied); ran `/hygiene` (qdev added to root README table/section/tree).

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Replace placeholder sections with repo-specific state as work progresses.

## Specs & Plans

- None recorded yet. Add design and implementation artifacts under `docs/specs/` and `docs/plans/` with ISO-8601-prefixed filenames.

## What Is Deployed

| Plugin | Version | Status |
|--------|---------|--------|
| up-docs | 0.5.1 | Released; audit-drift agent no longer fabricates verification evidence — new `<verification_discipline>` block with omit/unverifiable escape paths; template evidence-field guard tightened. Prior 0.5.0: mandatory handoff.md + conventions.md audit in propagate-repo; human/LLM audience split; Handoff-for-Next-Session brief. GitHub release tag: `up-docs/v0.5.1` |
| home-assistant-dev | 2.2.6 | Released; stale version refs in DESIGN_DOCUMENT.md fixed. GitHub release tag: `home-assistant-dev/v2.2.6` |
| plugin-test-harness | 0.7.4 | Released; TypeScript config fixes (tsconfig types, jest transform). 50 tests now pass. GitHub release tag: `plugin-test-harness/v0.7.4` |
| qdev | 1.2.1 | Released; first-ever release (no prior tags). Added `missing_tests` waiver. GitHub release tag: `qdev/v1.2.1` |

## What Remains

- Monitor plugin-test-harness CI stability after TypeScript config fixes (jest transform improvements may affect other test suites).
- qdev requires ongoing maintenance (low activity, no tests, markdown-only) — consider if it should be kept or archived.
- release-pipeline and linux-sysadmin READMEs each need a short table section added (Agents and Hooks respectively); see hygiene sweep notes in session context.

## Bugs Found And Fixed

1. 2026-04-20 — home-assistant-dev DESIGN_DOCUMENT.md had stale version refs (2.2.2 vs 2.2.6). Fixed and released in 2.2.6.
2. 2026-04-20 — plugin-test-harness TypeScript config missing @types/jest in tsconfig types array; jest transform pointed at wrong config. Fixed and released in 0.7.4 (50 tests now pass, was 0).
3. 2026-04-20 — up-docs orchestrator and five wrapper skills dispatched sub-agents with bare names (e.g. "up-docs-propagate-repo") instead of plugin-namespaced form (e.g. "up-docs:up-docs-propagate-repo"), causing "Agent type not found" errors. Fixed all five skills and released in 0.4.1.
4. 2026-04-20 — `up-docs-audit-drift` agent fabricated verification evidence (reported Hermes v0.8.0 → v1.0.0 drift with invented `version.txt` file output). Root cause: prompt required `evidence` field on every finding without sanctioned escape for command failure, creating completeness pressure that won over accuracy. Fixed by adding `<verification_discipline>` block with omit/unverifiable escape paths, a worked example for the failure case, and a tightened evidence-field rule in the template. Released in 0.5.1.

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
