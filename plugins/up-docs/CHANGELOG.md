# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.5.0] - 2026-04-20

### Added
- `up-docs-propagate-repo` agent now performs a **mandatory audit** of `docs/handoff.md` and `docs/conventions.md` on every run (when either file exists). The audit covers each `docs/handoff.md` schema section (Last Updated, What Is Deployed, What Remains, Bugs Found And Fixed, Architecture, Credentials, Gotchas) and extracts any session-durable pattern into `docs/conventions.md` using the six-field schema + Quick Reference row. Both files always appear in the propagator's output table as explicit rows — never silently omitted.
- `up-docs-propagate-repo` agent `<writing_style>` block codifies the repo-doc audience split: `README.md` files are human-facing prose; `CLAUDE.md`, `AGENTS.md`, and everything under `docs/` are LLM-facing (terse, scannable, tables over narrative). The agent preserves existing style when extending a file.
- `/up-docs:repo` and `/up-docs:all` skills now emit a **"Handoff for Next Session" brief** after the propagator table. The brief is a scannable read-only excerpt of the updated `docs/handoff.md` (Last Updated, Currently Deployed, Open Items, Open Bugs, Gotchas) meant to bridge session boundaries.

### Changed
- `up-docs-propagate-repo` guardrails explicitly allow the mandatory `docs/handoff.md` + `docs/conventions.md` audit as an exception to the "only act on items in the session-change summary" rule.


## [0.4.1] - 2026-04-20

### Fixed
- Orchestrator and wrapper skills now pass the plugin-namespaced `subagent_type` (`up-docs:up-docs-propagate-repo`, etc.) to the Agent tool. Previous bare-name strings (`up-docs-propagate-repo`) caused "Agent type not found" errors because Claude Code only addresses plugin-defined agents through their plugin namespace. Affected: `skills/all/SKILL.md`, `skills/repo/SKILL.md`, `skills/wiki/SKILL.md`, `skills/notion/SKILL.md`, `skills/drift/SKILL.md`.


## [0.4.0] - 2026-04-19

### Added
- Four sub-agents under `agents/`: `up-docs-propagate-repo`, `up-docs-propagate-wiki`, `up-docs-propagate-notion` (all Haiku), and `up-docs-audit-drift` (Sonnet). Each runs in its own context window with per-agent `model:` frontmatter overriding the caller's model tier.
- `templates/session-change-summary.md` — canonical format for the orchestrator's numbered change list; the single critical artifact consumed by every sub-agent.
- `templates/drift-finding.md` — dual-form (JSON + markdown) output contract for the drift auditor, including escalation triggers.

### Changed
- `/up-docs:all` orchestrates rather than executes: builds the session-change summary, dispatches three propagators in parallel via the Agent tool (formerly Task; renamed in Claude Code v2.1.63), then sequentially dispatches the drift auditor. Main-agent context stays slim — sub-agents read and edit pages in their own isolated contexts.
- `/up-docs:repo`, `/up-docs:wiki`, `/up-docs:notion`, `/up-docs:drift` are now thin wrappers that dispatch their single matching sub-agent. Layer guidelines and Notion content rules are inlined into sub-agent system prompts (no runtime `Read` on `references/notion-guidelines.md` from the propagator).
- Cost model: propagation runs on Haiku (≈ 1/10 the cost of Opus) while preserving Sonnet-quality drift detection. Parallel dispatch reduces wall time to `max(repo, wiki, notion)` instead of their sum.

### Fixed
- Opus escalation is now surfaced as an advisory block in the combined report rather than silently consuming Opus budget on routine drift passes. User decides whether to re-run with Opus.
- Agent prompts rewritten for Anthropic canonical patterns: XML tag structure (`<role>`, `<task>`, `<guardrails>`, `<examples>`, `<output_format>`), 5 worked few-shot examples per agent, canonical "Never speculate about X you have not read" grounding language, and commit-to-approach anti-flip-flop guidance. Particularly beneficial for the 3 Haiku propagators, which are more example-dependent than Sonnet.
- Drift auditor prompt now cross-checks propagator reports before emitting findings, preventing double-dispatch on a re-propagation pass.


## [0.3.0] - 2026-04-09

### Added
- add 4 scripts for context gathering, server inspection, link auditing, convergence tracking

### Changed
- pass 3 — close remaining gaps, 293 total tests across 9 plugins
- close gap analysis findings, 247 total tests across 9 plugins
- add 166 bats tests across 9 plugins for new scripts

### Fixed
- add handoff to root README, fix up-docs skill names


## [0.3.0] - 2026-04-09

### Added
- `scripts/context-gather.sh` consolidating git context assessment for all 5 skills
- `scripts/server-inspect.sh` batching 5-15 SSH commands per host into a single session
- `scripts/link-audit.sh` for markdown link extraction and verification
- `scripts/convergence-tracker.sh` for managing iteration state across drift analysis phases

### Changed
- All 5 skill files (repo, wiki, notion, all, drift) now use context-gather.sh for session context
- `skills/drift/SKILL.md` Phase 1 uses server-inspect.sh and convergence-tracker.sh
- `skills/drift/SKILL.md` Phase 3 uses link-audit.sh for external link verification

## [0.2.0] - 2026-03-28

### Added

- `/up-docs:drift` command for comprehensive drift analysis: SSHes into live infrastructure, syncs Outline wiki across four convergence phases (infrastructure sync, wiki consistency, link integrity, Notion update)
- Server inspection reference with patterns for systemd, Docker, web servers, databases, DNS, VPN, monitoring, and backup services
- Convergence tracking reference with iteration mechanics, oscillation detection, and narrowing strategy

## [0.1.0] - 2026-03-28

### Added

- `/up-docs:repo` command to update repository documentation (README.md, docs/, CLAUDE.md)
- `/up-docs:wiki` command to update Outline wiki with implementation-level details
- `/up-docs:notion` command to update Notion with strategic and organizational context
- `/up-docs:all` command to update all three layers sequentially
- Summary report template for consistent output formatting across all commands
- Notion content guidelines reference document
