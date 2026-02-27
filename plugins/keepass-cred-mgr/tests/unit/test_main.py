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
