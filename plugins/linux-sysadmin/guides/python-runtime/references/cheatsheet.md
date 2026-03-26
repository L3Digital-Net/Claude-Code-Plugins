# Python Runtime Cheatsheet

## Command Comparison: pip vs uv vs pyenv

| Task | pip | uv | pyenv |
|------|-----|-----|-------|
| Install package | `pip install requests` | `uv pip install requests` | N/A |
| Install from requirements | `pip install -r requirements.txt` | `uv pip install -r requirements.txt` | N/A |
| Create venv | `python3 -m venv .venv` | `uv venv` | N/A |
| Freeze/lock installed | `pip freeze > requirements.txt` | `uv pip freeze > requirements.txt` | N/A |
| Lock deps (pip-tools style) | `pip-compile requirements.in` | `uv pip compile requirements.in -o requirements.txt` | N/A |
| Sync env to lockfile | `pip-sync requirements.txt` | `uv pip sync requirements.txt` | N/A |
| Upgrade package | `pip install --upgrade requests` | `uv pip install --upgrade requests` | N/A |
| Uninstall package | `pip uninstall requests` | `uv pip uninstall requests` | N/A |
| List installed | `pip list` | `uv pip list` | N/A |
| Cache management | `pip cache purge` | `uv cache clean` | N/A |
| Install Python version | N/A | `uv python install 3.12` | `pyenv install 3.12` |
| List Python versions | N/A | `uv python list` | `pyenv versions` |
| Set global Python | N/A | `uv python pin --global 3.12` | `pyenv global 3.12` |
| Set local Python | N/A | `uv python pin 3.12` | `pyenv local 3.12` |
| Install CLI tool globally | `pipx install ruff` | `uv tool install ruff` | N/A |
| Run tool without install | `pipx run ruff` | `uvx ruff` | N/A |

## uv Project Commands (no pip equivalent)

| Task | Command |
|------|---------|
| Initialize project | `uv init myproject` |
| Add dependency | `uv add requests` |
| Add dev dependency | `uv add --dev pytest` |
| Remove dependency | `uv remove requests` |
| Generate lockfile | `uv lock` |
| Upgrade in lockfile | `uv lock --upgrade-package requests` |
| Sync from lockfile | `uv sync` |
| Sync (frozen, no freshness check) | `uv sync --frozen` |
| Sync (production, no dev deps) | `uv sync --frozen --no-dev` |
| Run in project env | `uv run python main.py` |
| Run with flags | `uv run -- flask run -p 3000` |

## Virtual Environment Activation by Shell

| Shell | Activate | Deactivate |
|-------|----------|------------|
| bash | `source .venv/bin/activate` | `deactivate` |
| zsh | `source .venv/bin/activate` | `deactivate` |
| fish | `source .venv/bin/activate.fish` | `deactivate` |
| csh/tcsh | `source .venv/bin/activate.csh` | `deactivate` |
| PowerShell | `.venv/bin/Activate.ps1` | `deactivate` |
| No activation needed | `.venv/bin/python script.py` | N/A |

Note: uv commands (`uv run`, `uv sync`) auto-detect `.venv` without activation.

## pyenv Workflow

```
1. Install pyenv        → curl -fsSL https://pyenv.run | bash
2. Add shell init       → append to ~/.bashrc (see SKILL.md)
3. Restart shell        → exec "$SHELL"
4. Install build deps   → sudo apt install build-essential libssl-dev ...
5. Install Python       → pyenv install 3.12
6. Set global version   → pyenv global 3.12
7. Set per-project      → cd myproject && pyenv local 3.11
8. Verify               → python --version
```

Priority order (highest wins): `PYENV_VERSION` env var > `pyenv shell` > `.python-version` file (pyenv local) > `~/.pyenv/version` (pyenv global) > system Python.

## uv Installation

```bash
# Recommended (standalone installer)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Alternative methods
pipx install uv        # via pipx
pip install uv          # via pip (inside a venv)
brew install uv         # macOS/Linuxbrew
cargo install --locked uv   # from source via Rust
```

## Key Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `VIRTUAL_ENV` | Active venv root (set by activate) | unset |
| `PYTHONPATH` | Prepend to sys.path | unset |
| `PYTHONDONTWRITEBYTECODE` | Suppress .pyc files when set to 1 | unset |
| `PYTHONUNBUFFERED` | Disable stdout/stderr buffering when set to 1 | unset |
| `PYENV_ROOT` | pyenv install directory | `~/.pyenv` |
| `PYENV_VERSION` | Override active Python version | unset |
| `UV_CACHE_DIR` | uv cache location | `~/.cache/uv` |
| `UV_PYTHON_INSTALL_DIR` | Where uv stores Python versions | `~/.local/share/uv/python` |
| `UV_TOOL_DIR` | Where uv stores tool envs | `~/.local/share/uv/tools` |
| `PIP_INDEX_URL` | Default PyPI index for pip | `https://pypi.org/simple/` |
| `PIP_REQUIRE_VIRTUALENV` | Block pip install outside venv when set to 1 | unset |
