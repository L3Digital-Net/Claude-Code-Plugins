# Vault-Wide Search and Access Control Design

**Date:** 2026-03-03
**Plugin:** keepass-cred-mgr
**Status:** Approved

## Problem

Agents fail to find credentials when:

1. An entry is not in the group the credential skill prescribed
2. An entry lives in a sub-group the skill didn't anticipate
3. A multi-part entry (e.g. public/private key pair) stores material in fields the agent didn't check

The root cause is a combination of `allowed_groups` acting as a hard allowlist and credential skills hardcoding group names as lookup constraints rather than storage conventions. Users cannot reorganize their vault without breaking agent lookups.

## Goals

- Agents find credentials regardless of where in the vault they live
- Users can freely reorganize groups without any config or skill changes
- Sensitive entries remain protected: `AI RESTRICTED` tag blocks all AI access; `READ ONLY` tag blocks writes
- Agents always search first rather than targeting a specific group

## Non-Goals

- Recursive `list_entries` (deferred; `search_entries` covers the discovery use case)
- Migrating existing config files (extra `allowed_groups` keys are silently ignored by the YAML loader)

## Vault Path

`~/keepass/keepass_yubi.kdbx`

---

## Section 1: Server Layer

### `config.py`

Remove `allowed_groups` entirely:

- Remove from `Config` dataclass
- Remove from `_REQUIRED_FIELDS`
- Remove validation block in `_validate_config`
- Remove from `Config(...)` constructor call in `load_config`

Remaining required fields: `database_path`, `audit_log_path`.
Optional fields unchanged: `yubikey_slot`, `grace_period_seconds`, `yubikey_poll_interval_seconds`, `write_lock_timeout_seconds`, `page_size`, `log_level`.

Backwards compatibility: existing config YAML files with `allowed_groups` continue to load — the extra key is ignored by the YAML loader.

### `vault.py`

- Remove `GroupNotAllowed` exception
- Remove `check_group_allowed()` method
- Add `EntryRestricted` exception: raised when an entry is tagged `AI RESTRICTED`
- Add `EntryReadOnly` exception: raised when a write is attempted on a `READ ONLY`-tagged entry

### `read.py`

**`_parse_show_output`** — add `tags` key. Parse the `Tags:` line from `keepassxc-cli show` output (format: `Tags: tag1;tag2`). Normalize to a set of lowercase strings. When the `Tags:` line is absent, return an empty set — not an error.

**`list_groups`** — remove `allowed_groups` filter. Return every group from root-level `ls` output.

**`list_entries`** — remove `allowed_groups` references. When `group=None`, call `list_groups` first then iterate over all root-level groups (still one level deep). Add `AI RESTRICTED` tag filter: silently exclude matching entries.

**`search_entries`** — remove `allowed_groups` filter. Fix multi-level path parsing: replace `partition("/")` with `rsplit("/", 1)` so `"SSH Keys/Personal/SSH - laptop"` correctly yields `group="SSH Keys/Personal"`, `title="SSH - laptop"`. Silently exclude entries tagged `AI RESTRICTED`.

**`get_entry`** — remove `check_group_allowed`. After fetching, check parsed `tags` for `ai restricted`; raise `EntryRestricted` if found.

**`get_attachment`** — remove `check_group_allowed`. Fetch the entry first to check tags; raise `EntryRestricted` if `ai restricted` tag is present.

### `write.py`

Remove `check_group_allowed` calls from all four write functions:
`create_entry`, `deactivate_entry`, `add_attachment`, `import_entries`.

Add `READ ONLY` enforcement:

- `deactivate_entry`: already calls `show` to read existing notes — add tag check there; raise `EntryReadOnly` if `read only` tag is present
- `add_attachment`: add a `show` call at the top for the tag check; raise `EntryReadOnly` if tagged

`create_entry` and `import_entries` create new entries and are unaffected.

### `main.py`

- Remove `GroupNotAllowed` from all `except` tuples
- Add `EntryRestricted` to `get_entry` and `get_attachment` handlers
- Add `EntryReadOnly` to `deactivate_entry` and `add_attachment` handlers
- Update `list_groups` docstring: "List all KeePass groups"
- Update `search_entries` docstring: "Search entries vault-wide by keyword"

---

## Section 2: Skill Layer

### `keepass-hygiene`

Add three blocks:

**Lookup pattern (mandatory):**
1. Call `search_entries(query="<title or purpose>")` to locate the entry — never assume a group
2. Use the `group` and `title` from the result when calling `get_entry` or `get_attachment`
3. If search returns no results, try broader terms before reporting not found

**`AI RESTRICTED` tag:**
Entries with this tag are blocked at the server level. If a search result returns an entry you need that is tagged `AI RESTRICTED`, stop and tell the user — do not attempt to access it.

**`READ ONLY` tag:**
Entries with this tag can be read freely. Never call `deactivate_entry` or `add_attachment` on them; the server will reject it.

### All 5 credential skills

Affected: `keepass-credential-ssh`, `keepass-credential-anthropic`, `keepass-credential-ftp`, `keepass-credential-cpanel`, `keepass-credential-brave-search`.

Change `GROUP: X` to `STORAGE DEFAULT: X` in each skill, with a note:

> Group location is a default for new entries only. Always use `search_entries` to locate existing entries — the user may have reorganized the vault.

---

## Section 3: Testing

### `conftest.py`

Remove `allowed_groups` from the `test_config` fixture.

### `create_test_db.sh`

Add three new seed items:

1. **Sub-group entry**: `mkdir "SSH Keys/Personal"` → add `"SSH Keys/Personal/SSH - laptop"` (tests multi-level path parsing)
2. **AI RESTRICTED entry**: add entry, then `keepassxc-cli edit --tags "AI RESTRICTED"` to tag it
3. **READ ONLY entry**: add entry, then `keepassxc-cli edit --tags "READ ONLY"` to tag it

### New unit tests

| Test | Verifies |
|------|----------|
| `test_parse_show_output_tags` | `Tags: ai restricted;read only` → `{"ai restricted", "read only"}`; missing `Tags:` → empty set |
| `test_search_entries_multilevel_path` | `"SSH Keys/Personal/SSH - laptop"` → `group="SSH Keys/Personal"`, `title="SSH - laptop"` |
| `test_get_entry_ai_restricted_raises` | `get_entry` on tagged entry raises `EntryRestricted` |
| `test_get_attachment_ai_restricted_raises` | `get_attachment` raises `EntryRestricted` |
| `test_search_excludes_ai_restricted` | Tagged entry absent from `search_entries` results |
| `test_list_entries_excludes_ai_restricted` | Tagged entry absent from `list_entries` results |
| `test_deactivate_read_only_raises` | `deactivate_entry` raises `EntryReadOnly` |
| `test_add_attachment_read_only_raises` | `add_attachment` raises `EntryReadOnly` |
| `test_get_entry_read_only_succeeds` | `get_entry` on `READ ONLY` entry returns normally |
| `test_config_no_allowed_groups` | Config loads without `allowed_groups` field |
| `test_config_legacy_allowed_groups_ignored` | Config with `allowed_groups` still loads |
