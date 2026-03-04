# Vault-Wide Search and Access Control — Implementation Plan

**Design doc:** `2026-03-03-vault-wide-search-design.md`
**Branch:** testing

---

## Batch 1: Core server exceptions and config

### Task 1 — `vault.py`: remove `GroupNotAllowed`, remove `check_group_allowed`, add new exceptions
- Remove `GroupNotAllowed` exception class
- Remove `check_group_allowed()` method
- Add `EntryRestricted` exception: "Entry is tagged AI RESTRICTED; access denied"
- Add `EntryReadOnly` exception: "Entry is tagged READ ONLY; write operations are not permitted"
- Verify: `grep -n "GroupNotAllowed\|check_group_allowed" server/vault.py` returns nothing (except imports if any)

### Task 2 — `config.py`: remove `allowed_groups`
- Remove `allowed_groups: list[str]` from `Config` dataclass
- Remove `"allowed_groups"` from `_REQUIRED_FIELDS`
- Remove the `allowed_groups` validation block in `_validate_config`
- Remove `allowed_groups=raw["allowed_groups"]` from `Config(...)` constructor call
- Verify: `grep -n "allowed_groups" server/config.py` returns nothing

### Task 3 — `read.py`: tag parsing in `_parse_show_output`
- Add `tags` key: parse `Tags:` line, split on `;`, strip whitespace, lowercase each item, return as set
- When `Tags:` line is absent, `tags` key is an empty set
- Update return type annotation to include `tags: set[str]`
- Verify: manually trace that `Tags: AI RESTRICTED;READ ONLY` → `{"ai restricted", "read only"}`

---

## Batch 2: read.py — list and search functions

### Task 4 — `read.py`: `list_groups` — remove allowlist filter
- Remove the `if g in vault.config.allowed_groups` filter
- Return all groups from `ls` output
- Verify: function returns all groups without filtering

### Task 5 — `read.py`: `list_entries` — remove allowlist, add AI RESTRICTED filter
- Remove `vault.config.allowed_groups` as default group list
- When `group=None`: call `await list_groups(vault)` first, then iterate over returned groups
- Remove `vault.check_group_allowed(group)` call
- After building `fields`, check `fields.get("tags", set())` for `"ai restricted"` — skip entry if found
- Verify: no reference to `allowed_groups` or `check_group_allowed` remains

### Task 6 — `read.py`: `search_entries` — remove allowlist, fix path parsing, add AI RESTRICTED filter
- Remove `vault.check_group_allowed(group)` call
- Remove `if grp and grp not in vault.config.allowed_groups: continue` filter
- Fix path parsing: replace `entry_path.partition("/")` with `rsplit`-based logic:
  ```python
  parts = entry_path.rsplit("/", 1)
  grp = parts[0] if len(parts) == 2 else None
  title = parts[-1]
  ```
- After fetching `fields`, check tags for `"ai restricted"` — skip entry if found
- Verify: multi-level path `"SSH Keys/Personal/SSH - laptop"` → `grp="SSH Keys/Personal"`, `title="SSH - laptop"`

### Task 7 — `read.py`: `get_entry` and `get_attachment` — remove group check, add EntryRestricted
- `get_entry`: remove `vault.check_group_allowed(group)`. After parsing fields, check tags for `"ai restricted"`; raise `EntryRestricted` if found.
- `get_attachment`: remove `vault.check_group_allowed(group)`. Fetch entry fields first (using `run_cli("show", ...)`) to check tags; raise `EntryRestricted` if `"ai restricted"` tag present.
- Import `EntryRestricted` from vault at top of file
- Verify: no `check_group_allowed` calls remain in read.py

---

## Batch 3: write.py and main.py

### Task 8 — `write.py`: remove group checks, add READ ONLY enforcement
- `create_entry`: remove `vault.check_group_allowed(group)`
- `deactivate_entry`: remove `vault.check_group_allowed(group)`. The existing `show` call already reads fields — extend `_parse_show_output` usage (or re-parse manually) to check tags; raise `EntryReadOnly` if `"read only"` tag present.
- `add_attachment`: remove `vault.check_group_allowed(group)`. Add a `show` call at the top to fetch entry fields and check tags; raise `EntryReadOnly` if `"read only"` tag present.
- `import_entries`: remove `vault.check_group_allowed(e["group"])` from the validation loop
- Import `EntryReadOnly` and `EntryRestricted` (if needed) from vault
- Verify: `grep -n "check_group_allowed" server/tools/write.py` returns nothing

