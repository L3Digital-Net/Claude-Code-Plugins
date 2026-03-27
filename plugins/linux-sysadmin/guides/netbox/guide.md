# netbox

> **Based on:** netbox 4.5.5 | **Updated:** 2026-03-27

## Identity
- **Application**: Django web application (Python)
- **Container image**: `netboxcommunity/netbox` (Docker Hub), `lscr.io/linuxserver/netbox`
- **Config**: `/opt/netbox/netbox/netbox/configuration.py` (bare metal) or environment variables (Docker)
- **Dependencies**: PostgreSQL, Redis
- **Default port**: 8000/tcp (gunicorn/WSGI) — typically behind nginx on 80/443
- **Data**: PostgreSQL database, `/opt/netbox/netbox/media/` (uploaded files)
- **Logs**: gunicorn/Django logs, `journalctl -u netbox` (if systemd-managed)
- **Install**: Docker Compose (recommended) or manual deployment with Python venv

## Quick Start

```bash
# Docker Compose (recommended)
git clone -b release https://github.com/netbox-community/netbox-docker.git
cd netbox-docker
tee docker-compose.override.yml <<EOF
services:
  netbox:
    ports:
      - "8000:8080"
EOF
docker compose pull
docker compose up -d
# Default login: admin / admin — change immediately
```

## What It Does

NetBox is an IP address management (IPAM) and datacenter infrastructure management (DCIM) tool. It tracks:

| Domain | What It Models |
|--------|----------------|
| **DCIM** | Sites, racks, devices, cables, power |
| **IPAM** | IP addresses, prefixes, VRFs, VLANs, ASNs |
| **Circuits** | Providers, circuit types, terminations |
| **Virtualization** | Clusters, virtual machines, VM interfaces |
| **Tenancy** | Tenants, tenant groups (multi-tenancy) |
| **Contacts** | Contact groups, contact assignments |
| **Wireless** | Wireless LANs, links |

NetBox is the "source of truth" — it documents what your infrastructure *should* look like. Automation tools (Ansible, Terraform) read from NetBox to configure what it *actually* looks like.

## Key Operations

| Task | How |
|------|-----|
| Access web UI | `http://<host>:8000` |
| API access | `http://<host>:8000/api/` (REST API with Swagger docs) |
| Create API token | Admin → API Tokens → Add |
| GraphQL | `http://<host>:8000/graphql/` |
| Django admin | `http://<host>:8000/admin/` |
| Create superuser (bare metal) | `python3 manage.py createsuperuser` |
| Create superuser (Docker) | `docker compose exec netbox python manage.py createsuperuser` |
| Run migrations | `python3 manage.py migrate` |
| Collect static files | `python3 manage.py collectstatic` |
| Custom scripts | Upload via web UI → Customization → Scripts |
| Webhooks | Web UI → Integrations → Webhooks |

## Expected Ports
- **8000/tcp** (or 8080 in Docker) — application server (gunicorn/WSGI)
- Put behind a reverse proxy (nginx, Caddy) for TLS and production use.

## Health Checks

1. `curl -sf http://localhost:8000/api/status/` — returns JSON with NetBox version and status
2. `docker compose ps` — all containers running (Docker deploy)
3. Check PostgreSQL and Redis connectivity from NetBox logs

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Database connection refused" | PostgreSQL not running or wrong credentials | Check `DATABASES` config; verify PostgreSQL is up |
| "Redis connection error" | Redis not running | Start Redis; check `REDIS` config |
| Static files not loading (unstyled) | `collectstatic` not run or nginx not serving static | Run `collectstatic`; configure nginx to serve `/static/` |
| "CSRF verification failed" | `ALLOWED_HOSTS` doesn't include the access hostname | Add hostname/IP to `ALLOWED_HOSTS` in config |
| API returns 403 | Missing or invalid API token | Create token in web UI; include as `Authorization: Token <token>` header |
| Slow with large datasets | Missing database indexes or unoptimized queries | Upgrade NetBox (performance improvements in each release); check PostgreSQL config |

## Pain Points

- **NetBox is documentation, not configuration management.** It doesn't push changes to devices. It's the source of truth that other tools read from. Ansible, Terraform, and custom scripts consume the NetBox API.

- **Plugins extend functionality.** NetBox has a plugin system for adding custom models, views, and API endpoints. Popular plugins add BGP, DNS, access lists, and more. Install via pip into the NetBox venv.

- **PostgreSQL and Redis are required.** No SQLite option. The Docker Compose setup includes both. For bare metal, install and configure them separately.

- **Keep it behind a reverse proxy.** Gunicorn should not face the internet directly. Use nginx or Caddy for TLS termination, static file serving, and security headers.

- **Regular backups.** Back up PostgreSQL (`pg_dump`) and the media directory. The database contains all your infrastructure documentation.

## See Also

- **postgresql** — required database backend for NetBox
- **redis** — required cache/queue backend for NetBox
- **nginx** — recommended reverse proxy for production NetBox
- **ansible** — can use NetBox as dynamic inventory source

## References
See `references/` for:
- `docs.md` — official documentation links
