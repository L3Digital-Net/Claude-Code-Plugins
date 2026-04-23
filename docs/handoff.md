# Handoff

**Session handoff document for LLM consumption.** Read this first at the start of every session.

## Last Updated

- 2026-04-23 — Plugin delegation migration Phase 1–3 + 6 merged to main: opus-context 1.1.0 (SessionStart hook now injects skill context mechanically as JSON), home-assistant-dev 2.2.7 (ha-integration-reviewer downgrade haiku), qt-suite 0.3.1 (gui-tester + test-generator explicit sonnet), qdev 1.3.0 (three new agents + thin command orchestrators), repo-hygiene 1.4.0 (semantic audit split to Haiku subagent), python-dev 1.1.0 (code-review thin dispatcher + Sonnet agent). Released all six plugins to main via signed annotated tags. Added design pattern doc: `docs/plans/2026-04-23-plugin-delegation-migration.md`. Skipped phases 4–5 per design review: nominal:postflight has per-domain interactive loop incompatible with delegation; test-driver has explicit function-level enumeration scoped to Claude per design comment.
- 2026-04-20 — Polish/cleanup pass: release-pipeline 2.1.2 (README section rename `Pre-flight Agents` → `Agents`), linux-sysadmin 2.1.2 (README `## Hooks` section added), up-docs 0.6.0 (new handoff.md pruning + permission-gated stale-file scan in propagate-repo; drift auditor stats enum pinned to five required keys). Confirmed qdev stays.
- 2026-04-20 — Released up-docs 0.5.1 (fixed `up-docs-audit-drift` evidence fabrication — added `<verification_discipline>` block with sanctioned omit/unverifiable responses when verification commands fail; "unverifiable" confidence value added; template evidence-field guard strengthened).
- 2026-04-20 — Released up-docs 0.5.0 (mandatory handoff.md + conventions.md audit in propagate-repo; repo-doc human/LLM audience split codified; Handoff for Next Session brief emitted by `/up-docs:repo` and `/up-docs:all`). Added PLUGIN-001 convention (plugin-namespaced `subagent_type`) and expanded DOC-001 to make human/LLM audience split explicit.

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Replace placeholder sections with repo-specific state as work progresses.

## Specs & Plans

- None recorded yet. Add design and implementation artifacts under `docs/specs/` and `docs/plans/` with ISO-8601-prefixed filenames.

## What Is Deployed

| Plugin | Version | Status |
|--------|---------|--------|
| opus-context | 1.1.0 | Released 2026-04-23; SessionStart hook rewritten to read skill body, strip YAML frontmatter, and mechanically inject JSON `hookSpecificOutput` into context window (guarantees rules present on every turn vs. optional via skill tool). SKILL.md tightened 1000 → 350 tokens; terminal banner moved to stderr. GitHub release tag: `opus-context/v1.1.0` |
| home-assistant-dev | 2.2.7 | Released 2026-04-23; ha-integration-reviewer agent downgraded haiku (structural review is mechanical pattern-matching). GitHub release tag: `home-assistant-dev/v2.2.7` |
| qt-suite | 0.3.1 | Released 2026-04-23; gui-tester and test-generator agents explicitly set model: sonnet (was inherit, resolved to opus on opus sessions; ~5x cost reduction per invocation). GitHub release tag: `qt-suite/v0.3.1` |
| qdev | 1.3.0 | Released 2026-04-23; three new agents (qdev-deps-auditor haiku, qdev-quality-reviewer sonnet, qdev-doc-syncer haiku) with grunt work split out; commands rewritten as thin orchestrators (~50K tokens weekly savings). Prior 1.2.1: first release. GitHub release tag: `qdev/v1.3.0` |
| repo-hygiene | 1.4.0 | Released 2026-04-23; semantic audit (Step 2) split to hygiene-semantic-auditor haiku subagent; Step 1 (seven mechanical scripts) unchanged (~15K tokens per run reduction). GitHub release tag: `repo-hygiene/v1.4.0` |
| python-dev | 1.1.0 | Released 2026-04-23; code-review command rewritten as thin dispatcher; 11 domain rules moved to python-code-reviewer sonnet agent (~20K tokens per review reduction). GitHub release tag: `python-dev/v1.1.0` |
| up-docs | 0.6.0 | Released; propagate-repo agent now performs handoff.md pruning (retain most recent 5 Last Updated entries; Bugs Found And Fixed never pruned) and permission-gated stale-file scan (plans/specs/dated `.md` with completion markers + shipped work + >60 days → surfaced as candidates; skill asks via AskUserQuestion; deletion only on explicit consent via `git rm`). Includes drift-auditor stats-key enum pinning. Prior 0.5.1: verification_discipline; evidence-field guard. Prior 0.5.0: mandatory handoff+conventions audit; audience split; Handoff-for-Next-Session brief. GitHub release tag: `up-docs/v0.6.0` |
| release-pipeline | 2.1.2 | Released; README section rename for template compliance. GitHub release tag: `release-pipeline/v2.1.2` |
| linux-sysadmin | 2.1.2 | Released; README `## Hooks` section added documenting the SessionStart context-injection hook. GitHub release tag: `linux-sysadmin/v2.1.2` |
| plugin-test-harness | 0.7.4 | Released; TypeScript config fixes (tsconfig types, jest transform). 50 tests now pass. GitHub release tag: `plugin-test-harness/v0.7.4` |

## What Remains

- Monitor plugin-test-harness CI stability after TypeScript config fixes (jest transform improvements may affect other test suites).

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
