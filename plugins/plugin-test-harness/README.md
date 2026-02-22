# Plugin Test Harness (PTH)

An MCP-based iterative testing framework for Claude Code plugins and MCP servers. Drives a tight test/fix/reload loop — generating tests, recording pass/fail results, applying source fixes, reloading the target plugin, and retesting — until your plugin converges to a stable, passing state.

## Summary

PTH treats plugin testing as an iterative convergence problem rather than a one-shot process. Each session creates a dedicated git branch and git worktree in the target plugin's repository, giving you a complete audit trail of every test added and fix applied. Sessions persist to disk and can be resumed after interruption. Claude drives the loop interactively — you can inspect results, override decisions, or add tests at any point.

## Principles

**[P1] Claude's Judgment, Not Mechanical Rules** — No rigid enforcement gates or hard-coded safety thresholds. Claude assesses risk, decides approval workflows, and manages safety contextually — because tests span wildly varying plugin domains and environment configurations where rigid rules would be either too restrictive or too permissive.

**[P2] Convergence Over Single-Pass** — Testing is an iterative convergence problem. PTH drives successive test/fix/reload cycles and measures the trend (improving, plateaued, oscillating, declining) across iterations. A plugin is not done when the first run passes.

**[P3] Durable Session Assets** — The git branch and test definitions are the session's durable assets. If the environment fails catastrophically, the session can always be resumed from these.

**[P4] Transparent Errors** — PTH always surfaces raw error output alongside its own interpretation. Exceptions are never silently swallowed; Claude always has enough context to decide the next step.

**[P5] Audit Trail by Default** — Every fix is committed to the session branch immediately. The full debug history is always recoverable via `git log` — no extra logging or manual export required.

## Installation

```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install plugin-test-harness@l3digitalnet-plugins
```

## Installation Notes

After installation, navigate to the plugin cache directory and install Node.js dependencies:

```bash
cd ~/.claude/plugins/<marketplace>/plugin-test-harness
npm install
```

The `dist/` directory ships prebuilt — a build step is only required if you modify the TypeScript source.

## Usage

PTH operates as an iterative loop. Start with a preflight check, then cycle through generate → run → record → fix → reload until convergence:

```
pth_preflight       → verify target plugin path, git repo, and session lock status
pth_start_session   → create session branch + git worktree, detect plugin mode
pth_generate_tests  → auto-generate tests (MCP: spawns server to fetch schemas; plugin: scans hooks)
[Run tests — call each tool and evaluate output]
pth_record_result   → record pass/fail for each test
pth_get_iteration_status → check convergence trend and iteration table
pth_apply_fix       → write file changes and commit to session branch
pth_reload_plugin   → rebuild, sync to cache, restart MCP server
[Repeat from pth_generate_tests or pth_record_result]
pth_end_session     → persist tests, generate SESSION-REPORT.md, close worktree
```

To resume an interrupted session:
```
pth_resume_session({ pluginPath: "...", branch: "pth/my-plugin-2026-02-18-abc123" })
```

## Tools

### Session Management

| Tool | Description |
|------|-------------|
| `pth_preflight` | Check plugin path, git repo, build system, and active session lock |
| `pth_start_session` | Create session branch + worktree, detect plugin mode; optional `sessionNote` |
| `pth_resume_session` | Re-attach to an existing session branch by name |
| `pth_end_session` | Persist tests, write `SESSION-REPORT.md`, remove worktree |
| `pth_get_session_status` | Session metadata, iteration count, pass/fail totals, convergence trend |

### Test Management

| Tool | Description |
|------|-------------|
| `pth_generate_tests` | Auto-generate tests — MCP plugins: spawns the target server and calls `tools/list`; plugin mode: scans hook scripts. Optional `toolSchemas` override and `includeEdgeCases` flag. |
| `pth_list_tests` | List tests with optional filters: `mode`, `status`, `tag` |
| `pth_create_test` | Add a single test by passing a YAML string |
| `pth_edit_test` | Replace a test definition by ID |

