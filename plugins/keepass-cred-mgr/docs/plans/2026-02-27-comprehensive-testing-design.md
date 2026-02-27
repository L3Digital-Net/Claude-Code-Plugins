# keepass-cred-mgr Comprehensive Testing Design

## Goal

Raise the keepass-cred-mgr test suite from ~55-60% line coverage to 90%+ by filling all identified gaps, fixing a discovered bug, and implementing the integration test stubs.

## Current State

58 unit tests across 5 test files. `main.py` (the MCP handler layer) has 0% coverage. Integration tests are all `pass` stubs. Approximate per-file coverage:

| File | Coverage | Key Gaps |
|------|----------|----------|
| `config.py` | ~85% | No-path-no-env branch, empty YAML, non-string paths |
| `yubikey.py` | ~92% | `OSError` catch, returncode+stdout edge |
| `vault.py` | ~78% | Async cancel cleanup, subprocess timeout, properties |
| `audit.py` | ~95% | None fields, timestamp format, write errors |
| `tools/read.py` | ~70% | `_parse_show_output` edges, `group=None`, page_size |
| `tools/write.py` | ~65% | `_shred_file`, `_acquire_lock` timeout, str content, audit |
| `main.py` | **0%** | Everything: lifespan, handlers, error mapping, base64 |

## Bug Fix

`main.py` `add_attachment` handler does not catch `binascii.Error` from malformed base64 input. This causes an unhandled exception instead of a clean `ValueError`. Fix: add `binascii.Error` to the handler's exception tuple.

Additionally, `subprocess.TimeoutExpired` is not caught by any handler's exception tuple. A hanging `keepassxc-cli` process crashes the tool handler. Fix: add `subprocess.TimeoutExpired` to all 8 handler exception tuples.

## Approach

Expand in-place: add tests to existing files plus one new `test_main.py`. No file splits, no new dependencies.

## New Tests by File

### `tests/unit/test_main.py` (new, ~15 tests)

Highest priority. Tests the outermost MCP handler layer.

- `_get_ctx`: extracts `AppContext` from FastMCP `Context`
- `_error_text`: formats exception strings
- `app_lifespan`: startup wires config/vault/audit/polling; cleanup cancels poll task
- Each of 8 tool handlers: happy path delegates correctly; domain exceptions map to `ValueError`
- `add_attachment` handler: malformed base64 raises `ValueError` (regression test for bug fix)
- `get_attachment` handler: returns base64-encoded string

Mock strategy: patch the domain functions (`tools.read.*`, `tools.write.*`) to isolate the handler logic. Use `AsyncMock` for `app_lifespan` testing.

### `tests/unit/test_tools.py` (+12 tests)

**Read tools:**
- `_parse_show_output` directly: empty input, value containing `: `, unknown fields, case insensitivity
- `list_entries(group=None)`: iterates all allowed groups
- `list_entries` page_size truncation
- `search_entries` with explicit group filter
- `search_entries` filtering inactive entries
- `search_entries` with entries lacking group prefix

**Write tools:**
- `_acquire_lock` timeout raises `WriteLockTimeout`
- `_shred_file` on nonexistent file (OSError paths)
- `_shred_file` on zero-length file
- `create_entry` with partial optional fields (username only)
- `add_attachment` with `str` content (UTF-8 encode branch)
- Write tool audit logging (verify audit records for create, deactivate, add_attachment)

### `tests/unit/test_vault.py` (+6 tests)

- `unlock_time` property set to datetime after unlock
- `config` property accessor returns the Config object
- `_lock()` resets `_unlocked` and `_unlock_time`
- Cancel polling while grace timer is mid-countdown (async cleanup)
- `subprocess.TimeoutExpired` from `run_cli`
- Poll loop no-op when vault is locked and YubiKey removed

### `tests/unit/test_config.py` (+4 tests)

- `load_config()` with no path and no env var set
- Empty YAML file (yaml.safe_load returns None)
- Invalid YAML syntax
- Non-string `database_path` value (tilde expansion guard)

### `tests/unit/test_yubikey.py` (+2 tests)

- `OSError` in `RealYubiKey.is_present()`
- Non-zero returncode with non-empty stdout

### `tests/unit/test_audit.py` (+3 tests)

- `group=None` serializes to JSON null
- ISO timestamp format parseable by `datetime.fromisoformat`
- `PermissionError` on audit log file propagates

### `tests/integration/test_integration.py` (~6 tests)

Fill the existing stubs. Mock `subprocess.run` at the bottom of the call chain to simulate keepassxc-cli responses. Exercise the real path: handler -> tool function -> vault -> mocked subprocess.

Tests: list_groups, list_entries, get_entry, create_entry, deactivate_entry, get_attachment.

## Projected Outcome

| File | Before | After |
|------|--------|-------|
| `config.py` | ~85% | ~95% |
| `yubikey.py` | ~92% | ~98% |
| `vault.py` | ~78% | ~92% |
| `audit.py` | ~95% | ~98% |
| `tools/read.py` | ~70% | ~90%+ |
| `tools/write.py` | ~65% | ~90%+ |
| `main.py` | 0% | ~90% |
| **Overall** | **~58%** | **~90%+** |

Total: ~48 new tests, bringing the suite from 58 to ~106 tests.