### Task 9 — `main.py`: update exception handlers and docstrings
- Remove `GroupNotAllowed` from all `except` tuples (9 locations)
- Remove `GroupNotAllowed` from imports
- Add `EntryRestricted` to `get_entry` and `get_attachment` handlers
- Add `EntryReadOnly` to `deactivate_entry` and `add_attachment` handlers
- Add `EntryRestricted`, `EntryReadOnly` to vault imports
- Update `list_groups` docstring: `"List all KeePass groups"`
- Update `search_entries` docstring: `"Search entries vault-wide by keyword"`
- Update `import_entries` docstring: remove "All groups must be in the configured allowlist"
- Verify: `grep -n "GroupNotAllowed" server/main.py` returns nothing; imports compile

---

## Batch 4: tests

### Task 10 — `conftest.py`: remove `allowed_groups` from fixture
- Remove `"allowed_groups": ["Servers", "SSH Keys", "API Keys"]` line from `test_config` fixture
- Verify: fixture still constructs a valid `Config`

### Task 11 — `create_test_db.sh`: add sub-group and tagged entries
- Add: `keepassxc-cli mkdir "$DB" "SSH Keys/Personal"` (with password)
- Add entry `"SSH Keys/Personal/SSH - laptop"` with password
- Add entry `"API Keys/Secret Project"`, then tag it `AI RESTRICTED` via `keepassxc-cli edit --tags`
- Add entry `"Servers/Production DB"`, then tag it `READ ONLY` via `keepassxc-cli edit --tags`
- Regenerate `tests/fixtures/test.kdbx` by running the script

### Task 12 — Write unit tests
Create `tests/unit/test_read_tools.py` and `tests/unit/test_write_tools.py` covering:

**`test_read_tools.py`:**
- `test_parse_show_output_tags`: `Tags: AI RESTRICTED;READ ONLY` → `{"ai restricted", "read only"}`
- `test_parse_show_output_no_tags`: missing `Tags:` line → empty set
- `test_search_entries_multilevel_path`: mock CLI returns `"SSH Keys/Personal/SSH - laptop"` → correct group/title split
- `test_search_entries_excludes_ai_restricted`: entry with `ai restricted` tag absent from results
- `test_list_entries_excludes_ai_restricted`: same for list_entries
- `test_get_entry_ai_restricted_raises`: raises `EntryRestricted`
- `test_get_attachment_ai_restricted_raises`: raises `EntryRestricted`

**`test_write_tools.py`:**
- `test_deactivate_read_only_raises`: raises `EntryReadOnly`
- `test_add_attachment_read_only_raises`: raises `EntryReadOnly`
- `test_get_entry_read_only_succeeds`: read on `READ ONLY` entry returns normally

**`test_config.py` additions:**
- `test_config_no_allowed_groups`: config loads without the field
- `test_config_legacy_allowed_groups_ignored`: config with `allowed_groups` key still loads (extra key silently dropped)

---

## Batch 5: skills and docs

### Task 13 — `keepass-hygiene` skill: add lookup pattern and tag rules
Add three blocks after existing rules:

```
LOOKUP PATTERN (mandatory):
1. Call search_entries(query="<title or purpose>") to locate the entry. Never assume a group.
2. Use the group and title from the result when calling get_entry or get_attachment.
3. If search returns no results, try broader terms before reporting not found.

AI RESTRICTED tag: entries with this tag are blocked by the server. If you need an entry
that is tagged AI RESTRICTED, stop and inform the user. Do not attempt to access it.

READ ONLY tag: entries with this tag can be read freely. Never call deactivate_entry or
add_attachment on them. The server enforces this.
```

### Task 14 — All 5 credential skills: convert GROUP to STORAGE DEFAULT
In each of `keepass-credential-ssh`, `keepass-credential-anthropic`, `keepass-credential-ftp`, `keepass-credential-cpanel`, `keepass-credential-brave-search`:
- Change `GROUP: <name>` to `STORAGE DEFAULT: <name>`
- Add note after: `Group location applies to new entries only. Use search_entries to locate existing entries.`

### Task 15 — Setup docs: update vault path
In `docs/keepass-cred-mgr-setup.md`:
- Update any example `database_path` to `~/keepass/keepass_yubi.kdbx`
- Remove any mention of `allowed_groups` as a required config field

---

## Verification Checklist (final)

```bash
cd plugins/keepass-cred-mgr
grep -rn "allowed_groups\|GroupNotAllowed\|check_group_allowed" server/
uv run pytest tests/ -x -q
```

All `grep` hits should return empty. All tests should pass.
