# CLAUDE.md

**Session startup:** Agent Handoff injects state through the shared repo-local SessionStart hook.

**Branch workflow:** Direct commit to `main`. No `testing` branch. Plugin releases are manual — bump `plugins/<name>/.claude-plugin/plugin.json` and its matching `.claude-plugin/marketplace.json` entry, then commit, tag `<name>/vX.Y.Z`, push, and `gh release create`. See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for full rules.

**Document layout (read on demand):**

- `docs/handoff/state.md` — live state + active incidents (auto-injected, do not read directly)
- `docs/handoff/deployed.md` — deployment truth + what-remains
- `docs/handoff/architecture.md` — repo structure + plugin design principles + full CLAUDE.md detail
- `docs/handoff/credentials.md` — credential surfaces
- `docs/handoff/conventions.md` — pattern library (Phase 5 deferred)
- `docs/handoff/sessions/` — monthly session logs (grep by date)
- `docs/handoff/bugs/` — per-file bug KB (grep by service or tag)
- `docs/handoff/specs-plans.md` — pointer into `docs/plans/`
- per-plugin tests: `plugins/<plugin>/tests/` (frameworks by language per `docs/handoff/conventions.md` TEST-001)

<!-- prettier-ignore-start -->

<!-- BEGIN project-standards:agent-handoff -->
<!-- markdownlint-disable MD025 -->
# Agent Handoff

Use the repo-local `agent-handoff` skill at session startup and closeout. Do not reread state already injected by SessionStart. Keep project knowledge inside this repository and store credential references only, never values.
<!-- markdownlint-enable MD025 -->
<!-- END project-standards:agent-handoff -->

<!-- prettier-ignore-end -->

<!-- prettier-ignore-start -->

<!-- BEGIN project-standards:markdown-tooling -->
<!-- markdownlint-disable MD025 -->
# Markdown and structured-text tooling

Prettier owns physical formatting and markdownlint owns Markdown structure. Do not add overlapping tools.

Enabled checks: format, lint.
Markdown scope: `**/*.md`.
Structured-config scope: `**/*.json`, `**/*.jsonc`, `**/*.yml`, `**/*.yaml`.
Lint additionally skips generated directories: `.pytest_cache/**`, `.ruff_cache/**`, `.venv/**`, `node_modules/**`.

Check formatting over exactly that scope, with Git as the corpus authority:

```bash
git ls-files -z -- ':(glob)**/*.md' ':(glob)**/*.json' ':(glob)**/*.jsonc' ':(glob)**/*.yml' ':(glob)**/*.yaml' | xargs -0 -r npx prettier --check --
```

Without Git, bound the same scope by glob instead:

```bash
npx prettier --check --no-error-on-unmatched-pattern -- '**/*.md' '**/*.json' '**/*.jsonc' '**/*.yml' '**/*.yaml'
```

Never check or write with a bare `.`: it reaches undeclared languages and Git-excluded scratch.

Lint Markdown structure over the same Git-tracked scope:

```bash
git ls-files -z -- ':(glob)**/*.md' ':(glob,exclude).pytest_cache/**' ':(glob,exclude).ruff_cache/**' ':(glob,exclude).venv/**' ':(glob,exclude)node_modules/**' | sed -z 's|^|:|' | xargs -0 -r npx markdownlint-cli2 --no-globs
```

Never lint a bare recursive glob: it descends into any independent Git repository checked out below this one.

Run the enabled checks before claiming completion.
<!-- markdownlint-enable MD025 -->
<!-- END project-standards:markdown-tooling -->

<!-- prettier-ignore-end -->
