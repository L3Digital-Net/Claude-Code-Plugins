# Comprehensive Testing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Raise keepass-cred-mgr test coverage from ~58% to 90%+ by filling all unit test gaps, creating handler-layer tests, fixing a base64 decoding bug, and implementing integration test stubs.

**Architecture:** Expand existing test files in-place. Add one new file (`test_main.py`) for the MCP handler layer. Fix one real bug (`binascii.Error` uncaught in `add_attachment` handler) and one risk (`subprocess.TimeoutExpired` uncaught in all handlers). All tests mock at the `subprocess.run` boundary.

**Tech Stack:** pytest, pytest-asyncio, unittest.mock (patch/MagicMock/AsyncMock), filelock

---

## Dependency Map

```
Task 1 (bug fix) ← Task 7 (test_main.py — validates bug fix)
Tasks 2-6 are independent of each other
Task 7 depends on Task 1
Task 8 depends on Tasks 2-7
```

---

### Task 1: Fix `main.py` Bug — Uncaught `binascii.Error` and `subprocess.TimeoutExpired`

**Files:**
- Modify: `server/main.py:219-222` (add_attachment handler exception tuple)
- Modify: `server/main.py:90-91,106-107,124-125,134-135,150-151,176-179,195-197` (all handler exception tuples)

**Step 1: Add `binascii.Error` to the `add_attachment` handler**

In `server/main.py`, change the `add_attachment` handler's exception tuple (line 219-222) from:

```python
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError,
    ) as e:
```

to:

```python
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError, binascii.Error,
    ) as e:
```

And add `import binascii` at the top (line 10):

```python
import binascii
```

**Step 2: Add `subprocess.TimeoutExpired` to ALL 8 handler exception tuples**

Add `import subprocess` to imports, then add `subprocess.TimeoutExpired` to every handler's `except` tuple. The complete list of handlers and their new tuples:

`list_groups` (line 90):
```python
    except (VaultLocked, YubiKeyNotPresent, KeePassCLIError, subprocess.TimeoutExpired) as e:
```

`list_entries` (line 106):
```python
    except (VaultLocked, GroupNotAllowed, KeePassCLIError, subprocess.TimeoutExpired) as e:
```

`search_entries` (line 124):
```python
    except (VaultLocked, GroupNotAllowed, KeePassCLIError, subprocess.TimeoutExpired) as e:
```

`get_entry` (line 134):
```python
    except (VaultLocked, EntryInactive, GroupNotAllowed, KeePassCLIError, subprocess.TimeoutExpired) as e:
```

`get_attachment` (line 150):
```python
    except (VaultLocked, EntryInactive, GroupNotAllowed, KeePassCLIError, subprocess.TimeoutExpired) as e:
```

`create_entry` (line 176):
```python
    except (
        VaultLocked, GroupNotAllowed, DuplicateEntry,
        WriteLockTimeout, KeePassCLIError, ValueError, subprocess.TimeoutExpired,
    ) as e:
```

`deactivate_entry` (line 195):
```python
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError, subprocess.TimeoutExpired,
    ) as e:
```

`add_attachment` (line 219):
```python
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError, binascii.Error, subprocess.TimeoutExpired,
    ) as e:
```

