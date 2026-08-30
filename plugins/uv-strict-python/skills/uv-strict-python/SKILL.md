---
name: uv-strict-python
description: Configures Python projects to the Python Tooling SSOT Standard (uv, Ruff, BasedPyright strict, pytest+coverage, pip-audit). Use when creating projects, writing standalone scripts, configuring pyproject.toml, migrating from pip/Poetry/mypy/black/flake8, or auditing a project for conformance to the standard.
compatibility: Claude Code and Codex CLI
metadata:
  version: '1.2.0'
---

# uv-strict-python

Operational guide for the **Python Tooling SSOT Standard**: one small, strict, boring toolchain that behaves identically in CLI, VS Code, and CI. The standard prefers a few non-overlapping authorities over many competing tools, because contradictory feedback is expensive for coding agents.

This skill operationalizes the **Python Tooling** standard — toolchain, layout, and the verification gate. Code _shape_ and agent-behavior rules (error handling, side-effect boundaries, trust boundaries, prohibited behaviors) live in the companion **Python Coding** standard, summarized in [coding-standard.md](./references/coding-standard.md). A green gate on badly shaped code is not done — read both.

> **Sync pin:** mirrors Project Standards v5.25.0 (peeled commit `b2f73d9dee080a7579a7900168093dabf4c52b5b`) and Python Tooling 1.16 (`sha256:60d3a68c9973942b7a92f7affcd3fbac553b3c79c31bcd63b723e1186bd3c734`). The immutable released payload is canonical. This skill retains exactly three byte-identical whole-file resources and delegates semantic units to Catalog 5 reconciliation.

## When to Use This Skill

- Creating a new Python project or package
- Setting up or auditing `pyproject.toml`
- Configuring the toolchain (format, lint, type-check, test, coverage, audit)
- Writing Python scripts with external dependencies
- Migrating an existing project to the standard toolchain

## When NOT to Use This Skill

- **User wants to keep legacy tooling**: respect existing workflows if explicitly requested; record the deviation as an ADR exception, not a silent drift.
- **Documented project exception applies**: a project may pin a lower `requires-python`, add scanners, or keep mypy if an ADR records why.
- **Non-Python projects**: mixed codebases where Python isn't primary.

## Which gate to run

Decide before running anything — the two paths are not interchangeable:

- **Repository adopts the standard** (`.standards/config.toml` selects `python-tooling`, the generated `AGENTS.md`/`CLAUDE.md` carries the Python tooling block, `scripts/check.py` exists): the repository-owned gate **is** the gate. Run `uv run python scripts/check.py`, or the generated block's own commands scoped to their declared roots. Never substitute a repository-wide `.` sweep in an adopting repo — it reaches paths the repository deliberately excluded.
- **Non-adopting project or standalone script with no repository gate**: use the **fallback gate** below. It is complete as-is and is the normal path for scripts and projects that never adopted Catalog 5.

**Fallback gate (no repository-owned gate)** — the non-mutating proof the tree is clean. Code is not complete until this passes (or the response says exactly what failed and why):

```bash
uv run ruff format --check .
uv run ruff check .
uv run basedpyright
uv run coverage run -m pytest
uv run coverage report
uv run pip-audit
```

**Fix pass** — allowed to modify source; run it first when changing code, in either path:

```bash
uv run ruff format .
uv run ruff check . --fix
```

## Anti-Patterns to Avoid

| Avoid | Use Instead |
| --- | --- |
| `mypy` / `pyright` / `ty` | **`basedpyright`** strict — one semantic/type authority |
| `select = ["ALL"]` (auto-enables new rules on every Ruff bump) | A **curated** Ruff `select` set (stable, boring) |
| `[tool.pytest]` in templates | `[tool.pytest.ini_options]` (recognized back to pytest 6.0; avoids silent inert config) |
| `--cov` flags in pytest `addopts` | `coverage run -m pytest` + `coverage report` (branch coverage) |
| `pre-commit` / `prek` | The gate runs in CI + VS Code tasks + `scripts/check.py` — no overlapping hook runner |
| `uv pip install` | `uv add` / `uv sync` |
| Editing `pyproject.toml` to add deps by hand | `uv add <pkg>` / `uv remove <pkg>` |
| `hatchling` build backend | `uv_build` |
| Poetry / Pipenv / PDM | `uv` |
| `requirements.txt` | PEP 723 for single-file scripts, `pyproject.toml` for projects |
| `[project.optional-dependencies]` for dev tools | `[dependency-groups]` (PEP 735) |
| Manual venv activation (`source .venv/bin/activate`) | `uv run <cmd>` |
| Pylance / Python Environments as a second authority | BasedPyright (type) + Ruff (format/lint), nothing overlapping |

