# Suggested Commands

## Validation (always run before merging to main)
```bash
./scripts/validate-marketplace.sh
```

## TypeScript plugin (plugin-test-harness)
```bash
cd plugins/plugin-test-harness
npm ci && npm run build   # install + build
npm test                   # run all tests
npm run test:unit          # unit tests only
npm run lint               # eslint
npm run typecheck          # tsc type check
```

## Python plugins (home-assistant-dev, keepass-cred-mgr)
```bash
pytest plugins/home-assistant-dev/tests/scripts/ -m unit
pytest plugins/home-assistant-dev/tests/scripts/ -m integration
```

## Run Claude Code with a specific plugin
```bash
claude --plugin-dir ./plugins/plugin-name
```

## Deploy to main
```bash
git checkout main && git merge testing --no-ff -m "Deploy: <description>" && git push origin main && git checkout testing
```

## Git workflow
- All development on `testing` branch
- Commit WIP before spawning subagents
- Never push directly to `main`
