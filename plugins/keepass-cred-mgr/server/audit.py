"""Structured audit logging for vault operations.

Writes one JSON record per line to the configured audit log path.
Secret values and attachment content are never logged.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path

import structlog

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.audit")

# Keys whose values are redacted in the extra-kwargs dict before writing to disk.
# This guards against callers accidentally passing sensitive data through **extra.
_SENSITIVE_KEY_FRAGMENTS = frozenset(
    {"password", "secret", "token", "api_key", "credential", "auth", "key"}
)


def _sanitize_extra(extra: dict[str, object]) -> dict[str, object]:
    return {
        k: "**REDACTED**"
        if any(fragment in k.lower() for fragment in _SENSITIVE_KEY_FRAGMENTS)
        else v
        for k, v in extra.items()
    }


class AuditLogger:
    def __init__(self, audit_log_path: str) -> None:
        path = Path(audit_log_path)
        if not path.parent.exists():
            raise FileNotFoundError(
                f"Audit log parent directory does not exist: {path.parent}"
            )
        self._path = path

    def log(
        self,
        *,
        tool: str,
        title: str | None = None,
        group: str | None = None,
        secret_returned: bool = False,
        attachment: str | None = None,
        **extra: object,
    ) -> None:
        record: dict[str, object] = {
            "timestamp": datetime.now(UTC).isoformat(),
            "tool": tool,
            "title": title,
            "group": group,
            "secret_returned": secret_returned,
            "attachment": attachment,
        }
        record.update(_sanitize_extra(extra))
        try:
            with open(self._path, "a") as f:
                f.write(json.dumps(record) + "\n")
        except OSError:
            log.warning("audit_write_failed", path=str(self._path), tool=tool)