**Key principles:**

- `uv` owns dependency resolution, the lockfile, the virtualenv, and command execution — always `uv add`/`uv remove`, never hand-edit deps or activate venvs.
- Exactly **one** semantic/type authority (BasedPyright) and **one** format/lint/import authority (Ruff). Do not add a second.
- The toolchain stack is non-negotiable; only its **scope** (which paths it covers) is tunable, via `extend-exclude` / `[tool.basedpyright].include`.
- Use `[dependency-groups]` for dev/test deps, not `[project.optional-dependencies]`.

## Decision Tree

```text
What are you doing?
│
├─ Single-file script with dependencies?
│   └─ Use PEP 723 inline metadata (./references/pep723-scripts.md — skill
│      extension; the standard governs script *projects*, not single files)
│
├─ New importable project or package?
│   └─ Full setup with src/ layout (see Full Setup below)
│
├─ Small automation/script project (lives in Git)?
│   └─ Still uv + pyproject + ruff + basic typing (Quick Start below)
│
└─ Migrating an existing project?
    └─ See Migration Guide below
```

## Tool Overview

| Tool | Purpose | Replaces |
| --- | --- | --- |
| **uv** | Package/dependency management, venv, command execution | pip, virtualenv, pip-tools, pipx, pyenv |
| **ruff** | Linting AND formatting AND import sorting | flake8, black, isort, pyupgrade |
| **basedpyright** | Strict type checking (CLI + language server) | mypy, pyright, ty |
| **pytest** | Testing | unittest |
| **coverage.py** | Branch coverage enforcement | — |
| **pip-audit** | Dependency vulnerability scanning | — |

Security baseline is **`pip-audit`** (run in CI) plus **Dependabot** for update PRs. Extra scanners (Bandit, shellcheck, actionlint, zizmor, detect-secrets) are **threat-model-driven additions**, not part of the baseline — add them when a project handles auth, secrets, public network services, subprocess execution, or uploaded files, and document the addition. See [security-setup.md](./references/security-setup.md).

## Quick Start: Minimal Project

For small multi-file or automation projects that still live in Git:

```bash
# Create project with uv (src/ layout)
uv init --package myproject
cd myproject

# Runtime dependencies
uv add requests rich

# Initialize the V5 control plane, configure Python Tooling, then reconcile.
project-standards init --catalog 5
# Edit .standards/config.toml using the package block below.
project-standards reconcile --check
project-standards reconcile --apply
uv lock
uv run python scripts/check.py
```

## Full Project Setup

### 1. Create the project and control plane

```bash
uv init --package myproject
cd myproject
project-standards init --catalog 5
```

### 2. Select Python Tooling

Add this package configuration to `.standards/config.toml`. Change an option
only to preserve deliberate repository intent; the selected immutable payload,
not copied snippets, owns the resulting semantic units.

```toml
[standards.python-tooling]
enabled = true
version = "latest"

[standards.python-tooling.config]
contract_version = "1.1"
python_version = "3.14"
build_backend = "uv_build"
source_layout = "src"
additional_source_roots = []
additional_dev_dependencies = []
workflow_ownership = "managed"
script_ownership = "managed"

[standards.python-tooling.config.ruff]
line_length = 100
extend_exclude = [".claude", ".agents", ".codex", ".continue"]
extend_include = []
extend_select = []
extend_ignore = []

[standards.python-tooling.config.type_checker]
name = "basedpyright"
mode = "strict"

[standards.python-tooling.config.pytest]
fail_under = 85
markers = []
coverage_exclude_also = []
test_paths = ["tests"]

[standards.python-tooling.config.coverage]
parallel = false
patch = []
omit = []

[standards.python-tooling.config.pip_audit]
ignore_vulnerabilities = []

[standards.python-tooling.config.ci]
enabled = true
performance = false

[standards.python-tooling.config.vscode]
format_on_save = true

[standards.python-tooling.config.agent_instructions]
include_fix_commands = true
```

