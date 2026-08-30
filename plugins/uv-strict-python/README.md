# uv-strict-python

A Claude Code plugin that configures Python projects to the **Python Tooling SSOT Standard**: one small, strict, boring toolchain (uv, Ruff, BasedPyright, pytest + coverage, pip-audit) that behaves identically in CLI, VS Code, and CI.

It operationalizes the **Python Tooling** standard (toolchain, layout, gate) and carries a compact summary of the companion **Python Coding** standard (code shape and agent behavior) in `references/coding-standard.md`. These are two of the five standards in the `project-standards` repository (alongside Markdown Frontmatter, Markdown Tooling, and ADR).

## When to Use

- Setting up a new Python project on the standard toolchain
- Replacing pip/virtualenv with uv for dependency management
- Replacing flake8/black/isort with Ruff for unified linting and formatting
- Replacing mypy/pyright/ty with BasedPyright strict type checking
- Migrating an existing project to the standard, or auditing one for conformance

## What It Covers

**Core toolchain:**

- **uv** — package/dependency management, lockfile, virtualenv, command execution (replaces pip, virtualenv, pip-tools, pipx, pyenv)
- **Ruff** — linting, formatting, import sorting (replaces flake8, black, isort, pyupgrade) — a **curated** rule set, not `select = ["ALL"]`
- **BasedPyright** — strict type checking, one semantic authority (replaces mypy, pyright, ty)
- **pytest + coverage.py** — testing with branch-coverage enforcement, run as `coverage run -m pytest`
- **pip-audit** — dependency vulnerability scanning

**Security baseline:**

- **pip-audit** in CI + **Dependabot** update PRs. Additional scanners are threat-model-driven, not part of the baseline.

**Standards:**

- **pyproject.toml** — single configuration center with dependency groups (PEP 735)
- **PEP 723** — inline metadata for single-file scripts
- **src/ layout** — importable product code under `src/<package>/`
- **Python 3.14** — default baseline
- **The verification gate** — one non-mutating command sequence, identical in CLI, VS Code tasks, and CI

This plugin operationalizes the Python Tooling SSOT Standard. Where a project must deviate, record an ADR exception rather than weakening the toolchain silently.

## Hook: Legacy Command Interception (opt-in)

This plugin ships PATH shims for `python`, `pip`, `pipx`, and `uv`. When a shim is on PATH and something runs a bare `python`, `pip`, or `pipx` command, the shell resolves to the shim, which prints an error with the correct `uv` alternative and exits non-zero. `uv run` is unaffected because it prepends its managed virtualenv's `bin/` to PATH, shadowing the shims.

**The shims are off by default and are not the enforcement layer for the agent's own commands.** Enforcement belongs to the `python-command-guard` PreToolUse hook (deployed separately from `agent-configs` to `~/.claude/hooks/python-command-guard`), which inspects the command Claude is about to run and blocks it before execution — with no effect on anything else in the session.

The shims remain available as an opt-in tripwire for invocations a PreToolUse hook cannot see, such as a subshell, a Makefile, or a test harness. Their known cost is that they impersonate the interpreter for the whole process tree: a `#!/usr/bin/env python3` shebang and any child process started from the session resolve to the shim rather than a real interpreter, so unrelated tooling can break far from the shim. Opt in per project in `.claude/uv-strict-python.local.md` frontmatter:

```yaml
shims: always
```

Any other value, and the absence of the file, leaves the shims uninstalled. Python project markers (`pyproject.toml`, `.python-version`, `uv.lock`) no longer install them on their own.

| Intercepted Command       | Suggested Alternative                      |
| ------------------------- | ------------------------------------------ |
| `python ...`              | `uv run python ...`                        |
| `python -m module`        | `uv run python -m module`                  |
| `python -m pip`           | `uv add`/`uv remove`                       |
| `pip install pkg`         | `uv add pkg` or `uv run --with pkg`        |
| `pip uninstall pkg`       | `uv remove pkg`                            |
| `pip freeze`              | `uv export`                                |
| `uv pip ...` (mutating)   | `uv add`/`uv remove`/`uv sync`/`uv export` |
| `pipx install <pkg>`      | `uv tool install <pkg>`                    |
| `pipx run <pkg>`          | `uvx <pkg>`                                |
| `pipx uninstall <pkg>`    | `uv tool uninstall <pkg>`                  |
| `pipx upgrade <pkg>`      | `uv tool upgrade <pkg>`                    |
| `pipx upgrade-all`        | `uv tool upgrade --all`                    |
| `pipx ensurepath`         | `uv tool update-shell`                     |
| `pipx inject <pkg> <dep>` | `uv tool install --with <dep> <pkg>`       |
| `pipx list`               | `uv tool list`                             |

Read-only `uv pip` introspection (`list`, `show`, `tree`, `check`) passes through to the real uv — the standard only proscribes the legacy install/modify path, and diagnostics should keep working.

Commands like `grep python`, `which python`, and `cat python.txt` work normally because `python` is a shell argument, not the command being invoked.

The shims point only at `uv`/`uv tool` equivalents — they are independent of the type-checker and linter choices, so they enforce the standard's "use uv" rule without touching BasedPyright or Ruff.

Read-only diagnostics pass through to the real binaries: `python --version`/`-V`, and `uv pip list|show|tree|check`.

## LSP: BasedPyright Language Server

The plugin ships an LSP integration (`.lsp.json` → `scripts/basedpyright-lsp.sh`) implementing the standard's §13 CLI-agent language-server policy: **BasedPyright is the single Python semantic/type authority** across editing surfaces. The launcher prefers a `uv tool install basedpyright` install and falls back to `uvx --from basedpyright basedpyright-langserver` (downloads on first use).

Do not enable a second Python language server (Pyright, Pylance, python-lsp-server, Jedi) alongside it — one type authority, per the standard. Run `/reload-plugins` after updating; check the `/plugin` Errors tab if diagnostics don't appear.

## Tests

```bash
plugins/uv-strict-python/tests/run.sh
```

The wrapper runs the bats suites (shims, hook gating, LSP launcher), then `check-standard-sync.sh` — which requires the pinned `project-standards` release on PATH and fails when its provenance, the Python Tooling payload digest, the SKILL.md sync pin, or the three byte-identical template resources disagree — and `validate-fenced-blocks.sh`, which parses every fenced `toml`/`json`/`yaml` block in the skill content. Always use the wrapper, never bare `bats` (it hardens PATH against this workstation's find/grep shims).
