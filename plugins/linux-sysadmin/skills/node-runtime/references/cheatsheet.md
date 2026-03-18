# Node.js Runtime Cheatsheet

## Command Comparison: npm vs pnpm vs yarn

| Task | npm | pnpm | yarn (v4) |
|------|-----|------|-----------|
| Install all deps | `npm install` | `pnpm install` | `yarn install` |
| Add dependency | `npm install express` | `pnpm add express` | `yarn add express` |
| Add dev dependency | `npm install -D jest` | `pnpm add -D jest` | `yarn add -D jest` |
| Remove dependency | `npm uninstall express` | `pnpm remove express` | `yarn remove express` |
| Update all deps | `npm update` | `pnpm update` | `yarn up` |
| Update specific dep | `npm update express` | `pnpm update express` | `yarn up express` |
| Run script | `npm run build` | `pnpm run build` | `yarn run build` |
| Run script (short) | `npm run build` | `pnpm build` | `yarn build` |
| Execute package binary | `npx eslint .` | `pnpm dlx eslint .` | `yarn dlx eslint .` |
| Install globally | `npm install -g pm2` | `pnpm add -g pm2` | N/A (use corepack) |
| List installed | `npm list` | `pnpm list` | `yarn info --all` |
| List outdated | `npm outdated` | `pnpm outdated` | `yarn upgrade-interactive` |
| Audit vulnerabilities | `npm audit` | `pnpm audit` | `yarn npm audit` |
| Clean cache | `npm cache clean --force` | `pnpm store prune` | `yarn cache clean` |
| Init project | `npm init -y` | `pnpm init` | `yarn init` |
| Lockfile | `package-lock.json` | `pnpm-lock.yaml` | `yarn.lock` |
| Frozen install (CI) | `npm ci` | `pnpm install --frozen-lockfile` | `yarn install --immutable` |
| Workspaces | `npm workspaces` | `pnpm workspaces` | `yarn workspaces` |

## nvm Workflow

```
1. Install nvm          -> curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
2. Restart shell        -> exec "$SHELL"
3. Install Node LTS     -> nvm install --lts
4. Set default          -> nvm alias default lts/*
5. Pin per-project      -> echo "24" > .nvmrc
6. Use project version  -> cd myproject && nvm use
7. Verify               -> node --version && npm --version
```

Priority order (highest wins): `.nvmrc` in cwd (via `nvm use`) > `nvm alias default` > system Node.

## nvm Commands

| Command | Purpose |
|---------|---------|
| `nvm install --lts` | Install latest LTS |
| `nvm install 24` | Install latest v24.x |
| `nvm install 24.2.0` | Install exact version |
| `nvm use 24` | Switch active version |
| `nvm alias default 24` | Set default for new shells |
| `nvm ls` | List installed versions |
| `nvm ls-remote --lts` | List available LTS versions |
| `nvm current` | Show active version |
| `nvm which 24` | Print path to Node binary |
| `nvm run 22 app.js` | Run with specific version |
| `nvm exec 22 npm test` | Execute command with specific version |
| `nvm deactivate` | Undo nvm effects in current shell |
| `nvm uninstall 20` | Remove installed version |
| `nvm install 24 --reinstall-packages-from=22` | Migrate global packages |
| `nvm install-latest-npm` | Update npm for current Node |

## pm2 Commands

| Command | Purpose |
|---------|---------|
| `pm2 start app.js` | Start application (fork mode) |
| `pm2 start app.js --name api` | Start with a name |
| `pm2 start app.js -i max` | Start in cluster mode (all CPUs) |
| `pm2 start app.js -i 4` | Start with 4 instances |
| `pm2 start ecosystem.config.js` | Start from ecosystem file |
| `pm2 start ecosystem.config.js --env production` | Start with production env |
| `pm2 list` | List all processes |
| `pm2 show api` | Detailed info for one process |
| `pm2 monit` | Real-time monitoring dashboard |
| `pm2 logs` | Stream all logs |
| `pm2 logs api --lines 100` | Last 100 lines for one process |
| `pm2 flush` | Empty all log files |
| `pm2 stop api` | Stop process |
| `pm2 stop all` | Stop all processes |
| `pm2 restart api` | Restart process (downtime) |
| `pm2 reload api` | Zero-downtime reload (cluster mode) |
| `pm2 delete api` | Remove from process list |
| `pm2 delete all` | Remove all processes |
| `pm2 scale api +2` | Scale up by 2 workers |
| `pm2 scale api 4` | Scale to exactly 4 workers |
| `pm2 startup` | Generate OS startup script |
| `pm2 save` | Save current process list |
| `pm2 resurrect` | Restore saved process list |
| `pm2 unstartup` | Remove startup script |
| `pm2 update` | Update pm2 in-memory daemon |

## Corepack Commands

| Command | Purpose |
|---------|---------|
| `corepack enable` | Activate corepack shims (yarn, pnpm) |
| `corepack enable pnpm` | Activate only pnpm shim |
| `corepack disable` | Remove shims |
| `corepack use pnpm@latest` | Set packageManager in package.json |
| `corepack use yarn@4` | Pin yarn version |

## Key Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `NODE_ENV` | Runtime mode (development/production) | unset |
| `NODE_OPTIONS` | CLI flags applied to all Node processes | unset |
| `NODE_PATH` | Additional module search paths | unset |
| `NVM_DIR` | nvm installation directory | `~/.nvm` |
| `NPM_CONFIG_PREFIX` | npm global install location | `/usr/local` or nvm-managed |
| `NPM_CONFIG_REGISTRY` | Default registry URL | npmjs.org registry |
| `npm_config_cache` | npm cache directory | `~/.npm` |

## Useful Debugging Commands

```bash
# Which Node is active and where
node -e "console.log(process.execPath)"
node -e "console.log(process.versions)"
node -e "console.log(require('module').globalPaths)"

# Module resolution for a specific package
node -e "console.log(require.resolve('express'))"

# Show effective npm config
npm config list
npm config list -l    # all defaults included

# Inspect installed package tree
npm ls --depth=0
npm ls express        # find where express resolves

# Check for peer dependency issues
npm explain express   # show why/how express was installed
```
