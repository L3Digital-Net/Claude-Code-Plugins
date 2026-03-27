# authentik

> **Based on:** authentik 2026.2.1 | **Updated:** 2026-03-27

## Identity
- **Components**: Server (web + API), Worker (background tasks), PostgreSQL, Redis
- **Container images**: `ghcr.io/goauthentik/server`, `ghcr.io/goauthentik/proxy`, `ghcr.io/goauthentik/ldap`
- **Config**: Environment variables in `.env` file (no config file inside the container)
- **Data**: PostgreSQL database (all config, users, flows, policies)
- **Media**: `/media/` volume (icons, custom assets)
- **Blueprints**: `/blueprints/` volume (declarative config-as-code)
- **Default ports**: 9000/tcp (HTTP), 9443/tcp (HTTPS)
- **Logs**: Container stdout/stderr (`docker compose logs authentik-server`)
- **Install**: Docker Compose (primary), Kubernetes via Helm

## Quick Start

```bash
wget https://docs.goauthentik.io/compose.yml
echo "PG_PASS=$(openssl rand -base64 36 | tr -d '\n')" >> .env
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')" >> .env
docker compose pull
docker compose up -d
# Navigate to http://<host>:9000/if/flow/initial-setup/
```

## Architecture

```
Browser
   ↓
Reverse Proxy (nginx, Traefik, Caddy)
   ↓
authentik Server (:9000/:9443)
   ├── Web UI (flows, admin, user dashboard)
   ├── API (REST + WebSocket for outposts)
   └── Protocol endpoints (OAuth2, SAML, LDAP, SCIM, RADIUS)
   ↓
authentik Worker
   └── Background tasks (email, backups, outpost management)
   ↓
PostgreSQL (state) + Redis (cache, sessions, task queue)

Outposts (optional, deployed separately):
   ├── Proxy Outpost — forward auth / reverse proxy
   ├── LDAP Outpost — LDAP interface for legacy apps
   └── RADIUS Outpost — RADIUS interface
```

## Key Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `AUTHENTIK_SECRET_KEY` | Yes | Encryption key for tokens and sessions |
| `PG_PASS` | Yes | PostgreSQL password (max 99 chars) |
| `PG_HOST` | No | PostgreSQL host (default: `postgresql`) |
| `PG_USER` | No | PostgreSQL user (default: `authentik`) |
| `PG_DB` | No | PostgreSQL database (default: `authentik`) |
| `AUTHENTIK_REDIS__HOST` | No | Redis host (default: `redis`) |
| `AUTHENTIK_ERROR_REPORTING__ENABLED` | No | Send error reports to authentik devs |
| `AUTHENTIK_EMAIL__HOST` | No | SMTP server for notifications |
| `AUTHENTIK_EMAIL__PORT` | No | SMTP port |
| `AUTHENTIK_EMAIL__USERNAME` | No | SMTP username |
| `AUTHENTIK_EMAIL__PASSWORD` | No | SMTP password |
| `AUTHENTIK_EMAIL__USE_TLS` | No | Enable STARTTLS |
| `AUTHENTIK_EMAIL__FROM` | No | From address for outgoing mail |
| `COMPOSE_PORT_HTTP` | No | Override exposed HTTP port (default: 9000) |
| `COMPOSE_PORT_HTTPS` | No | Override exposed HTTPS port (default: 9443) |

## Key Operations

| Task | How |
|------|-----|
| Initial setup | Navigate to `http://<host>:9000/if/flow/initial-setup/` |
| Admin dashboard | `http://<host>:9000/if/admin/` |
| User dashboard | `http://<host>:9000/if/user/` |
| Create recovery key | `docker compose run --rm server ak create_recovery_key 10 akadmin` |
| Run migrations | `docker compose run --rm server ak migrate` |
| Check server version | `docker compose exec server ak version` |
| View logs | `docker compose logs -f server worker` |
| Restart outposts | Admin → Outposts → select → "Restart" |
| Export config as blueprint | Admin → Blueprints → Export |
| Import blueprint | Place YAML in `/blueprints/custom/` and restart |
| Backup | Back up PostgreSQL + `.env` + media volume |

## Supported Protocols

