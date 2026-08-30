# uv Commands — Mechanics SSOT and Standard Overlay

**Tool mechanics belong to the `uv-package-manager` skill, if it is deployed in your harness** — read `~/.claude/skills/uv-package-manager/SKILL.md` (Claude) or `~/.codex/skills/uv-package-manager/SKILL.md` (Codex) for command syntax, flags, Docker/CI recipes, workspaces, lockfile/export details, and migration mechanics. That skill is not deployed by default; where it is present it is verified against the official uv docs on its own cadence, and duplicating its content here would drift. Otherwise use the Fallback below.

This file records only what the **Python Tooling SSOT Standard** adds on top. Where the neutral reference and this standard disagree, **the standard wins inside standard-adopting repos** (the neutral reference documents tools the standard forbids — `hatchling`, pre-commit, `[project.optional-dependencies]` for dev tools, ad-hoc `uv pip install`; see the Anti-Patterns table in [SKILL.md](../SKILL.md)).

## Standard overlay (rules the neutral reference does not impose)

- **Never bootstrap uv via pip or pipx** — this standard replaces both with uv itself. Use the standalone installer or a system package manager.
- **Python baseline is 3.14** (`requires-python = ">=3.14"`, `.python-version` = `3.14`). Do not change a project's Python version unless the task explicitly requires it; pinning lower needs a documented ADR exception.
- **The dev group is always the full standard toolchain** — the stack is non-negotiable, only its scope is tunable:

  ```bash
  uv add --dev basedpyright "coverage[toml]" pip-audit pytest ruff
  ```

- **CI must use `uv sync --locked --all-groups`** — it fails when the lockfile is stale, which is the point. Do **not** substitute `--frozen`, which skips that check (`--frozen` is for Docker layers where `pyproject.toml` and `uv.lock` ship as a unit).
- **`uv add`/`uv remove` only** — never hand-edit dependencies in `pyproject.toml`, never `uv pip install` into a project (read-only `uv pip list|show|tree|check` diagnostics are fine).
- **`uv run` everything** — never activate a venv manually.
- **`[dependency-groups]` (PEP 735) for dev/test tools**, not `[project.optional-dependencies]` (which is published metadata for real consumer extras).
- **Build backend is `uv_build`**, not hatchling (see [pyproject.md](./pyproject.md)).

## Container/host split venvs

When developing on a host machine while also running in containers, separate venvs avoid rebuilding on each context switch:

```bash
# On host machine (shell profile or .envrc)
export UV_PROJECT_ENVIRONMENT=.venv-dev
# Host uses .venv-dev, containers use default .venv
```

Add both `.venv/` and `.venv-dev/` to `.gitignore`.

## Fallback

The `uv-package-manager` skill is not deployed by default, so this is the normal path, not the exception: when it is absent from the current environment, use `uv <command> --help` and the official docs (https://docs.astral.sh/uv/) for mechanics — do not guess flags from memory; uv moves fast.
