# Code Style and Conventions

## Plugin Structure (every plugin requires)
```
plugins/<name>/
  .claude-plugin/plugin.json   # name, version, description, author
  CHANGELOG.md                 # Keep a Changelog format
  README.md                    # from docs/plugin-readme-template.md
```

## plugin.json valid fields
`name`, `version`, `description`, `author`, `homepage`
INVALID (rejected silently on install): `category`, `keywords`, `repository`, `license`

## marketplace.json plugin entry fields
Required: `name`, `description`, `source`
Optional: `version`, `author`, `category`, `homepage`, `tags`, `strict`
INVALID: `displayName`, `keywords`, `license`

## TypeScript (plugin-test-harness)
- TypeScript 5.8, ESM modules, esbuild bundler
- Jest for tests, ESLint for linting
- Build: `npm run build` (tsc typecheck + esbuild bundle)

## Python
- pytest with markers: `-m unit`, `-m integration`, `-m gui`
- No root-level test runner — each plugin self-contained

## Hooks (hooks.json)
- `hooks` must be a record keyed by event name (not an array)
- PreToolUse blocking: exit code 2 with JSON output
- PostToolUse warnings: write to stdout

## Design Principles (P1–P6 in CLAUDE.md)
- P1: Act on Intent — execute without narration; clarify before, not after
- P2: Scope Fidelity — complete the full scope, no routine sub-task gates
- P3: Succeed Quietly, Fail Transparently
- P4: Use bounded choices (AskUserQuestion) over open-ended prompts
- P5: Convergence is the Contract — iterate to measurable criterion
- P6: Composable, Focused Units — one thing per component
