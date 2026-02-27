# Quality Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fill integration test stubs with real keepassxc-cli calls, close the remaining 6% coverage gap (94% → ~98%), and add ruff + mypy static analysis.

**Architecture:** Create a `PasswordVault` test helper that overrides `run_cli` to pipe a password via stdin instead of `--yubikey`. Add targeted unit tests for the ~29 uncovered lines. Configure ruff and mypy in pyproject.toml.

**Tech Stack:** pytest, pytest-asyncio, pytest-cov, ruff, mypy, keepassxc-cli

---

## Dependency Map

```
Task 1 (PasswordVault helper) ← Task 2 (integration tests need it)
Task 3 (coverage gaps) is independent
Task 4 (ruff + mypy) is independent
Task 5 (verification) depends on all
```

---

### Task 1: Create PasswordVault Test Helper

**Files:**
- Create: `tests/helpers.py`

**Step 1: Create the PasswordVault subclass**

Create `tests/helpers.py`:

```python
"""Test helpers for integration tests.

PasswordVault overrides the YubiKey-based auth with a password piped via stdin,
enabling integration tests against a password-only test.kdbx.
"""

from __future__ import annotations

import subprocess

from server.config import Config
from server.vault import KeePassCLIError, Vault, VaultLocked
from server.yubikey import MockYubiKey


class PasswordVault(Vault):
    """Vault subclass that uses password auth instead of YubiKey.

    For integration testing only. Overrides unlock() and run_cli()
    to pipe the database password via stdin.
    """

    def __init__(self, config: Config, password: str) -> None:
        super().__init__(config, MockYubiKey(present=True, slot=config.yubikey_slot))
        self._password = password

    def unlock(self) -> None:
        from datetime import datetime, timezone

        result = subprocess.run(
            ["keepassxc-cli", "open", self._config.database_path],
            input=self._password + "\n",
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            raise KeePassCLIError(
                f"keepassxc-cli open failed: {result.stderr.strip()}"
            )
        self._unlocked = True
        self._unlock_time = datetime.now(timezone.utc)

    def run_cli(self, *args: str) -> str:
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        cmd = ["keepassxc-cli", *args]
        result = subprocess.run(
            cmd,
            input=self._password + "\n",
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            raise KeePassCLIError(
                f"keepassxc-cli {args[0]} failed: {result.stderr.strip()}"
            )
        return result.stdout
```

**Step 2: Run existing tests to verify no breakage**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/ -v --tb=short`
Expected: 100 passed

**Step 3: Commit**

```bash
git add tests/helpers.py
git commit -m "test(keepass-cred-mgr): add PasswordVault helper for integration tests"
```

---

### Task 2: Fill Integration Test Stubs

**Files:**
- Modify: `tests/integration/test_integration.py`

**Step 1: Create the test database**

Run: `cd plugins/keepass-cred-mgr && bash tests/fixtures/create_test_db.sh`
Expected: "Test database created at .../test.kdbx"

**Step 2: Rewrite the integration test file**

Replace the contents of `tests/integration/test_integration.py`:

```python
"""Integration tests against real test.kdbx.

Requires keepassxc-cli installed. No YubiKey needed (test db uses password only).
These tests call real keepassxc-cli commands via the PasswordVault helper.
"""

import shutil
from pathlib import Path

import pytest

from server.audit import AuditLogger
from server.config import load_config
from server.vault import DuplicateEntry, GroupNotAllowed

# Skip entire module if keepassxc-cli not available
pytestmark = pytest.mark.integration

KEEPASSXC_CLI = shutil.which("keepassxc-cli")
if not KEEPASSXC_CLI:
    pytest.skip("keepassxc-cli not installed", allow_module_level=True)

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"
TEST_DB = FIXTURES_DIR / "test.kdbx"

if not TEST_DB.exists():
    pytest.skip("test.kdbx not found — run create_test_db.sh", allow_module_level=True)


