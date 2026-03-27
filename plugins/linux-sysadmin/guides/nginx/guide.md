# nginx

> **Based on:** nginx 1.28.3 | **Updated:** 2026-03-27

## Identity
- **Unit**: `nginx.service`
- **Config**: `/etc/nginx/nginx.conf`, `/etc/nginx/sites-enabled/`, `/etc/nginx/conf.d/`
- **Logs**: `journalctl -u nginx`, `/var/log/nginx/access.log`, `/var/log/nginx/error.log`
- **User**: `www-data` (Debian/Ubuntu), `nginx` (RHEL/Fedora)
- **Distro install**: `apt install nginx` / `dnf install nginx`

## Quick Start
```bash
sudo apt install nginx
sudo systemctl enable --now nginx
nginx -t                       # syntax is ok, test is successful
curl -sI http://localhost      # HTTP 200 = running
```

## Key Operations
- **Validate config**: `nginx -t`
- **Full config dump**: `nginx -T` (merged, useful for debugging includes)
- **Reload (no downtime)**: `sudo systemctl reload nginx`
- **Restart**: `sudo systemctl restart nginx`
- **Test specific config**: `nginx -t -c /path/to/test.conf`

## Expected Ports
- 80/tcp (HTTP), 443/tcp (HTTPS)
- Verify: `ss -tlnp | grep nginx`
- Firewall: `sudo ufw allow 'Nginx Full'` or `sudo ufw allow 80,443/tcp`

## Health Checks
1. `systemctl is-active nginx` → `active`
2. `nginx -t 2>&1` → contains `syntax is ok` and `test is successful`
3. `curl -sI http://localhost` → HTTP response (not connection refused)
4. `ss -tlnp | grep ':80\|:443'` → nginx listed

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `bind() to 0.0.0.0:80 failed` | Port already in use | `ss -tlnp \| grep :80` — find conflicting process |
| `502 Bad Gateway` | Upstream service down or wrong address | Check upstream (`systemctl status <app>`), verify `proxy_pass` URL |
| `504 Gateway Timeout` | Upstream too slow | Increase `proxy_read_timeout`; check upstream performance |
| Config test passes but reload fails | Syntax error in included file | `nginx -T 2>&1 \| grep -A3 error` |
| `Permission denied` on socket | Wrong socket path or permissions | Check `proxy_pass unix:/run/app.sock` path and ownership |
| SSL: `unknown protocol` | HTTP client hitting HTTPS port | Redirect port 80 → 443 or check client |
| `too many open files` | `worker_rlimit_nofile` too low | Raise in nginx.conf and system `ulimit` |
| 413 Request Entity Too Large | `client_max_body_size` too small | Increase to match expected upload size |

## Pain Points
- **Trailing slash in `proxy_pass`**: `proxy_pass http://backend/` strips the location prefix; `proxy_pass http://backend` does not. Deliberately different behavior.
- **Sites-enabled symlinks**: Broken symlinks are silently ignored — nginx won't warn you.
- **`worker_connections` x `worker_processes`**: This is the real max client limit, not either alone.
- **`default_server` matters**: Without it, the first defined vhost catches unmatched requests.
- **`server_name` regex ordering**: `~` (regex) checked before literal matches.
- **Upstream keepalive**: Set `keepalive` in the upstream block AND `proxy_http_version 1.1` + `proxy_set_header Connection ""` in the location block — both required.
- **`try_files` final arg is a fallback URI, not a file**: `try_files $uri $uri/ =404` — the `=404` is a named response code fallback, not a file path.

## See Also
- **apache** — traditional web server with .htaccess support and extensive module ecosystem
- **caddy** — modern web server with automatic HTTPS and zero-config TLS
- **traefik** — container-native reverse proxy with Docker label auto-discovery
- **haproxy** — dedicated TCP/HTTP load balancer for high-throughput multi-backend routing
- **certbot** — free TLS certificates from Let's Encrypt for nginx and Apache
- **keycloak** — identity provider; nginx proxies Keycloak and enforces its auth decisions
- **kong** — API gateway built on nginx with plugin-based extensibility
- **envoy** — advanced proxy with circuit breaking and service mesh integration

## References
See `references/` for:
- `nginx.conf.annotated` — full default config with every directive explained
- `common-patterns.md` — reverse proxy, virtual hosts, SSL, load balancing, and static file examples
- `docs.md` — official documentation links
