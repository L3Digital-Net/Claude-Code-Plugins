import subprocess
from unittest.mock import patch

import pytest

from server.config import load_config
from server.yubikey import MockYubiKey


@pytest.fixture
def unlocked_vault(test_config, mock_yubikey):
    """A vault that's been unlocked (CLI calls are mocked)."""
    from server.vault import Vault
    from server.audit import AuditLogger

    with patch("subprocess.run") as mock_run:
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
    audit = AuditLogger(test_config.audit_log_path)
    return vault, audit


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


class TestReadTools:
    @patch("subprocess.run")
    def test_list_groups(self, mock_run, unlocked_vault):
        from server.tools.read import list_groups

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="Servers/\nSSH Keys/\nAPI Keys/\nBanking/\nRecycle Bin/\n",
            stderr="",
        )
        result = list_groups(vault)
        # Banking and Recycle Bin should be filtered out
        assert set(result) == {"Servers", "SSH Keys", "API Keys"}

    @patch("subprocess.run")
    def test_list_entries_filters_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Web Server\n[INACTIVE] Old Server\nDB Server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: DB Server\nUserName: dba\nURL: https://db.example.com\n",
                stderr="",
            ),
        ]
        result = list_entries(vault, audit, group="Servers")
        assert len(result) == 2
        titles = [e["title"] for e in result]
        assert "Web Server" in titles
        assert "[INACTIVE] Old Server" not in titles

    @patch("subprocess.run")
    def test_list_entries_includes_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Web Server\n[INACTIVE] Old Server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: [INACTIVE] Old Server\nUserName: old\nURL: https://old.example.com\n",
                stderr="",
            ),
        ]
        result = list_entries(vault, audit, group="Servers", include_inactive=True)
        assert len(result) == 2

    @patch("subprocess.run")
    def test_get_entry_returns_full_record(self, mock_run, unlocked_vault):
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout=(
                "Title: Web Server\n"
                "UserName: admin\n"
                "Password: s3cret\n"
                "URL: https://web.example.com\n"
                "Notes: Production server\n"
            ),
            stderr="",
        )
        result = get_entry(vault, audit, title="Web Server", group="Servers")
        assert result["title"] == "Web Server"
        assert result["username"] == "admin"
        assert result["password"] == "s3cret"
        assert result["url"] == "https://web.example.com"
        assert result["notes"] == "Production server"

    @patch("subprocess.run")
    def test_get_entry_raises_on_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import get_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            get_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_get_entry_audits_secret(self, mock_run, unlocked_vault, test_config):
        import json
        from pathlib import Path
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="Title: Web Server\nUserName: admin\nPassword: s3cret\nURL: \nNotes: \n",
            stderr="",
        )
        get_entry(vault, audit, title="Web Server", group="Servers")
        log_line = Path(test_config.audit_log_path).read_text().strip()
        record = json.loads(log_line)
        assert record["tool"] == "get_entry"
        assert record["secret_returned"] is True

    @patch("subprocess.run")
    def test_search_entries(self, mock_run, unlocked_vault):
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Servers/Web Server\nBanking/My Bank\nAPI Keys/Anthropic\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Anthropic\nUserName: key\nURL: https://api.anthropic.com\n",
                stderr="",
            ),
        ]
        result = search_entries(vault, audit, query="server")
        # Banking/My Bank should be filtered out (not in allowed_groups)
        assert len(result) == 2
        groups = [e["group"] for e in result]
        assert "Banking" not in groups

    @patch("subprocess.run")
    def test_get_attachment(self, mock_run, unlocked_vault, test_config):
        import json
        from pathlib import Path
        from server.tools.read import get_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="ssh-ed25519 AAAA... user@host\n",
            stderr="",
        )
        result = get_attachment(
            vault, audit,
            title="SSH Key", attachment_name="id_ed25519.pub", group="SSH Keys",
        )
        assert b"ssh-ed25519" in result

        # Verify audit log
        log_line = Path(test_config.audit_log_path).read_text().strip().split("\n")[-1]
        record = json.loads(log_line)
        assert record["tool"] == "get_attachment"
        assert record["secret_returned"] is True
        assert record["attachment"] == "id_ed25519.pub"

    @patch("subprocess.run")
    def test_get_attachment_raises_on_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import get_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            get_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                group="SSH Keys",
            )

    @patch("subprocess.run")
    def test_list_entries_group_not_allowed(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            list_entries(vault, audit, group="Banking")


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


class TestWriteTools:
    @patch("subprocess.run")
    def test_create_entry(self, mock_run, unlocked_vault, test_config):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="Existing Entry\n", stderr=""
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
        ]
        create_entry(
            vault, audit,
            title="New Server",
            group="Servers",
            username="admin",
            password="pass123",
            url="https://new.example.com",
            notes="Test notes",
        )
        add_call = mock_run.call_args_list[-1]
        cmd = add_call.args[0] if add_call.args else add_call[0][0]
        cmd_str = " ".join(cmd) if isinstance(cmd, list) else str(cmd)
        assert "add" in cmd_str

    @patch("subprocess.run")
    def test_create_entry_rejects_duplicate(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import DuplicateEntry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="Existing Entry\n", stderr=""
        )
        with pytest.raises(DuplicateEntry):
            create_entry(
                vault, audit,
                title="Existing Entry",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_create_entry_rejects_slash_in_title(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="slash"):
            create_entry(
                vault, audit,
                title="Bad/Title",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_create_entry_group_not_allowed(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            create_entry(
                vault, audit,
                title="New Entry",
                group="Banking",
            )

    @patch("subprocess.run")
    def test_deactivate_entry(self, mock_run, unlocked_vault):
        from server.tools.write import deactivate_entry

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nNotes: Production server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
        ]
        deactivate_entry(vault, audit, title="Web Server", group="Servers")

        title_edit_call = mock_run.call_args_list[1]
        cmd = title_edit_call.args[0] if title_edit_call.args else title_edit_call[0][0]
        cmd_str = " ".join(cmd) if isinstance(cmd, list) else str(cmd)
        assert "[INACTIVE]" in cmd_str

    @patch("subprocess.run")
    def test_deactivate_already_inactive(self, mock_run, unlocked_vault):
        from server.tools.write import deactivate_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            deactivate_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_add_attachment(self, mock_run, unlocked_vault):
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        add_attachment(
            vault, audit,
            title="SSH Key",
            attachment_name="id_ed25519",
            content=b"ssh-ed25519 AAAA...",
            group="SSH Keys",
        )

    @patch("subprocess.run")
    def test_add_attachment_cleans_temp_file(self, mock_run, unlocked_vault):
        import os
        from server.tools.write import add_attachment
        import tempfile

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )

        original_ntf = tempfile.NamedTemporaryFile
        created_paths = []

        def tracking_ntf(**kwargs):
            f = original_ntf(**kwargs)
            created_paths.append(f.name)
            return f

        with patch("tempfile.NamedTemporaryFile", side_effect=tracking_ntf):
            add_attachment(
                vault, audit,
                title="SSH Key",
                attachment_name="id_ed25519",
                content=b"ssh-ed25519 AAAA...",
                group="SSH Keys",
            )

        for path in created_paths:
            assert not os.path.exists(path), f"Temp file not cleaned up: {path}"

    @patch("subprocess.run")
    def test_add_attachment_inactive_rejected(self, mock_run, unlocked_vault):
        from server.tools.write import add_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            add_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                content=b"key data",
                group="SSH Keys",
            )

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
