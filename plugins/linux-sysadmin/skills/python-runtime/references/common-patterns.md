# Common Python Runtime Patterns

## 1. Setting Up a New Project With uv

```bash
# Create and enter project
uv init myproject
cd myproject

# Add dependencies
uv add fastapi uvicorn
uv add --dev pytest ruff mypy

# Run the app
uv run python -m myproject

# Run tests
uv run pytest
```

uv creates `pyproject.toml`, `uv.lock`, `.python-version`, and `.venv` automatically.
The lockfile (`uv.lock`) is cross-platform and should be committed to version control.

---

## 2. Setting Up a New Project With pip + venv

```bash
mkdir myproject && cd myproject

# Create and activate venv
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install fastapi uvicorn
pip install pytest ruff mypy

# Freeze for reproducibility
pip freeze > requirements.txt

# Later, recreate the environment
python3 -m venv .venv --clear
source .venv/bin/activate
pip install -r requirements.txt
```

For better reproducibility, use `pip-compile` from pip-tools to generate
`requirements.txt` from a `requirements.in` (or `pyproject.toml`).

---

## 3. pyenv + virtualenv Workflow

```bash
# Install desired Python version
pyenv install 3.12

# Set it as project default
cd myproject
pyenv local 3.12

# Create venv with that version
python -m venv .venv
source .venv/bin/activate

# Verify
python --version   # 3.12.x
which python        # /path/to/myproject/.venv/bin/python
```

pyenv selects the interpreter; the venv isolates packages. Both `.python-version`
and `.venv/` should be in `.gitignore` (or committed per team convention).

---

## 4. Building Python From Source

Use when the distro Python is too old and you cannot use pyenv or uv.

```bash
# 1. Install build dependencies (Ubuntu/Debian)
sudo apt update
sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libffi-dev liblzma-dev \
  libncursesw5-dev xz-utils tk-dev

# 2. Download
VERSION=3.12.7
wget "https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tgz"
tar xzf "Python-${VERSION}.tgz"
cd "Python-${VERSION}"

# 3. Configure
#   --prefix: install location (keeps it separate from system Python)
#   --enable-optimizations: PGO build (~10-20% faster, much longer compile)
#   --with-ensurepip: include pip in the installation
./configure \
  --prefix=/opt/python-${VERSION} \
  --enable-optimizations \
  --with-ensurepip=install

# 4. Build and install
make -j$(nproc)
sudo make altinstall    # installs as python3.12, not python3

# 5. Verify
/opt/python-${VERSION}/bin/python3.12 --version

# 6. Optional: add to PATH
echo 'export PATH="/opt/python-3.12.7/bin:$PATH"' >> ~/.bashrc
```

`make altinstall` is critical: plain `make install` overwrites `/usr/bin/python3`,
which can break system tools.

---

## 5. Handling PEP 668 on Modern Distros

PEP 668 blocks `pip install` (including `--user`) outside a virtual environment.

**Affected distros:** Ubuntu 23.04+, Debian 12+ (Bookworm), Arch Linux.
**Not affected:** Fedora (proposed but not implemented), older Ubuntu/Debian, RHEL/CentOS.

### The error
```
error: externally-managed-environment

This environment is externally managed
To install Python packages system-wide, try apt install python3-xyz...
```

### Solutions (best to worst)

1. **Use a virtual environment** (recommended):
   ```bash
   python3 -m venv .venv && source .venv/bin/activate
   pip install whatever
   ```

2. **Use uv** (handles venvs transparently):
   ```bash
   uv pip install whatever    # works in any venv
   uv add whatever            # project-managed
   ```

3. **Use pipx for CLI tools**:
   ```bash
   pipx install ruff
   # or: uv tool install ruff
   ```

4. **Override with --break-system-packages** (last resort):
   ```bash
   pip install --break-system-packages whatever
   ```

5. **Delete the marker file** (not recommended; risks breaking system tools):
   ```bash
   sudo rm /usr/lib/python3.*/EXTERNALLY-MANAGED
   ```

