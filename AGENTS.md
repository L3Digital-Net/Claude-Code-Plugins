# Codex Instructions for Claude-Code-Plugins

**Session state:** Agent Handoff SessionStart injects `docs/handoff/state.md`; do not reread it when injected. Then use this file and `docs/handoff/conventions.md`.

**Full conventions reference:** [`docs/handoff/conventions.md`](docs/handoff/conventions.md) - LLM-targeted pattern library. Every convention follows the six-field schema (Applies-when / Rule / Code / Why / Sources / Related) with a Quick Reference table at the top for O(1) lookup. Do not introduce new patterns without checking conventions first.

**Detailed review workflows:** [AGENTS.reviews.md](AGENTS.reviews.md) - read this only for review-related tasks (review planning, review sweeps, code/security/test/etc. reviews). The verbose per-review routing, defaults, and orchestrator notes live there.

## Repo Purpose

Plugin authoring and release workspace for Claude Code / Codex plugins.

## Key Rules

- Treat the design specs indexed in `docs/handoff/specs-plans.md` (stored under `docs/plans/`, `docs/research/`, and `docs/superpowers/{specs,plans}/`) as the architectural source of truth for plugin behavior; the marketplace schema lives in `docs/handoff/architecture.md`.
- Keep `.claude-plugin/plugin.json`, plugin folders, command wiring, and marketplace metadata in sync.
- Validate substantive plugin changes with the plugin test harness before wrapping up.
- Preserve documented enforcement layers, hooks, and release expectations when refactoring.
- **Branch workflow:** direct commit to `main`. No `testing` branch — that convention was retired 2026-05-07. Plugin releases are manual: bump `plugin.json` and the matching `.claude-plugin/marketplace.json` entry, commit, tag `<name>/vX.Y.Z`, push, and `gh release create`. See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md).

## Markdown & Structured-Text Tooling

This repository follows the Markdown Tooling Standard (project-standards v3.0.0). Prettier formats the structured-text it supports (`md`/`json`/`jsonc`/`yaml`/`code-workspace`); markdownlint lints Markdown structure only. JS/TS source is excluded from Prettier via `.prettierignore`. MD060 is enabled at `{style: "leading_and_trailing", aligned_delimiter: false}` (Prettier-compatible; the standard's `{style: "any"}` conflicts with Prettier's empty-cell rendering). Both deviations recorded in [`docs/decisions/adr-0001-prettier-jsts-scope.md`](docs/decisions/adr-0001-prettier-jsts-scope.md). Do not introduce a competing formatter or linter.

### Fix pass

When changing Markdown, JSON, JSONC, or YAML, run the fix pass first:

```bash
npx prettier --write .
npx markdownlint-cli2 --fix "**/*.md"
```

### Check contract

Before considering work complete, run the non-mutating check:

```bash
npx prettier --check .
npx markdownlint-cli2 "**/*.md"
```

Do not claim completion if either command fails.

### Rules

- Prettier owns physical formatting. Do not fight its output or hand-format.
- markdownlint owns Markdown structure. Do not disable a rule to silence a warning — fix the Markdown.
- Do not edit `.prettierrc.json` or `.markdownlint.json` to bypass a check without a documented ADR exception.

<!-- prettier-ignore-start -->

<!-- BEGIN project-standards:agent-handoff -->
<!-- markdownlint-disable MD025 -->
# Agent Handoff

Use the repo-local `agent-handoff` skill at session startup and closeout. Do not reread state already injected by SessionStart. Keep project knowledge inside this repository and store credential references only, never values.
<!-- markdownlint-enable MD025 -->
<!-- END project-standards:agent-handoff -->

<!-- prettier-ignore-end -->

<!-- prettier-ignore-start -->

<!-- BEGIN project-standards:markdown-tooling -->
<!-- markdownlint-disable MD025 -->
# Markdown and structured-text tooling

Prettier owns physical formatting and markdownlint owns Markdown structure. Do not add overlapping tools.

Enabled checks: format, lint.
Markdown scope: `**/*.md`.
Structured-config scope: `**/*.json`, `**/*.jsonc`, `**/*.yml`, `**/*.yaml`.
Lint additionally skips generated directories: `.pytest_cache/**`, `.ruff_cache/**`, `.venv/**`, `node_modules/**`.

Run the enabled checks before claiming completion.
<!-- markdownlint-enable MD025 -->
<!-- END project-standards:markdown-tooling -->

<!-- prettier-ignore-end -->
