# Common Node.js Runtime Patterns

## 1. nvm Setup in .bashrc / .zshrc

Add these lines to your shell profile after installing nvm:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # load nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # load completions
```

For zsh users who want automatic version switching when entering a directory with `.nvmrc`:

```bash
# Add to ~/.zshrc after the nvm init lines above
autoload -U add-zsh-hook
load-nvmrc() {
  local nvmrc_path="$(nvm_find_nvmrc)"
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chdir load-nvmrc
load-nvmrc
```

For bash users, add this to `~/.bashrc`:

```bash
cd() {
  builtin cd "$@" || return
  if [ -f .nvmrc ]; then
    nvm use
  fi
}
```

---

## 2. .nvmrc Project Pinning

Create a `.nvmrc` file at the project root to pin the Node.js version:

```bash
# Pin to major version (nvm resolves latest matching)
echo "24" > .nvmrc

# Pin to exact version
echo "24.2.0" > .nvmrc

# Pin to latest LTS
echo "lts/*" > .nvmrc

# Pin to a named LTS
echo "lts/krypton" > .nvmrc
```

Then any developer (or CI) can run:
```bash
nvm use        # reads .nvmrc and switches
nvm install    # installs the version if missing, then switches
```

Commit `.nvmrc` to version control. Add it alongside `package.json` so the Node version requirement is visible.

---

## 3. pm2 Ecosystem File

Create `ecosystem.config.js` at the project root:

```javascript
module.exports = {
  apps: [
    {
      name: "api",
      script: "./dist/server.js",
      instances: "max",
      exec_mode: "cluster",
      autorestart: true,
      watch: false,
      max_memory_restart: "500M",
      env: {
        NODE_ENV: "development",
        PORT: 3000
      },
      env_production: {
        NODE_ENV: "production",
        PORT: 8080
      }
    },
    {
      name: "worker",
      script: "./dist/worker.js",
      instances: 2,
      exec_mode: "fork",
      autorestart: true,
      cron_restart: "0 */6 * * *",
      env_production: {
        NODE_ENV: "production"
      }
    }
  ]
};
```

Usage:
```bash
pm2 start ecosystem.config.js                    # development
pm2 start ecosystem.config.js --env production   # production
pm2 start ecosystem.config.js --only api         # single app
pm2 reload ecosystem.config.js --env production  # zero-downtime reload
```

---

## 4. Deploying Node Apps with systemd

Create a unit file at `/etc/systemd/system/myapp.service`:

```ini
[Unit]
Description=My Node.js Application
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/myapp
# Point directly to the nvm-managed binary (nvm is not available in systemd)
ExecStart=/home/deploy/.nvm/versions/node/v24.2.0/bin/node dist/server.js
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=3

# Environment
Environment=NODE_ENV=production
Environment=PORT=3000

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/www/myapp/logs /var/www/myapp/uploads

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl start myapp
sudo systemctl status myapp
sudo journalctl -u myapp -f    # tail logs
```

If using nvm, use the full path to the node binary. nvm's shell function is not available in systemd contexts. Alternatively, create a symlink: `sudo ln -s /home/deploy/.nvm/versions/node/v24.2.0/bin/node /usr/local/bin/node-24`.

---

## 5. Docker Node.js Patterns

### Choosing the right base image

| Image | Size | Use case |
|-------|------|----------|
| `node:24` | ~1 GB | Full Debian with build tools; good for native module compilation |
| `node:24-slim` | ~200 MB | Minimal Debian; production default |
| `node:24-alpine` | ~60 MB | Alpine (musl libc); smallest but some native modules fail |
| `node:24-bookworm` | ~1 GB | Explicit Debian 12 base |
| `node:24-slim-bookworm` | ~200 MB | Explicit slim Debian 12; best reproducibility |

### Dockerfile with npm

```dockerfile
FROM node:24-slim-bookworm AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --only=production

FROM node:24-slim-bookworm
WORKDIR /app

ENV NODE_ENV=production
ENV PYTHONDONTWRITEBYTECODE=1

COPY --from=builder /app/node_modules ./node_modules
COPY . .

USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Dockerfile with pnpm

```dockerfile
FROM node:24-slim-bookworm AS builder
RUN corepack enable pnpm
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

FROM node:24-slim-bookworm
WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/node_modules ./node_modules
COPY . .

USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Key rules for Node.js Docker images

- Pin the Node.js version in the FROM line (e.g., `node:24.2.0-slim-bookworm`).
- Copy `package.json` and lockfile before source code for layer cache efficiency.
- Use `npm ci` (not `npm install`) in Docker; it is faster, deterministic, and deletes existing `node_modules`.
- Set `NODE_ENV=production` to skip devDependencies and enable framework optimizations.
- Run as the built-in `node` user (UID 1000), not root.
- Use `--init` flag with `docker run` (or `tini` in Dockerfile) so Node handles signals correctly as PID 1.
- Avoid alpine for projects with native addons (node-gyp, sharp, bcrypt) unless you are prepared to install build tools inside the container.
- Add a `.dockerignore` to exclude `node_modules`, `.git`, `.env`, and dev artifacts.

---

## 6. npm vs pnpm Lockfile Differences

### package-lock.json (npm)

Flat JSON structure mapping every resolved package to a version, integrity hash, and resolved URL. Supports `npm ci` for deterministic installs. Format has changed across npm versions (lockfileVersion 1, 2, 3).

```bash
# Regenerate lockfile from scratch
rm package-lock.json node_modules
npm install

# Update lockfile without changing node_modules
npm install --package-lock-only
```

### pnpm-lock.yaml (pnpm)

YAML format that reflects pnpm's content-addressable storage model. Records each dependency's integrity hash and which packages depend on it. More compact than package-lock.json for large projects.

```bash
# Regenerate lockfile
rm pnpm-lock.yaml
pnpm install

# Check if lockfile is up to date
pnpm install --frozen-lockfile   # fails if lockfile needs changes
```

### Migration between lockfiles

```bash
# npm to pnpm
rm -rf node_modules package-lock.json
pnpm import              # reads package-lock.json if present, generates pnpm-lock.yaml
pnpm install

# pnpm to npm
rm -rf node_modules pnpm-lock.yaml
npm install              # generates package-lock.json from package.json
```

Commit whichever lockfile your project uses. Never commit `node_modules`.

---

## 7. NodeSource PPA Installation (Debian/Ubuntu)

When nvm is not suitable (e.g., system-wide install for production servers):

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install -y curl gnupg

# Add NodeSource repository (Node.js 24.x LTS)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -

# Install Node.js (includes npm)
sudo apt-get install -y nodejs

# Verify
node --version
npm --version

# Optional: install build tools for native modules
sudo apt-get install -y build-essential
```

For RPM-based distros (Fedora, RHEL, CentOS):
```bash
curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo bash -
sudo dnf install -y nodejs       # Fedora
sudo yum install -y nodejs       # RHEL/CentOS
```

NodeSource packages install to `/usr/bin/node` and `/usr/bin/npm`. They replace any distro-packaged Node.js. To remove: `sudo apt-get remove nodejs` and delete `/etc/apt/sources.list.d/nodesource.list`.

---

## 8. Corepack and packageManager Field

Pin your package manager version per project so every developer and CI uses the same one:

```bash
# Enable corepack (ships with Node.js 14.19 through 24.x)
corepack enable

# Set pnpm as the project's package manager (writes to package.json)
corepack use pnpm@10.6.0

# Set yarn as the project's package manager
corepack use yarn@4.6.0
```

This adds to `package.json`:
```json
{
  "packageManager": "pnpm@10.6.0"
}
```

From this point, running `pnpm install` in the project will use exactly pnpm 10.6.0, downloaded automatically. Running `npm install` or `yarn install` will warn or fail, preventing lockfile confusion.

For Node.js 25+ (where corepack is no longer bundled):
```bash
npm install -g corepack
corepack enable
```

---

## 9. CI/CD Patterns

### GitHub Actions with npm

```yaml
- uses: actions/setup-node@v4
  with:
    node-version-file: ".nvmrc"
    cache: "npm"

- run: npm ci
- run: npm test
- run: npm run build
```

### GitHub Actions with pnpm

```yaml
- uses: pnpm/action-setup@v4
  with:
    version: 10

- uses: actions/setup-node@v4
  with:
    node-version-file: ".nvmrc"
    cache: "pnpm"

- run: pnpm install --frozen-lockfile
- run: pnpm test
- run: pnpm build
```

### Caching strategies

- **npm**: `actions/setup-node` with `cache: "npm"` caches `~/.npm` (downloaded tarballs, not `node_modules`).
- **pnpm**: `actions/setup-node` with `cache: "pnpm"` caches the pnpm store. Combine with `pnpm/action-setup` to install pnpm itself.
- **node_modules caching**: Caching `node_modules/` directly is faster but fragile across Node version changes. Key the cache on the lockfile hash.

---

## 10. Global Package Management Without sudo

### With nvm (recommended)

nvm installs Node.js under `~/.nvm/`, so global packages go to a user-writable location. No sudo needed:

```bash
npm install -g pm2 typescript eslint
```

### Without nvm (manual prefix)

```bash
mkdir -p ~/.local/lib ~/.local/bin
npm config set prefix ~/.local

# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
```

### Avoid global installs entirely

Use `npx` or `pnpm dlx` to run CLI tools without global installation:

```bash
npx create-react-app myapp       # downloads and runs, then discards
pnpm dlx degit user/repo myapp   # same idea with pnpm
```

Or use corepack for yarn/pnpm, and `npx` for everything else.

---

## 11. Default Packages for nvm

Create `~/.nvm/default-packages` to auto-install global packages whenever a new Node version is installed via nvm:

```
pm2
typescript
eslint
npm-check-updates
```

Then `nvm install 24` will install these packages automatically after installing Node.
