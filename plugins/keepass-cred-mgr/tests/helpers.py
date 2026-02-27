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
