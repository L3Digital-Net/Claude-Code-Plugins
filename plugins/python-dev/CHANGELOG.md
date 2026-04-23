# Changelog

All notable changes to the python-dev plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-23

### Changed

- `/python-code-review` is now a thin orchestrator that dispatches the new `python-code-reviewer` subagent (Sonnet) instead of walking Opus through 11 domain audits inline. The 11 domain rules moved from the command body into the agent prompt. Estimated ~20K tokens saved per review when invoked from Opus sessions.

### Added

- `plugins/python-dev/agents/python-code-reviewer.md` — Sonnet agent that runs all 11 domain passes (anti-patterns, type safety, design, style, resources, resilience, configuration, observability, testing, async, background jobs) and returns a prioritized findings report.

## [1.0.1] - 2026-03-04

### Changed
- update org references from L3Digital-Net to L3DigitalNet

### Fixed
- apply /hygiene sweep fixes — em dashes, root README python-dev entry
- apply audit findings — factual errors, docs, UX


## [Unreleased]

## [1.0.0] - 2026-03-02

### Added

- 11 Python development skills with automatic context-triggered loading:
  - `python-anti-patterns`: checklist of common Python bugs and structural mistakes
  - `python-type-safety`: type hints, generics, Protocol, TypeVar, mypy/pyright
  - `python-design-patterns`: KISS, SRP, composition over inheritance, dependency injection
  - `python-code-style`: ruff, naming conventions, docstrings, import organization
  - `python-resource-management`: context managers, ExitStack, streaming, cleanup
  - `python-resilience`: tenacity retries, exponential backoff, timeouts, circuit breakers
  - `python-configuration`: pydantic-settings, environment variables, secrets
  - `python-observability`: structlog, Prometheus, OpenTelemetry, correlation IDs
  - `python-testing-patterns`: pytest fixtures, parametrize, mocking, async tests
  - `async-python-patterns`: asyncio, gather, semaphores, event loop patterns
  - `python-background-jobs`: Celery, RQ, Dramatiq, idempotency, job state
- `/python-code-review` command: systematic audit across all 11 domains with 🔴/🟡/🟢 prioritized findings and top 3 action items
