# uptime-kuma

> **Based on:** uptime-kuma 2.2.1 | **Updated:** 2026-03-27

## Identity
- **Runtime**: Node.js application (v18+ required)
- **Container image**: `louislam/uptime-kuma:1` (Docker Hub), `ghcr.io/louislam/uptime-kuma:1` (GHCR)
- **Config/data**: SQLite database in data volume (`/app/data/kuma.db`)
- **Default port**: 3001/tcp (HTTP dashboard and API)
- **No config file**: All configuration is via the web UI; state lives in the SQLite database
- **Logs**: Container stdout/stderr, or `journalctl -u uptime-kuma` if using systemd
- **Install**: Docker (recommended), or `npm` directly

## Quick Start

```bash
# Docker (simplest)
docker run -d \
  --name uptime-kuma \
  --restart unless-stopped \
  -p 3001:3001 \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1

# Docker Compose
# services:
#   uptime-kuma:
#     image: louislam/uptime-kuma:1
#     restart: unless-stopped
#     ports:
#       - "3001:3001"
#     volumes:
#       - ./data:/app/data

# Node.js (manual)
git clone https://github.com/louislam/uptime-kuma.git
cd uptime-kuma
npm run setup
node server/server.js --port=3001
```

## Monitor Types

Uptime Kuma supports many check types:

| Type | What It Checks |
|------|----------------|
| HTTP(S) | URL status code, response time, keyword/JSON match |
| TCP | Port reachable |
| Ping | ICMP echo |
| DNS | Record resolution against expected value |
| Docker | Container status via Docker socket |
| Steam | Game server query |
| MQTT | Broker connectivity |
| gRPC | gRPC health check |
| Radius | RADIUS auth test |
| MongoDB | Connection string test |
| MySQL/MariaDB | Connection and query |
| PostgreSQL | Connection and query |
| Redis | Connection test |
| Push | Passive: expects heartbeat POST from the monitored service |

## Key Operations

| Task | How |
|------|-----|
| Add a monitor | Web UI → "Add New Monitor" |
| Status page (public) | Web UI → "Status Pages" → create/edit |
| Reset admin password | `docker exec -it uptime-kuma npm run reset-password` |
| Backup database | Copy `/app/data/kuma.db` (stop container first for consistency) |
| Restore from backup | Replace `kuma.db` in the data volume and restart |
| Export/import monitors | Settings → Backup → Export/Import JSON |
| API access | Settings → API Keys → create key; use `/api/` endpoints |
| Prometheus metrics | Settings → enable; scrape at `/metrics` with API key |
| Maintenance windows | Web UI → "Maintenance" → schedule downtime |
| Bulk actions | Select multiple monitors → Actions dropdown |

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `UPTIME_KUMA_PORT` | `3001` | Listening port |
| `UPTIME_KUMA_HOST` | `0.0.0.0` | Bind address |
| `DATA_DIR` | `/app/data` | Data directory path |
| `NODE_EXTRA_CA_CERTS` | — | Custom CA certificate path |
| `UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN` | — | Allow embedding in iframes |

## Expected Ports
- **3001/tcp** — Web UI, API, and Prometheus metrics endpoint
- Verify: `ss -tlnp | grep 3001` or `docker port uptime-kuma`

## Health Checks

1. `curl -sf http://localhost:3001/` — dashboard loads
2. `docker inspect --format='{{.State.Health.Status}}' uptime-kuma` — container health (if using `--health-cmd`)
3. Check "Heartbeat" section in UI — all monitors show recent checks

## Notification Providers

Uptime Kuma supports 90+ notification methods, including:
Telegram, Discord, Slack, Email (SMTP), Gotify, Ntfy, Pushover, Webhook, Microsoft Teams, Matrix, PagerDuty, Opsgenie, Signal, Apprise, and many more.

Configure in Settings → Notifications. Each monitor can use different notification channels.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Dashboard unreachable | Port not mapped or firewall blocking | Check `docker port uptime-kuma`; check firewall rules |
| "Database is locked" errors | Concurrent writes to SQLite | Ensure only one instance runs; avoid NFS/CIFS for data volume |
| Monitor shows DOWN but service is UP | DNS resolution failure inside container, or custom cert not trusted | Check container DNS; add `NODE_EXTRA_CA_CERTS` for self-signed certs |
| Forgot admin password | No password recovery in UI | `docker exec -it uptime-kuma npm run reset-password` |
| Notifications not sending | Notification provider misconfigured | Test via "Test" button in notification settings; check container logs |
| High memory usage over time | Many monitors with short intervals and long retention | Increase check intervals; reduce history retention in Settings |
| Container won't start after update | Breaking schema migration or corrupted DB | Check container logs; restore from backup; try `npm run setup` |

## Pain Points

- **SQLite is the only database backend.** There is no option for PostgreSQL or MySQL. This means the data volume must be on a local filesystem with proper locking. NFS, CIFS, and some FUSE filesystems cause "database is locked" errors. Use bind mounts or Docker volumes on local storage.

- **No config-as-code.** All monitors, notifications, and status pages are configured through the web UI and stored in the SQLite database. There's no YAML/JSON config file to version control. Use the built-in Export/Import for backup, or the API for automation.

- **Single-instance only.** Uptime Kuma does not support clustering or HA. For redundancy, run independent instances and monitor each other. The Push monitor type lets you build basic distributed checking.

- **Reverse proxy needs WebSocket support.** The dashboard uses WebSockets for real-time updates. nginx, Caddy, and Traefik all work but must be configured to proxy WebSocket connections (`Upgrade` and `Connection` headers).

- **Docker socket monitoring is powerful but risky.** Mounting `/var/run/docker.sock` lets Uptime Kuma monitor container status directly. This grants significant host access. Use a Docker socket proxy (like Tecnativa's) for hardened setups.

- **v1 to v2 migration**: v2 introduced breaking changes. Follow the migration guide before upgrading. Back up `kuma.db` first.

## See Also

- **netdata** — real-time system and application metrics; Uptime Kuma is simpler but focused purely on uptime/availability
- **prometheus** — metrics collection with Alertmanager; Uptime Kuma can expose metrics to Prometheus via its `/metrics` endpoint
- **gotify** — push notification server; can receive alerts from Uptime Kuma

## References
See `references/` for:
- `docs.md` — official documentation links
