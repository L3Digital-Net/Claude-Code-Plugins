# Codex Instructions for Claude-Code-Plugins

**Session handoff:** [`docs/handoff.md`](docs/handoff.md) - read this first. Current deployed state, remaining work, bugs log, architecture, credential locations / required env vars / secret names (never secret values), and gotchas.

**Full conventions reference:** [`docs/conventions.md`](docs/conventions.md) - LLM-targeted pattern library. Every convention follows the six-field schema (Applies-when / Rule / Code / Why / Sources / Related) with a Quick Reference table at the top for O(1) lookup. Do not introduce new patterns without checking conventions first.

**Detailed review workflows:** [AGENTS.reviews.md](AGENTS.reviews.md) - read this only for review-related tasks (review planning, review sweeps, code/security/test/etc. reviews). The verbose per-review routing, defaults, and orchestrator notes live there.

## Repo Purpose

Plugin authoring and release workspace for Claude Code / Codex plugins.

## Key Rules

- Treat `docs/specs/` as the architectural source of truth for plugin behavior and marketplace schema.
- Keep `.codex-plugin/plugin.json`, plugin folders, command wiring, and marketplace metadata in sync.
- Validate substantive plugin changes with the plugin test harness before wrapping up.
- Preserve documented enforcement layers, hooks, and release-pipeline expectations when refactoring.