### Set PIP_REQUIRE_VIRTUALENV for safety
Even on distros without PEP 668, you can self-enforce venv usage:
```bash
echo 'export PIP_REQUIRE_VIRTUALENV=1' >> ~/.bashrc
```
This makes pip refuse to install outside a venv regardless of distro.

---

## 6. Docker Python Images

### Choosing the right base

| Image | Size | Use case |
|-------|------|----------|
| `python:3.12` | ~1 GB | Full Debian with build tools; good for compilation |
| `python:3.12-slim` | ~150 MB | Minimal Debian; production default |
| `python:3.12-alpine` | ~50 MB | Musl libc; smallest but some packages fail to compile |
| `python:3.12-bookworm` | ~1 GB | Explicit Debian 12 base |
| `python:3.12-slim-bookworm` | ~150 MB | Explicit slim Debian 12; best for reproducibility |

### Dockerfile with uv (recommended)

```dockerfile
FROM python:3.12-slim-bookworm

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Deps first for cache efficiency
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY src/ ./src/

ENV PATH="/app/.venv/bin:$PATH"
CMD ["python", "-m", "myapp"]
```

### Dockerfile with pip

```dockerfile
FROM python:3.12-slim-bookworm

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
CMD ["python", "-m", "myapp"]
```

### Key rules for Python Docker images
- Pin the uv version in `COPY --from=ghcr.io/astral-sh/uv:0.5.0` for reproducible builds.
- Copy dependency files before source for layer cache efficiency.
- Use `--no-cache-dir` with pip to keep image size down.
- Set `PYTHONUNBUFFERED=1` and `PYTHONDONTWRITEBYTECODE=1` in ENV.
- Avoid alpine for projects with C extensions (numpy, pandas) unless you enjoy debugging musl issues.

---

## 7. CI/CD Patterns

### GitHub Actions with uv

```yaml
- uses: astral-sh/setup-uv@v5
  with:
    version: "latest"

- run: uv sync --frozen
- run: uv run pytest
- run: uv run ruff check .
```

### GitHub Actions with pip

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: "3.12"
    cache: "pip"

- run: pip install -r requirements.txt
- run: pytest
```

### Caching strategies
- **uv**: Cache `~/.cache/uv` between runs. uv's cache is safe to share across jobs.
- **pip**: Use `actions/setup-python` with `cache: "pip"` to cache downloaded wheels.
- **venv caching**: Cache the entire `.venv/` keyed on `requirements.txt` or `uv.lock` hash. Faster than reinstalling but fragile across Python version changes.

---

## 8. Managing Multiple Python Versions for Testing

### With uv

```bash
uv python install 3.10 3.11 3.12 3.13

# Run tests against each
uv run --python 3.10 pytest
uv run --python 3.11 pytest
uv run --python 3.12 pytest
```

### With pyenv + tox

```bash
pyenv install 3.10.14 3.11.9 3.12.4
pyenv local 3.10.14 3.11.9 3.12.4   # makes all available to tox

# tox.ini
# [tox]
# envlist = py310, py311, py312
tox
```

### With deadsnakes (Ubuntu)

```bash
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt install python3.10 python3.10-venv python3.11 python3.11-venv

# Create per-version venvs
python3.10 -m venv .venv310
python3.11 -m venv .venv311
```

---

## 9. Migrating From pip to uv

### Quick migration (pip-compatible interface)
Replace `pip` with `uv pip` in your commands. No project restructuring needed.

```bash
# Before
pip install -r requirements.txt
pip freeze > requirements.txt

# After
uv pip install -r requirements.txt
uv pip freeze > requirements.txt
```

### Full migration (project interface)
Convert to uv-managed project with `pyproject.toml` and `uv.lock`.

```bash
# 1. Initialize if no pyproject.toml exists
uv init

# 2. Import existing requirements
uv add -r requirements.txt

# 3. Generate lockfile
uv lock

# 4. Sync environment
uv sync

# 5. Verify
uv run python -c "import mypackage; print('ok')"

# 6. Update scripts/CI to use uv run instead of direct invocation
# Before: python main.py
# After:  uv run python main.py
```

After migration, commit `pyproject.toml` and `uv.lock`. The `requirements.txt` can
be kept for backwards compatibility or removed if all consumers use uv.