| Protocol | Use Case |
|----------|----------|
| OAuth2 / OpenID Connect | Modern web apps, SPAs, APIs |
| SAML 2.0 | Enterprise SSO, legacy apps |
| LDAP (via outpost) | Legacy apps requiring LDAP bind |
| RADIUS (via outpost) | Network equipment, VPN authentication |
| SCIM | User/group provisioning to downstream apps |
| Proxy (via outpost) | Forward auth for apps without native SSO |

## Expected Ports

- **9000/tcp** — HTTP (server)
- **9443/tcp** — HTTPS (server)
- **9300/tcp** — Proxy outpost HTTP (if deployed)
- **9443/tcp** — Proxy outpost HTTPS (if deployed)
- **3389/tcp** — LDAP outpost (if deployed)
- **6636/tcp** — LDAPS outpost (if deployed)
- **1812/udp** — RADIUS outpost (if deployed)

## Health Checks

1. `curl -sf http://localhost:9000/-/health/live/` — server alive
2. `curl -sf http://localhost:9000/-/health/ready/` — server ready (DB + Redis connected)
3. `docker compose ps` — all containers running and healthy
4. Admin dashboard → System → System Tasks — background tasks completing

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Initial setup page won't load | Server not ready; PostgreSQL migrations incomplete | Wait for migrations; `docker compose logs server` to check progress |
| "Internal Server Error" on login | `AUTHENTIK_SECRET_KEY` changed or missing | Ensure `.env` is consistent; secret key must never change after first run |
| Outpost won't connect | WebSocket blocked by reverse proxy or firewall | Reverse proxy must pass `Upgrade`/`Connection` headers for WebSocket |
| OAuth/SAML fails with time errors | Container time drifted from UTC | Never mount `/etc/timezone` or `/etc/localtime` into authentik containers; it uses UTC internally |
| Worker container restarting | PostgreSQL connection refused or Redis unreachable | Check PostgreSQL and Redis containers; verify `PG_PASS` matches |
| LDAP outpost returns no users | Bind group or search base misconfigured | Admin → Providers → LDAP → verify search base and bind DN group membership |
| Email notifications not sending | SMTP env vars not set or incorrect | Set `AUTHENTIK_EMAIL__*` variables and restart; test from Admin → System → Outgoing Email |
| Recovery key doesn't work | Expired (duration passed) or wrong username | Generate a new one: `docker compose run --rm server ak create_recovery_key 10 <username>` |

## Pain Points

- **Never change `AUTHENTIK_SECRET_KEY` after initial setup.** It encrypts tokens and session data. Changing it invalidates all existing sessions, tokens, and potentially stored credentials. Treat it like a database encryption key.

- **Never mount host timezone into containers.** Authentik uses UTC internally. Mounting `/etc/timezone` or `/etc/localtime` causes OAuth token validation failures and SAML assertion timing issues. This is the single most common deployment mistake.

- **Docker socket mount for outpost management.** The default compose file mounts `/var/run/docker.sock` into the worker for automatic outpost deployment. For hardened environments, use a Docker socket proxy or deploy outposts manually.

- **PostgreSQL password length limit.** `PG_PASS` must be 99 characters or fewer due to PostgreSQL limitations. The `openssl rand -base64 36` command in the docs produces an appropriate length.

- **Reverse proxy must support WebSocket and HTTP/1.1+.** Authentik uses WebSockets for outpost communication. HTTP/1.0 proxies, or proxies without WebSocket upgrade support, will break outpost connectivity. Configure `proxy_set_header Upgrade $http_upgrade;` in nginx.

- **Blueprints for config-as-code.** Place YAML files in `/blueprints/custom/` for declarative flow, policy, and provider configuration. Blueprints are applied on startup and can be used for GitOps-style management. They are the answer to "how do I version-control my authentik config."

- **Minimum resources**: 2 CPU cores, 2 GB RAM. Under-provisioned instances cause worker timeouts and sluggish flows.

## See Also

- **keycloak** — alternative open-source IdP with Java stack; more mature enterprise features but heavier resource usage
- **nginx** — common reverse proxy in front of authentik; needs WebSocket config for outpost communication
- **certbot** — TLS certificates for authentik's external-facing endpoints
- **postgresql** — authentik's database backend; back it up regularly

## References
See `references/` for:
- `docs.md` — official documentation links