@pytest.fixture
def integration_setup(tmp_path):
    """Copy test db to tmp, create config, return PasswordVault + audit."""
    import yaml
    from tests.helpers import PasswordVault

    # Copy db so writes don't pollute the fixture
    db_copy = tmp_path / "test.kdbx"
    shutil.copy(TEST_DB, db_copy)

    audit_path = tmp_path / "audit.jsonl"
    cfg = {
        "database_path": str(db_copy),
        "yubikey_slot": 2,
        "grace_period_seconds": 2,
        "yubikey_poll_interval_seconds": 1,
        "write_lock_timeout_seconds": 5,
        "page_size": 50,
        "allowed_groups": ["Servers", "SSH Keys", "API Keys"],
        "audit_log_path": str(audit_path),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    config = load_config(str(config_file))

    vault = PasswordVault(config, password="testpassword")
    vault._unlocked = True
    audit = AuditLogger(str(audit_path))

    return vault, audit, config, db_copy


class TestIntegrationReadCycle:
    def test_list_groups_returns_allowed(self, integration_setup):
        """list_groups returns only allowed groups."""
        from server.tools.read import list_groups

        vault, audit, config, db = integration_setup
        groups = list_groups(vault)
        assert set(groups) == {"Servers", "SSH Keys", "API Keys"}


class TestIntegrationWriteCycle:
    def test_create_then_list(self, integration_setup):
        """create_entry then list_entries confirms presence."""
        from server.tools.read import list_entries
        from server.tools.write import create_entry

        vault, audit, config, db = integration_setup
        create_entry(vault, audit, title="New Test Entry", group="Servers", username="testuser")
        entries = list_entries(vault, audit, group="Servers")
        titles = [e["title"] for e in entries]
        assert "New Test Entry" in titles


class TestIntegrationRotation:
    def test_rotation_cycle(self, integration_setup):
        """create -> deactivate -> confirm [INACTIVE] -> create same title."""
        from server.tools.read import list_entries
        from server.tools.write import create_entry, deactivate_entry

        vault, audit, config, db = integration_setup
        create_entry(vault, audit, title="Rotate Me", group="API Keys", username="u")
        deactivate_entry(vault, audit, title="Rotate Me", group="API Keys")
        entries = list_entries(vault, audit, group="API Keys", include_inactive=True)
        titles = [e["title"] for e in entries]
        assert "[INACTIVE] Rotate Me" in titles
        # Should be able to create a new entry with the same title
        create_entry(vault, audit, title="Rotate Me", group="API Keys", username="u2")


class TestIntegrationDuplicatePrevention:
    def test_duplicate_raises(self, integration_setup):
        """create_entry twice raises DuplicateEntry on second."""
        from server.tools.write import create_entry

        vault, audit, config, db = integration_setup
        create_entry(vault, audit, title="Unique Entry", group="SSH Keys", username="u")
        with pytest.raises(DuplicateEntry):
            create_entry(vault, audit, title="Unique Entry", group="SSH Keys", username="u2")


class TestIntegrationInactiveFiltering:
    def test_inactive_hidden_by_default(self, integration_setup):
        """list_entries hides [INACTIVE]; shows with flag."""
        from server.tools.read import list_entries

        vault, audit, config, db = integration_setup
        # The seeded db has "[INACTIVE] Old Server" in Servers
        visible = list_entries(vault, audit, group="Servers")
        visible_titles = [e["title"] for e in visible]
        assert "[INACTIVE] Old Server" not in visible_titles

        all_entries = list_entries(vault, audit, group="Servers", include_inactive=True)
        all_titles = [e["title"] for e in all_entries]
        assert "[INACTIVE] Old Server" in all_titles


class TestIntegrationGroupAllowlist:
    def test_disallowed_group_raises(self, integration_setup):
        """Request for unlisted group raises GroupNotAllowed."""
        from server.tools.read import list_entries

        vault, audit, config, db = integration_setup
        with pytest.raises(GroupNotAllowed):
            list_entries(vault, audit, group="Banking")
```

**Step 3: Run integration tests**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/integration/ -v --tb=short -m integration`
Expected: 6 passed

**Step 4: Run full suite**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/ -v --tb=short`
Expected: 106 passed

**Step 5: Commit**

```bash
git add tests/integration/test_integration.py
git commit -m "test(keepass-cred-mgr): fill integration test stubs with real keepassxc-cli calls"
```

---

### Task 3: Fill Coverage Gaps (94% → ~98%)

**Files:**
- Modify: `tests/unit/test_main.py`
- Modify: `tests/unit/test_tools.py`

**Step 1: Add 5 handler tests to `test_main.py`**

Add these test classes to `tests/unit/test_main.py`:

```python
class TestListEntriesHandler:
    def test_happy_path(self):
        from server.main import list_entries, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        entries = [{"title": "Test", "group": "Servers", "username": "u", "url": ""}]
        with patch("server.tools.read.list_entries", return_value=entries) as mock_le:
            result = list_entries(ctx, group="Servers", include_inactive=False)
            assert result == entries
            mock_le.assert_called_once_with(
                app.vault, app.audit, group="Servers", include_inactive=False
            )

    def test_group_not_allowed_maps_to_value_error(self):
        from server.main import list_entries, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.read.list_entries", side_effect=GroupNotAllowed("nope")):
            with pytest.raises(ValueError, match="GroupNotAllowed"):
                list_entries(ctx, group="Banking")


class TestSearchEntriesHandler:
    def test_happy_path(self):
        from server.main import search_entries, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        entries = [{"title": "Match", "group": "Servers", "username": "u", "url": ""}]
        with patch("server.tools.read.search_entries", return_value=entries) as mock_se:
            result = search_entries(ctx, query="Match", group=None, include_inactive=False)
            assert result == entries
            mock_se.assert_called_once()


class TestDeactivateEntryHandler:
    def test_vault_locked_maps_to_value_error(self):
        from server.main import deactivate_entry, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.write.deactivate_entry", side_effect=VaultLocked("locked")):
            with pytest.raises(ValueError, match="VaultLocked"):
                deactivate_entry(ctx, title="Test", group="Servers")

    def test_write_lock_timeout_maps_to_value_error(self):
        from server.main import deactivate_entry, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.write.deactivate_entry", side_effect=WriteLockTimeout("timeout")):
            with pytest.raises(ValueError, match="WriteLockTimeout"):
                deactivate_entry(ctx, title="Test", group="Servers")
```

Note: `test_main.py` already imports `VaultLocked`, `GroupNotAllowed`, `WriteLockTimeout` at the top. No new imports needed for the handler tests.

**Step 2: Add 3 search_entries tests to `test_tools.py`**

Add a new `TestSearchEntries` class to `tests/unit/test_tools.py`:

```python
class TestSearchEntries:
    @patch("subprocess.run")
    def test_search_with_group_filter(self, mock_run, unlocked_vault):
        """Explicit group filters results to only that group."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            # search returns entries from multiple groups
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Servers/Web Server\nSSH Keys/SSH Key\nAPI Keys/Anthropic\n",
                stderr=""
            ),
            # show Web Server (only this should be fetched for group="Servers")
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web\n",
                stderr=""
            ),
        ]
        result = search_entries(vault, audit, query="Server", group="Servers")
        assert len(result) == 1
        assert result[0]["title"] == "Web Server"

    @patch("subprocess.run")
    def test_search_filters_inactive_by_default(self, mock_run, unlocked_vault):
        """Inactive entries excluded when include_inactive=False."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Servers/Active Entry\nServers/[INACTIVE] Old Entry\n",
                stderr=""
            ),
            # show Active Entry
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Active Entry\nUserName: u\nURL: \n",
                stderr=""
            ),
        ]
        result = search_entries(vault, audit, query="Entry")
        assert len(result) == 1
        assert result[0]["title"] == "Active Entry"

    @patch("subprocess.run")
    def test_search_entry_without_group_prefix(self, mock_run, unlocked_vault):
        """Entries without group prefix (no '/') get group=None."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Standalone Entry\n",
                stderr=""
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Standalone Entry\nUserName: u\nURL: \n",
                stderr=""
            ),
        ]
        result = search_entries(vault, audit, query="Standalone")
        assert len(result) == 1
        assert result[0]["group"] is None
```

**Step 3: Run tests with coverage**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/ --cov=server --cov-report=term-missing --tb=short`
Expected: ~108 passed, coverage ≥ 97%

**Step 4: Commit**

```bash
git add tests/unit/test_main.py tests/unit/test_tools.py
git commit -m "test(keepass-cred-mgr): fill coverage gaps for handler and search_entries branches"
```

---

### Task 4: Add ruff + mypy Configuration

**Files:**
- Modify: `pyproject.toml`

**Step 1: Install dev tools**

Run: `pip install ruff mypy`

**Step 2: Add configuration to `pyproject.toml`**

Append these sections to `pyproject.toml`:

```toml
[tool.ruff]
target-version = "py312"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "UP"]

[tool.mypy]
python_version = "3.12"
strict = true
packages = ["server"]
exclude = ["tests/"]
```

Update the dev dependencies:

```toml
[project.optional-dependencies]
dev = ["pytest", "pytest-asyncio", "pytest-cov", "ruff", "mypy"]
```

**Step 3: Run ruff and fix any issues**

Run: `cd plugins/keepass-cred-mgr && ruff check server/ --fix`
Expected: Some import sorting or minor fixes; no functional changes

Run: `cd plugins/keepass-cred-mgr && ruff check server/`
Expected: All checks passed

**Step 4: Run mypy and fix any issues**

Run: `cd plugins/keepass-cred-mgr && mypy server/`

Fix any type errors. Common fixes:
- Add missing return types to functions
- Add type annotations for variables
- Fix `Optional[X]` to `X | None` if flagged by UP rules

**Step 5: Verify tests still pass after any fixes**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/ -v --tb=short`
Expected: All tests pass

**Step 6: Commit**

```bash
git add pyproject.toml server/
git commit -m "chore(keepass-cred-mgr): add ruff + mypy config, fix lint and type issues"
```

---

### Task 5: Final Verification

**Files:**
- None (read-only verification)

**Step 1: Run full test suite with coverage**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/ --cov=server --cov-report=term-missing --tb=short`
Expected: ~114 passed, coverage ≥ 97%

**Step 2: Run linters**

Run: `cd plugins/keepass-cred-mgr && ruff check server/ && mypy server/`
Expected: No errors

**Step 3: Verify server loads**

Run: `cd plugins/keepass-cred-mgr && python -c "from server.main import mcp; print(f'Tools: {len(mcp._tool_manager._tools)}')"`
Expected: `Tools: 8`

**Step 4: Run marketplace validation**

Run: `./scripts/validate-marketplace.sh`
Expected: All validations passed
