# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.2] - 2026-02-28

### Added

- `unlock_vault` MCP tool: explicit vault unlock requiring YubiKey touch; must be called before any other vault tool
- `scripts/start-server.sh`: bash wrapper that resolves Python dependencies via `uv run --with` and starts the FastMCP server; eliminates manual `pip install` step for users
- PTH fake-tool simulation infrastructure (`scripts/fake-tools/`): fake `ykman` and `keepassxc-cli` binaries for plugin-test-harness sessions; prepended to PATH automatically by `start-server.sh` when the directory exists; never present in production

### Fixed

- MCP server startup: `.mcp.json` now uses flat `{"keepass": {...}}` format (the `mcpServers` wrapper is not supported in plugin context)
- Dependency resolution: server uses `uv run --with mcp,structlog,pyyaml,filelock` — no manual Python dependency installation required after plugin install
- `printf` format string handling in fake CLI: `printf -- '...'` prevents bash from interpreting leading dashes as option flags

## [0.1.1] - 2026-02-28

### Added

- 100 unit tests (up from 58): full handler layer coverage, edge cases for config, vault, audit, and tools
- `test_main.py` covering all 8 MCP handlers, `app_lifespan`, and helper functions (~90% coverage on `main.py`)
- ruff + mypy strict configuration; integration test framework with test database creation script

### Fixed

- `add_attachment` handler now catches `binascii.Error` from malformed base64 input
- All 8 MCP handlers now catch `subprocess.TimeoutExpired` from hanging `keepassxc-cli` processes

### Changed

- Comprehensive testing sweep: 58 → 100 tests, coverage raised to ~97%

## [0.1.0] - 2026-02-27

### Added

- FastMCP server with stdio transport and `app_lifespan` context manager
- YubiKey HMAC-SHA1 presence detection via `ykman list`, with configurable grace period on removal
- Vault state machine: locked/unlocked with background polling and auto-lock
- 5 read tools: `list_groups`, `list_entries`, `search_entries`, `get_entry`, `get_attachment`
- 3 write tools: `create_entry`, `deactivate_entry`, `add_attachment`
- Group allowlist restricting all tool access to configured groups
- Soft delete via `[INACTIVE]` prefix (no overwrite or hard delete)
- File locking for write operations via `filelock`
- Secure temp file handling: `chmod 600`, zero-fill before unlink
- JSONL audit logging for all secret-returning operations
- YAML configuration with env var override (`KEEPASS_CRED_MGR_CONFIG`)
- 6 credential-type skills: cPanel, FTP/SFTP, SSH, Brave Search API, Anthropic API, hygiene rules
- 3 slash commands: `/keepass-status`, `/keepass-rotate`, `/keepass-audit`
- Integration test framework with test database creation script
