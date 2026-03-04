# What to Do When a Task is Completed

## Before merging to main
1. Bump version in `plugins/<name>/.claude-plugin/plugin.json`
2. Update matching version in `.claude-plugin/marketplace.json`
3. Update `CHANGELOG.md`
4. Run `./scripts/validate-marketplace.sh`

## For TypeScript plugins
- Run `npm ci && npm run build && npm test` in the plugin directory
- Run `npm run typecheck` and `npm run lint`

## For Python plugins
- Run `pytest` with appropriate markers

## Git
- Commit to `testing` branch
- Deploy to main: `git checkout main && git merge testing --no-ff -m "Deploy: <description>" && git push origin main && git checkout testing`

## Gotchas to check
- `((var++))` with `set -e` exits when var=0 — use `var=$((var + 1))`
- Marketplace cache is a git clone — edit requires git fetch + reset to update
- MCP servers need restart after binary/cache updates
- `installed_plugins.json` is the load source of truth, not just `settings.json`