### Execution & Results

| Tool | Description |
|------|-------------|
| `pth_record_result` | Record `passing`, `failing`, or `skipped` for a test; accepts optional `durationMs`, `failureReason`, and `claudeNotes` |
| `pth_get_results` | Pass/fail breakdown for all tests in the current suite |
| `pth_get_test_impact` | Identify tests likely affected by changes to specific source files |
| `pth_get_iteration_status` | Iteration table (passing/failing/fixes per iteration) and convergence trend |

### Fix Management

| Tool | Description |
|------|-------------|
| `pth_apply_fix` | Write file changes (`files: [{path, content}]`) and commit to session branch with PTH trailers; stages only the specified files |
| `pth_sync_to_cache` | Copy worktree files to the plugin cache so hook script changes take effect immediately |
| `pth_reload_plugin` | Build the MCP plugin (auto-detects build system), sync to cache, then terminate the server process so Claude Code restarts it; optional `processPattern` |
| `pth_get_fix_history` | List all PTH fix commits on the session branch |
| `pth_revert_fix` | Undo a specific fix commit by SHA (7–40 hex chars) via `git revert` |
| `pth_diff_session` | Cumulative diff of all session changes vs. branch point (truncated at 200 lines) |

## Modes

PTH auto-detects the target plugin type during `pth_start_session` — no `mode` parameter needed.

| Mode | When used | How PTH tests |
|------|-----------|---------------|
| `mcp` | Plugin has `.mcp.json` | Spawns the MCP server, calls `tools/list` to get schemas, generates `single` and `scenario` tests |
| `plugin` | Plugin has `.claude-plugin/` directory | Scans hook scripts and manifest to generate `validate` tests |

## Test YAML Format

Tests are YAML documents stored in the session's `.pth/tests/` directory. Fields are parsed by `src/testing/parser.ts`; the schema is defined in `src/testing/types.ts`.

**MCP single-tool test (most common):**

```yaml
id: "list-tools-returns-array"         # optional — derived from name if absent
name: "tools/list returns an array"
mode: "mcp"
type: "single"                          # inferred from presence/absence of steps
tool: "tools/list"
input: {}
expect:
  success: true
  output_contains: "tools"
tags:
  - "smoke"
timeout_seconds: 10
```

**MCP scenario test (multi-step, with variable capture):**

```yaml
name: "pth_revert_fix — valid commit hash"
mode: "mcp"
type: "scenario"
steps:
  - tool: "pth_apply_fix"
    input:
      files:
        - path: "src/stub.ts"
          content: "// stub\n"
      commitTitle: "test: stub for scenario"
    expect:
      success: true
    capture:
      commitHash: "text:Fix committed: (\\w+)"   # regex on response text
  - tool: "pth_revert_fix"
    input:
      commitHash: "${commitHash}"                # captured from step 1
    expect:
      success: true
expect:
  success: true
timeout_seconds: 30
generated_from: "schema"
```

**Plugin hook-script test:**

```yaml
name: "write-guard.sh — exists and is readable"
mode: "plugin"
type: "validate"
checks:
  - type: "file-exists"
    files: ["scripts/write-guard.sh"]
expect: {}
```

**`expect` block fields:** `success`, `output_contains`, `output_equals`, `output_matches`, `output_json`, `output_json_contains`, `error_contains`, `exit_code`, `stdout_contains`, `stdout_matches`

**`type` values:** `single` (MCP one-shot call), `scenario` (MCP multi-step), `hook-script` (run script directly), `validate` (file/schema checks), `exec` (arbitrary command)

**`setup`/`teardown`:** Array of steps that run before/after the test. Each step is `{exec: "shell command"}` or `{file: {path, content}}`.

**Multi-document files:** Test files support `---` separators — multiple tests can live in one `.yaml` file.

