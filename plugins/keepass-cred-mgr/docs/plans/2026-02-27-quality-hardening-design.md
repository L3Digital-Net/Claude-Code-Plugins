# keepass-cred-mgr Quality Hardening Design

## Goal

Fill integration test stubs with real keepassxc-cli calls, close the remaining 6% coverage gap, and add static analysis (ruff + mypy).

## Current State

- 100 unit tests, 94% line coverage (29 lines missing across 3 files)
- 6 integration test stubs (all `pass`)
- No linter or type checker configured
- `keepassxc-cli` available; YubiKeys not yet available
- Test database script creates password-only `test.kdbx` with 3 groups and 7 entries

## Part 1: Integration Tests

### Problem

`Vault.run_cli()` passes `--yubikey <slot>` on every CLI call. This fails on a password-only test database. The 6 test stubs are `pass` because no password-mode vault exists.

### Solution

Create a `PasswordVault` subclass in the test fixtures that overrides `unlock()` and `run_cli()` to pipe the database password via stdin instead of using `--yubikey`. This class lives in `tests/conftest.py` or a test helper, not in production code.

Key differences from `Vault`:
- `unlock()`: runs `keepassxc-cli open` with password on stdin, no `--yubikey`
- `run_cli()`: pipes password on stdin for every command, omits `--yubikey`

### Tests to Fill

| Test | What it exercises |
|------|-------------------|
| `test_list_groups_returns_allowed` | `list_groups` returns only configured allowed groups |
| `test_create_then_list` | `create_entry` followed by `list_entries` shows the new entry |
| `test_rotation_cycle` | create -> deactivate -> verify `[INACTIVE]` prefix -> create same title again |
| `test_duplicate_raises` | `create_entry` twice with same title raises `DuplicateEntry` |
| `test_inactive_hidden_by_default` | `list_entries` hides `[INACTIVE]` entries; `include_inactive=True` shows them |
| `test_disallowed_group_raises` | Requesting an unlisted group raises `GroupNotAllowed` |

### Test Database

Run `tests/fixtures/create_test_db.sh` to seed `test.kdbx` (password: `testpassword`). The fixture copies it to `tmp_path` so writes don't pollute the original.

## Part 2: Coverage Gap Fill (94% → ~98%)

### Missing Lines

**`main.py` (16 lines, 85%)**
- Lines 103-109: `list_entries` handler happy path
- Lines 120-127: `search_entries` handler happy path
- Lines 152-153: `get_attachment` domain error → ValueError
- Lines 197-202: `deactivate_entry` domain errors

**`tools/read.py` (6 lines, 94%)**
- Lines 106, 117, 123, 125, 127-128: `search_entries` group filter, inactive filter, and entries-without-group-prefix branches

**`vault.py` (7 lines, 92%)**
- Lines 144-150: `start_polling` CancelledError handler for `self._grace_timer` cleanup

### New Tests (~8)

Add to `test_main.py`:
- `test_list_entries_happy_path`: delegates to `read_tools.list_entries` with correct args
- `test_search_entries_happy_path`: delegates to `read_tools.search_entries`
- `test_get_attachment_group_not_allowed`: `GroupNotAllowed` → `ValueError`
- `test_deactivate_entry_vault_locked`: `VaultLocked` → `ValueError`
- `test_deactivate_entry_write_lock_timeout`: `WriteLockTimeout` → `ValueError`

Add to `test_tools.py`:
- `test_search_entries_with_group_filter`: explicit group filters results
- `test_search_entries_filters_inactive_by_default`: inactive entries excluded
- `test_search_entries_entries_without_group_prefix`: entries lacking group prefix are skipped

## Part 3: Type Checking + Linting

### Tools

- **ruff**: fast Python linter and formatter. Rules: E (pycodestyle), F (pyflakes), I (isort), UP (pyupgrade for 3.12+).
- **mypy**: strict static type checking on `server/` package.

### Configuration

Add to `pyproject.toml`:

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
```

Add to dev dependencies: `ruff`, `mypy`.

### Expected Issues

- Missing return type annotations on some functions
- `Any` types from MagicMock interactions (test files excluded from mypy)
- Possible `Optional` vs `X | None` inconsistencies (UP rules will catch)

## Projected Outcome

| Metric | Before | After |
|--------|--------|-------|
| Unit tests | 100 | ~108 |
| Integration tests | 0 (6 stubs) | 6 |
| Line coverage | 94% | ~98% |
| Linting | none | ruff clean |
| Type checking | none | mypy strict clean |