See [pyproject.md](./references/pyproject.md) for option effects and semantic
ownership boundaries.

### 3. Preview, apply, and verify

```bash
project-standards reconcile --check
project-standards reconcile --apply
uv lock
uv run python scripts/check.py
project-standards reconcile --check --json
```

The final JSON check must report `ok: true`, `drift: false`, and no findings.
Commit `.standards/config.toml`, `.standards/catalog.toml`,
`.standards/lock.toml`, `uv.lock`, and reconciled outputs together.

### Resource ownership

Catalog 5 composes `pyproject.toml`, `.editorconfig`, `.vscode/*`, `AGENTS.md`,
and `CLAUDE.md` as bounded semantic units while preserving unrelated consumer
content. Do not copy or merge whole-file templates for those surfaces.

This skill retains exactly three byte-identical package resources for inspection:

| Resource | Reconciled destination |
| --- | --- |
| [check.py](./templates/check.py) | `scripts/check.py` |
| [check.yml](./templates/check.yml) | `.github/workflows/check.yml` |
| [python-version](./templates/python-version) | `.python-version` |

The control plane remains the adoption authority even for these resources. The
supplemental Dependabot and ADR examples are skill guidance, not Python Tooling
payload resources.

## Migration Guide

When a user requests migration from legacy tooling (stage it; do not weaken the final standard):

For a V4 consumer, preview and apply the Catalog 5 migration before manual
cleanup:

```bash
project-standards init --catalog 5 --migrate
project-standards init --catalog 5 --migrate --apply
project-standards reconcile --check --json
```

### From requirements.txt + pip

**Standalone scripts**: convert to PEP 723 inline metadata (see [pep723-scripts.md](./references/pep723-scripts.md)).

**Projects**:

```bash
uv init --bare
uv add requests rich        # add each package via uv, not by editing pyproject.toml

# Or import from requirements.txt (review each package first)
grep -v '^#' requirements.txt | grep -v '^-' | grep -v '^\s*$' | while read -r pkg; do
    uv add "$pkg" || echo "Failed to add: $pkg"
done
uv sync
```

Then delete `requirements*.txt` and any `venv/`, and commit `uv.lock`.

### From setup.py / setup.cfg

1. `uv init --bare`
2. `uv add` each dependency from `install_requires`; `uv add --dev` for dev deps
3. Copy non-dependency metadata into `[project]`
4. Delete `setup.py`, `setup.cfg`, `MANIFEST.in`

### From flake8 + black + isort → Ruff

1. `uv remove flake8 black isort`
2. Delete `.flake8`, `[tool.black]`, `[tool.isort]`
3. `uv add --dev ruff`, add the curated config (see [ruff-config.md](./references/ruff-config.md))
4. `uv run ruff check . --fix` then `uv run ruff format .`

### From mypy / pyright / ty → BasedPyright

1. `uv remove mypy pyright ty` (whichever is present)
2. Delete `mypy.ini`, `pyrightconfig.json`, `[tool.mypy]`/`[tool.pyright]`/`[tool.ty]`
3. `uv add --dev basedpyright`
4. Add `[tool.basedpyright]` with `typeCheckingMode = "strict"`
5. `uv run basedpyright` — for messy codebases, adopt strictness in stages (BasedPyright baselines) rather than weakening the final bar.

## Quick Reference: uv Commands

| Command | Description |
| --- | --- |
| `uv init --package` | Create a distributable `src/` package |
| `uv add <pkg>` | Add runtime dependency |
| `uv add --dev <pkg>` | Add dev dependency |
| `uv remove <pkg>` | Remove dependency |
| `uv sync --all-groups` | Install everything |
| `uv sync --locked --all-groups` | CI install (fails if lockfile stale) |
| `uv run <cmd>` | Run a command in the project env |
| `uv run --with <pkg> <cmd>` | Run with a one-off dependency |
| `uv tool install <pkg>` | Install a global ad-hoc CLI (ruff, basedpyright, pip-audit) |

### Ad-hoc Dependencies with `--with`

```bash
uv run --with httpx python script.py   # project deps + httpx, not added to the project
```