**Step 3: Run existing tests to confirm no regressions**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/ -v --tb=short`
Expected: 58 passed, 1 skipped

**Step 4: Commit**

```bash
git add server/main.py
git commit -m "fix(keepass-cred-mgr): catch binascii.Error and TimeoutExpired in MCP handlers"
```

---

### Task 2: Expand `test_config.py` — 4 Edge Case Tests

**Files:**
- Modify: `tests/unit/test_config.py`

**Step 1: Write 4 new tests**

Add to the `TestConfigLoading` class in `tests/unit/test_config.py`:

```python
    def test_raises_when_no_path_and_no_env_var(self, monkeypatch):
        """load_config() with no path and no env var."""
        monkeypatch.delenv("KEEPASS_CRED_MGR_CONFIG", raising=False)
        with pytest.raises(FileNotFoundError, match="No config path provided"):
            load_config()

    def test_empty_yaml_file_raises(self, tmp_path):
        """Empty YAML file still enforces required fields."""
        config_file = tmp_path / "empty.yaml"
        config_file.write_text("")
        with pytest.raises(ValueError, match="Missing required config field"):
            load_config(str(config_file))

    def test_invalid_yaml_raises(self, tmp_path):
        """Malformed YAML raises yaml.YAMLError."""
        import yaml as yaml_mod
        config_file = tmp_path / "bad.yaml"
        config_file.write_text("{{invalid:: yaml::")
        with pytest.raises(yaml_mod.YAMLError):
            load_config(str(config_file))

    def test_non_string_path_skips_tilde_expansion(self, tmp_path):
        """Integer database_path bypasses expanduser but still works."""
        audit_path = tmp_path / "audit.jsonl"
        cfg = {
            "database_path": 12345,
            "allowed_groups": ["Servers"],
            "audit_log_path": str(audit_path),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        config = load_config(str(config_file))
        assert config.database_path == 12345
```

**Step 2: Run tests**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/test_config.py -v --tb=short`
Expected: 12 passed

**Step 3: Commit**

```bash
git add tests/unit/test_config.py
git commit -m "test(keepass-cred-mgr): add config edge case tests (empty YAML, no-path, non-string)"
```

---

### Task 3: Expand `test_yubikey.py` — 2 Edge Case Tests

**Files:**
- Modify: `tests/unit/test_yubikey.py`

**Step 1: Write 2 new tests**

Add to `TestRealYubiKey` class in `tests/unit/test_yubikey.py`:

```python
    @patch("subprocess.run")
    def test_not_present_on_os_error(self, mock_run):
        """OSError (e.g., ykman not installed) returns False."""
        from server.yubikey import RealYubiKey

        mock_run.side_effect = OSError("No such file or directory")
        yk = RealYubiKey(slot=2)
        assert yk.is_present() is False

    @patch("subprocess.run")
    def test_non_zero_returncode_with_stdout(self, mock_run):
        """Non-zero returncode with stdout still returns True (stdout check only)."""
        from server.yubikey import RealYubiKey

        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=1, stdout="YubiKey 5C Nano\n", stderr="warning"
        )
        yk = RealYubiKey(slot=2)
        # The code checks bool(stdout.strip()), not returncode
        assert yk.is_present() is True
```

**Step 2: Run tests**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/test_yubikey.py -v --tb=short`
Expected: 13 passed

**Step 3: Commit**

```bash
git add tests/unit/test_yubikey.py
git commit -m "test(keepass-cred-mgr): add YubiKey OSError and returncode edge cases"
```

---

### Task 4: Expand `test_vault.py` — 6 New Tests

**Files:**
- Modify: `tests/unit/test_vault.py`

**Step 1: Write 6 new tests**

Add a new `TestVaultProperties` class and a `TestVaultLock` class, plus expand `TestVaultRunCli` and `TestVaultGraceTimer`:

```python
class TestVaultProperties:
    @patch("subprocess.run")
    def test_unlock_time_set_after_unlock(self, mock_run, test_config, mock_yubikey):
        """unlock_time is a UTC datetime after successful unlock."""
        from datetime import datetime, timezone
        from server.vault import Vault

        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        vault = Vault(test_config, mock_yubikey)
        assert vault.unlock_time is None
        vault.unlock()
        assert isinstance(vault.unlock_time, datetime)
        assert vault.unlock_time.tzinfo == timezone.utc

    def test_config_property(self, test_config, mock_yubikey):
        """config property returns the Config object."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.config is test_config
        assert vault.config.database_path == test_config.database_path


class TestVaultLock:
    @patch("subprocess.run")
    def test_lock_resets_state(self, mock_run, test_config, mock_yubikey):
        """_lock() sets is_unlocked to False."""
        from server.vault import Vault

        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        assert vault.is_unlocked is True
        vault._lock()
        assert vault.is_unlocked is False
```

Add to `TestVaultRunCli`:

```python
    @patch("subprocess.run")
    def test_run_cli_raises_on_timeout(self, mock_run, test_config, mock_yubikey):
        """subprocess.TimeoutExpired propagates from run_cli."""
        mock_run.side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            subprocess.TimeoutExpired(cmd=["keepassxc-cli"], timeout=30),
        ]
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        with pytest.raises(subprocess.TimeoutExpired):
            vault.run_cli("show", test_config.database_path, "Servers/Entry")
```

Add to `TestVaultGraceTimer`:

```python
    @pytest.mark.asyncio
    async def test_cancel_polling_during_grace_timer(self, test_config):
        """Cancelling poll task while grace timer is active cleans up both tasks."""
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            vault.unlock()

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        # Wait just enough for grace timer to start but not finish
        await asyncio.sleep(0.5)
        assert vault._grace_timer is not None
        # Cancel polling while grace timer is mid-countdown
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass
        # Vault should still be unlocked (grace didn't finish)
        assert vault.is_unlocked is True

    @pytest.mark.asyncio
    async def test_poll_noop_when_locked_and_yubikey_removed(self, test_config):
        """No grace timer starts when vault is already locked."""
        from server.vault import Vault

        yk = MockYubiKey(present=False)
        vault = Vault(test_config, yk)
        # Vault starts locked, YubiKey absent
        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(1.5)
        assert vault._grace_timer is None
        assert vault.is_unlocked is False
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass
```

**Step 2: Run tests**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/test_vault.py -v --tb=short`
Expected: 20 passed

**Step 3: Commit**

```bash
git add tests/unit/test_vault.py
git commit -m "test(keepass-cred-mgr): add vault property, lock, timeout, and async edge case tests"
```

---

### Task 5: Expand `test_audit.py` — 3 New Tests

**Files:**
- Modify: `tests/unit/test_audit.py`

**Step 1: Write 3 new tests**

Add to `TestAuditLogger` class in `tests/unit/test_audit.py`:

```python
    def test_group_none_serializes_to_null(self, tmp_path):
        """group=None writes JSON null."""
        import json
        audit_path = tmp_path / "audit.jsonl"
        logger = AuditLogger(str(audit_path))
        logger.log(tool="get_entry", title="Test", group=None, secret_returned=True)
        record = json.loads(audit_path.read_text().strip())
        assert record["group"] is None
        assert record["attachment"] is None

    def test_timestamp_is_valid_iso_format(self, tmp_path):
        """Timestamp can be parsed by datetime.fromisoformat."""
        from datetime import datetime
        import json
        audit_path = tmp_path / "audit.jsonl"
        logger = AuditLogger(str(audit_path))
        logger.log(tool="test", title="Test")
        record = json.loads(audit_path.read_text().strip())
        parsed = datetime.fromisoformat(record["timestamp"])
        assert parsed.year >= 2026

    def test_permission_error_propagates(self, tmp_path):
        """Write failure raises OSError."""
        import os
        audit_path = tmp_path / "audit.jsonl"
        logger = AuditLogger(str(audit_path))
        # Create file as read-only
        audit_path.write_text("")
        os.chmod(audit_path, 0o444)
        try:
            with pytest.raises(PermissionError):
                logger.log(tool="test", title="Test")
        finally:
            os.chmod(audit_path, 0o644)
```

**Step 2: Run tests**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/test_audit.py -v --tb=short`
Expected: 9 passed

**Step 3: Commit**

```bash
git add tests/unit/test_audit.py
git commit -m "test(keepass-cred-mgr): add audit logger edge cases (null fields, timestamp, permissions)"
```

---

### Task 6: Expand `test_tools.py` — 12 New Tests

**Files:**
- Modify: `tests/unit/test_tools.py`

**Step 1: Write 6 new read tool tests**

Add a new `TestParseShowOutput` class and expand `TestReadTools`:

```python
class TestParseShowOutput:
    """Direct tests for the _parse_show_output helper."""

    def test_empty_input(self):
        from server.tools.read import _parse_show_output
        assert _parse_show_output("") == {}

    def test_value_containing_colon(self):
        """Values with ': ' are handled correctly by partition."""
        from server.tools.read import _parse_show_output
        result = _parse_show_output("Notes: URL: https://example.com\n")
        assert result["notes"] == "URL: https://example.com"

    def test_unknown_fields_ignored(self):
        from server.tools.read import _parse_show_output
        result = _parse_show_output("CustomField: something\nTitle: My Entry\n")
        assert result == {"title": "My Entry"}

    def test_case_insensitive_keys(self):
        from server.tools.read import _parse_show_output
        result = _parse_show_output("USERNAME: admin\nPASSWORD: s3cret\n")
        assert result["username"] == "admin"
        assert result["password"] == "s3cret"
```

Add to `TestReadTools`:

```python
    @patch("subprocess.run")
    def test_list_entries_group_none_iterates_all(self, mock_run, unlocked_vault):
        """group=None iterates all allowed_groups."""
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        # 3 allowed groups: Servers, SSH Keys, API Keys
        # Each returns one entry + one show call = 6 total subprocess calls
        mock_run.side_effect = [
            # ls Servers
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Web Server\n", stderr=""),
            # show Web Server
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Title: Web Server\nUserName: admin\nURL: https://web\n", stderr=""),
            # ls SSH Keys
            subprocess.CompletedProcess(args=[], returncode=0, stdout="My SSH Key\n", stderr=""),
            # show My SSH Key
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Title: My SSH Key\nUserName: user\nURL: \n", stderr=""),
            # ls API Keys
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Anthropic\n", stderr=""),
            # show Anthropic
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Title: Anthropic\nUserName: key\nURL: https://api\n", stderr=""),
        ]
        result = list_entries(vault, audit, group=None)
        assert len(result) == 3
        groups = {e["group"] for e in result}
        assert groups == {"Servers", "SSH Keys", "API Keys"}

    @patch("subprocess.run")
    def test_list_entries_page_size_truncation(self, mock_run, unlocked_vault, test_config):
        """Results truncated at page_size limit."""
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        # Override page_size to 2 for testing
        # We need a config with page_size=2
        import yaml
        from pathlib import Path
        from server.config import load_config
        from server.vault import Vault

        # Create a custom vault with page_size=2
        tmp_dir = Path(test_config.database_path).parent
        cfg = {
            "database_path": test_config.database_path,
            "yubikey_slot": 2,
            "grace_period_seconds": 2,
            "yubikey_poll_interval_seconds": 1,
            "write_lock_timeout_seconds": 2,
            "page_size": 2,
            "allowed_groups": ["Servers"],
            "audit_log_path": test_config.audit_log_path,
        }
        config_file = tmp_dir / "config_small.yaml"
        config_file.write_text(yaml.dump(cfg))
        small_config = load_config(str(config_file))
        from server.yubikey import MockYubiKey
        small_vault = Vault(small_config, MockYubiKey(present=True))
        small_vault._unlocked = True
        from server.audit import AuditLogger
        small_audit = AuditLogger(small_config.audit_log_path)

        mock_run.side_effect = [
            # ls returns 5 entries
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Entry1\nEntry2\nEntry3\nEntry4\nEntry5\n", stderr=""),
            # show Entry1
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Title: Entry1\nUserName: u1\nURL: \n", stderr=""),
            # show Entry2
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Title: Entry2\nUserName: u2\nURL: \n", stderr=""),
            # Entry3-5 should never be called because page_size=2
        ]
        result = list_entries(small_vault, small_audit, group="Servers")
        assert len(result) == 2
```

**Step 2: Write 6 new write tool tests**

Add to `TestWriteTools`:

```python
    @patch("subprocess.run")
    def test_acquire_lock_timeout_raises(self, mock_run, unlocked_vault, test_config):
        """WriteLockTimeout when lock is held by another process."""
        from server.tools.write import _acquire_lock
        from server.vault import WriteLockTimeout
        from filelock import FileLock

        vault, audit = unlocked_vault
        lock_path = test_config.database_path + ".lock"
        # Acquire lock from outside to simulate contention
        blocking_lock = FileLock(lock_path, timeout=0)
        blocking_lock.acquire()
        try:
            with pytest.raises(WriteLockTimeout):
                _acquire_lock(vault)
        finally:
            blocking_lock.release()

    def test_shred_file_nonexistent(self, tmp_path):
        """_shred_file on nonexistent file does not raise."""
        from server.tools.write import _shred_file
        fake_path = str(tmp_path / "nonexistent.tmp")
        # Should not raise
        _shred_file(fake_path)

    def test_shred_file_zero_length(self, tmp_path):
        """_shred_file on zero-length file still unlinks."""
        import os
        from server.tools.write import _shred_file
        empty_file = tmp_path / "empty.tmp"
        empty_file.write_bytes(b"")
        _shred_file(str(empty_file))
        assert not os.path.exists(str(empty_file))

    @patch("subprocess.run")
    def test_create_entry_partial_fields(self, mock_run, unlocked_vault):
        """create_entry with only username (no password, url, notes)."""
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            # ls returns no existing entries
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            # add succeeds
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
        ]
        create_entry(vault, audit, title="New", group="Servers", username="admin")
        add_call = mock_run.call_args_list[-1]
        cmd = add_call.args[0] if add_call.args else add_call[0][0]
        assert "--username" in cmd
        assert "--password" not in cmd
        assert "--url" not in cmd
        assert "--notes" not in cmd

    @patch("subprocess.run")
    def test_add_attachment_with_str_content(self, mock_run, unlocked_vault):
        """str content is encoded to UTF-8 before writing to temp file."""
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        # Pass string instead of bytes
        add_attachment(
            vault, audit,
            title="SSH Key",
            attachment_name="id_ed25519.pub",
            content="ssh-ed25519 AAAA... user@host",
            group="SSH Keys",
        )

    @patch("subprocess.run")
    def test_write_tools_produce_audit_records(self, mock_run, unlocked_vault, test_config):
        """All 3 write tools produce audit records."""
        import json
        from pathlib import Path
        from server.tools.write import create_entry, deactivate_entry, add_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        # Provide different side_effects for each operation
        mock_run.side_effect = [
            # create_entry: ls for duplicates
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            # create_entry: add
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            # deactivate_entry: show for notes
            subprocess.CompletedProcess(args=[], returncode=0, stdout="Title: Entry2\nNotes: \n", stderr=""),
            # deactivate_entry: edit title
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            # deactivate_entry: edit notes
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            # add_attachment: attachment-import
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
        ]

        create_entry(vault, audit, title="Entry1", group="Servers", username="u")
        deactivate_entry(vault, audit, title="Entry2", group="Servers")
        add_attachment(vault, audit, title="Entry3", attachment_name="f.txt", content=b"data", group="SSH Keys")

        log_lines = Path(test_config.audit_log_path).read_text().strip().split("\n")
        assert len(log_lines) == 3
        tools = [json.loads(line)["tool"] for line in log_lines]
        assert tools == ["create_entry", "deactivate_entry", "add_attachment"]
```

**Step 2: Run tests**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/test_tools.py -v --tb=short`
Expected: 31 passed

**Step 3: Commit**

```bash
git add tests/unit/test_tools.py
git commit -m "test(keepass-cred-mgr): add parse_show, page_size, lock timeout, shred, and audit tests"
```

---

### Task 7: Create `test_main.py` — MCP Handler Layer Tests

**Files:**
- Create: `tests/unit/test_main.py`

**Step 1: Write the full test file**

Create `tests/unit/test_main.py`:

```python
"""Tests for the MCP server entry point (main.py).

Tests the handler layer: context extraction, error translation,
base64 encode/decode, and app_lifespan lifecycle.
"""

import asyncio
import base64
import subprocess
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from server.vault import (
    DuplicateEntry,
    EntryInactive,
    GroupNotAllowed,
    KeePassCLIError,
    VaultLocked,
    WriteLockTimeout,
    YubiKeyNotPresent,
)


class TestHelpers:
    def test_error_text_formats_exception(self):
        from server.main import _error_text
        e = VaultLocked("unlock first")
        assert _error_text(e) == "VaultLocked: unlock first"

    def test_error_text_with_generic_exception(self):
        from server.main import _error_text
        e = ValueError("bad input")
        assert _error_text(e) == "ValueError: bad input"

    def test_get_ctx_extracts_app_context(self):
        from server.main import _get_ctx, AppContext
        mock_ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        mock_ctx.request_context.lifespan_context = app
        assert _get_ctx(mock_ctx) is app


class TestListGroupsHandler:
    def test_happy_path(self):
        from server.main import list_groups, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.read.list_groups", return_value=["Servers"]) as mock_lg:
            result = list_groups(ctx)
            assert result == ["Servers"]
            mock_lg.assert_called_once_with(app.vault)

    def test_vault_locked_maps_to_value_error(self):
        from server.main import list_groups, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.read.list_groups", side_effect=VaultLocked("locked")):
            with pytest.raises(ValueError, match="VaultLocked"):
                list_groups(ctx)

    def test_timeout_maps_to_value_error(self):
        from server.main import list_groups, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.read.list_groups", side_effect=subprocess.TimeoutExpired("cmd", 30)):
            with pytest.raises(ValueError, match="TimeoutExpired"):
                list_groups(ctx)


class TestGetEntryHandler:
    def test_happy_path(self):
        from server.main import get_entry, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        entry = {"title": "Test", "username": "u", "password": "p", "url": "", "notes": ""}
        with patch("server.tools.read.get_entry", return_value=entry) as mock_ge:
            result = get_entry(ctx, title="Test", group="Servers")
            assert result["password"] == "p"
            mock_ge.assert_called_once()

    def test_entry_inactive_maps_to_value_error(self):
        from server.main import get_entry, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.read.get_entry", side_effect=EntryInactive("inactive")):
            with pytest.raises(ValueError, match="EntryInactive"):
                get_entry(ctx, title="[INACTIVE] Old", group="Servers")


class TestGetAttachmentHandler:
    def test_returns_base64_encoded(self):
        from server.main import get_attachment, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        raw_bytes = b"ssh-ed25519 AAAA..."
        with patch("server.tools.read.get_attachment", return_value=raw_bytes):
            result = get_attachment(ctx, title="SSH Key", attachment_name="id_ed25519.pub", group="SSH Keys")
            assert base64.b64decode(result) == raw_bytes


class TestCreateEntryHandler:
    def test_returns_confirmation_string(self):
        from server.main import create_entry, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.write.create_entry"):
            result = create_entry(ctx, title="New", group="Servers")
            assert "Created entry" in result

    def test_duplicate_maps_to_value_error(self):
        from server.main import create_entry, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.write.create_entry", side_effect=DuplicateEntry("exists")):
            with pytest.raises(ValueError, match="DuplicateEntry"):
                create_entry(ctx, title="Dup", group="Servers")


class TestDeactivateEntryHandler:
    def test_returns_confirmation_string(self):
        from server.main import deactivate_entry, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with patch("server.tools.write.deactivate_entry"):
            result = deactivate_entry(ctx, title="Old", group="Servers")
            assert "Deactivated" in result


class TestAddAttachmentHandler:
    def test_happy_path_decodes_base64(self):
        from server.main import add_attachment, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        content = base64.b64encode(b"key data").decode("ascii")
        with patch("server.tools.write.add_attachment") as mock_aa:
            result = add_attachment(ctx, title="Key", attachment_name="id", content=content, group="SSH Keys")
            assert "Attached" in result
            call_kwargs = mock_aa.call_args.kwargs
            assert call_kwargs["content"] == b"key data"

    def test_malformed_base64_raises_value_error(self):
        """Regression test: binascii.Error must be caught."""
        from server.main import add_attachment, AppContext
        ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        ctx.request_context.lifespan_context = app
        with pytest.raises(ValueError, match="Error"):
            add_attachment(ctx, title="Key", attachment_name="id", content="!!!NOT-BASE64!!!", group="SSH Keys")


class TestAppLifespan:
    @pytest.mark.asyncio
    async def test_lifespan_starts_and_stops_polling(self):
        """app_lifespan creates vault, audit, polling task; cleanup cancels task."""
        from server.main import app_lifespan, AppContext

        with patch("server.main.load_config") as mock_cfg, \
             patch("server.main.RealYubiKey") as mock_yk_cls, \
             patch("server.main.Vault") as mock_vault_cls, \
             patch("server.main.AuditLogger") as mock_audit_cls:

            mock_cfg.return_value = MagicMock()
            mock_yk_cls.return_value = MagicMock()
            mock_vault = MagicMock()
            mock_vault.start_polling = AsyncMock()
            mock_vault_cls.return_value = mock_vault
            mock_audit_cls.return_value = MagicMock()

            server = MagicMock()
            async with app_lifespan(server) as ctx:
                assert isinstance(ctx, AppContext)
                assert ctx.vault is mock_vault
                # Poll task should be running
                assert ctx.poll_task is not None
            # After exit, poll task should have been cancelled
            # (the poll_task is an asyncio.Task wrapping start_polling)
```

**Step 2: Run tests**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/unit/test_main.py -v --tb=short`
Expected: 15 passed

**Step 3: Run full suite**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/ -v --tb=short`
Expected: ~106 passed, 1 skipped

**Step 4: Commit**

```bash
git add tests/unit/test_main.py
git commit -m "test(keepass-cred-mgr): add MCP handler layer tests (15 tests, 0% -> ~90% on main.py)"
```

---

### Task 8: Final Verification

**Files:**
- None (read-only verification)

**Step 1: Run full test suite**

Run: `cd plugins/keepass-cred-mgr && python -m pytest tests/ -v --tb=short`
Expected: ~106 passed, 1 skipped

**Step 2: Verify server still loads**

Run: `cd plugins/keepass-cred-mgr && python -c "from server.main import mcp; print(f'Tools: {len(mcp._tool_manager._tools)}')" `
Expected: `Tools: 8`

**Step 3: Run marketplace validation**

Run: `cd /home/chris/projects/Claude-Code-Plugins && ./scripts/validate-marketplace.sh`
Expected: All validations passed

**Step 4: Commit if any cleanup needed, otherwise done**