## Session Branches

Every session creates a dedicated git branch **and a git worktree** in the target plugin's repository. The worktree is checked out to `/tmp/pth-worktree-<branch-suffix>` and removed at `pth_end_session`. The branch remains.

```
Branch:   pth/<plugin>-<timestamp>-<hash>     e.g. pth/my-plugin-2026-02-18-abc123
Worktree: /tmp/pth-worktree-<branch-suffix>   (removed on end_session)
Lock:     <pluginPath>/.pth/active-session.lock  (PID + branch; removed on end_session)
Tests:    <worktree>/.pth/tests/*.yaml        (committed to branch on end_session)
Report:   <worktree>/.pth/SESSION-REPORT.md   (generated on end_session)
```

After a session ends, the branch is a complete record:

```bash
# See all commits from the session
git log pth/my-plugin-2026-02-18-abc123 --oneline

# Diff the entire session against the base branch
git diff $(git merge-base HEAD pth/my-plugin-2026-02-18-abc123)...pth/my-plugin-2026-02-18-abc123

# Merge a successful session to main
git checkout main && git merge --no-ff pth/my-plugin-2026-02-18-abc123
```

Abandoned sessions can be deleted without affecting your working branches:
```bash
git branch -d pth/my-plugin-2026-02-18-abc123
```

## Monorepo Support

PTH resolves the git repository root automatically — the target plugin can be a subdirectory within a larger mono-repo. File paths in `pth_apply_fix` are always relative to the **plugin directory**, not the repo root; PTH maps them to the correct worktree path internally.

## Convergence

`pth_get_iteration_status` reports the current trend and prints a per-iteration table:

```
| Iteration | Passing | Failing | Fixes |
|-----------|---------|---------|-------|
| 1         | 3       | 5       | 0     |
| 2         | 6       | 2       | 2     |
```

| Trend | Meaning | Recommended action |
|-------|---------|-------------------|
| `improving` | Pass rate rising each iteration | Keep iterating |
| `plateaued` | Pass rate has stalled | Try a different fix strategy |
| `oscillating` | Tests flip between pass and fail | Use `pth_get_test_impact` to find the regressing fix |
| `declining` | Pass rate is falling | Use `pth_revert_fix` before continuing |

Trend detection looks at the last 4 iteration snapshots; `unknown` is returned until 2+ snapshots exist.

## Requirements

- Node.js 20+
- Target plugin must be accessible on the local filesystem and inside a git repository
- For `mcp` mode: the target MCP server must be startable via its `.mcp.json` command

## Planned Features

- **Parallel test execution** — run independent tests concurrently to reduce session iteration time
- **HTML report export** — generate a self-contained HTML report from a completed session for sharing outside Claude
- **Test suite import** — seed a new session from an existing YAML test file rather than starting from zero
- **Watch mode** — automatically trigger a new iteration whenever source files in the target plugin change

## Known Issues

- **`npm install` must be run manually after plugin install** — the plugin installer does not execute `npm install`; run it in the plugin cache directory (see Installation Notes above)
- **`pth_reload_plugin` only works for MCP servers** — reloading hook-based or command-only plugins requires restarting the Claude Code session
- **Session state lives in the git worktree** — the worktree is created in `/tmp` and removed on `pth_end_session`. Tests and state are committed to the session branch at end; if the worktree is lost mid-session (e.g. system reboot), use `pth_resume_session` — it reconstructs from git history
- **`pth_apply_fix` commits immediately** — there is no staging area; use `pth_revert_fix` to undo a commit if a fix causes regressions

## Project Links

- Repository: [L3DigitalNet/Claude-Code-Plugins](https://github.com/L3DigitalNet/Claude-Code-Plugins)
- Design document: `docs/PTH-DESIGN.md`
- Issues and feedback: [GitHub Issues](https://github.com/L3DigitalNet/Claude-Code-Plugins/issues)