- `uv add`: package is a real project dependency (lands in `pyproject.toml`/`uv.lock`).
- `--with`: one-off usage or a script outside a project context.

For uv mechanics beyond this table (flags, Docker/CI patterns, workspaces, migration mechanics), use the `uv-package-manager` skill **if it is deployed** in your harness (`~/.claude/skills/uv-package-manager/SKILL.md` on Claude, `~/.codex/skills/uv-package-manager/SKILL.md` on Codex) — it is the tool-mechanics SSOT, verified against the official uv docs. It is not deployed by default; otherwise use `uv <command> --help` and the official docs (https://docs.astral.sh/uv/) — do not guess flags from memory. This standard constrains **which** of those commands are allowed (see Anti-Patterns above); where the two disagree, this standard wins inside standard-adopting repos. [uv-commands.md](./references/uv-commands.md) records that contract. The deployed python-expert skill states this same toolchain policy in condensed router form; on any conflict inside standard-adopting repos, this standard and canon govern.

## Best Practices Checklist

- [ ] `src/` layout for importable code
- [ ] `requires-python = ">=3.14"`, `.python-version` = `3.14`
- [ ] Ruff curated `select` set (not `ALL`)
- [ ] BasedPyright `typeCheckingMode = "strict"`
- [ ] pytest config in `[tool.pytest.ini_options]` with `--strict-markers --strict-config`
- [ ] Branch coverage on, `fail_under = 85`, via `coverage run -m pytest`
- [ ] `pip-audit` in CI
- [ ] `[dependency-groups]` for dev tools, `uv.lock` committed (apps)
- [ ] Verification gate green before claiming completion

## Enforcement Layers (optional, per-harness)

This skill's guidance stands alone — nothing below is required for the skill to work. Enforcement now has two independent layers with different defaults; both are activated by Python markers at the working tree (`pyproject.toml`, `.python-version`, or `uv.lock`).

- **`python-command-guard` (default, agent-facing):** a PreToolUse hook (Claude Bash tool; Codex PreToolUse where supported), deployed by `scripts/global/install-globals.sh`, that denies direct agent invocation of bare `python`/`python3`/`pip`/`pip3`/`pipx` and mutating `uv pip` commands. It inspects only the agent's command text, never `PATH` — shebangs, `command -v`, validator subprocesses, and nested scripts are unaffected, so it cannot reproduce the shim's cross-process failures (bugs 003/010/011). `-V`/`--version` and read-only `uv pip list`/`show`/`tree`/`check` pass through. A per-repo override file, `.claude/uv-strict-python.local.md` (Claude) or `.codex/uv-strict-python.local.md` (Codex), sets `enforcement: auto|always|never`.
- **Bundled PATH shims ([shims/](./shims/), opt-in):** shims that make bare `python`/`pip`/`pipx` (and mutating `uv pip`) fail for every child process in the session, not just direct agent calls — their documented cost is exactly that breadth (bugs 003/010/011). They remain shipped, and their per-harness activation mechanism is unchanged (Claude Code: the `uv-strict-python` plugin's `SessionStart` hook; Codex CLI: the `codex-bao` launch wrapper), but neither harness prepends them by default anymore; set `shims: always` in the same per-repo override file to opt back in.

If neither layer is active in a session, the rules in this skill still apply — enforcement is a tripwire, not the standard.

## Read Next

- [coding-standard.md](./references/coding-standard.md) — **companion**: compact summary of the Python Coding standard (code shape + agent behavior)
- [pyproject.md](./references/pyproject.md) — complete `pyproject.toml`, VS Code, and CI baseline
- [ruff-config.md](./references/ruff-config.md) — curated Ruff lint/format configuration
- [testing.md](./references/testing.md) — pytest + coverage (the standard's gate form)
- [uv-commands.md](./references/uv-commands.md) — mechanics-SSOT contract with `uv-package-manager` + the standard's uv rules
- [pep723-scripts.md](./references/pep723-scripts.md) — PEP 723 inline script metadata
- [security-setup.md](./references/security-setup.md) — pip-audit baseline + Dependabot
- [dependabot.md](./references/dependabot.md) — automated dependency updates
- [migration-checklist.md](./references/migration-checklist.md) — step-by-step migration cleanup
