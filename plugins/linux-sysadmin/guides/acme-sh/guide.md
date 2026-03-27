# acme-sh

> **Based on:** acme-sh 3.1.2 | **Updated:** 2026-03-27

## Identity
- **Binary**: `~/.acme.sh/acme.sh` (installs per-user, not system-wide)
- **Config**: `~/.acme.sh/account.conf` (account settings, default CA)
- **Cert storage**: `~/.acme.sh/<domain>/` (private key, cert, chain, fullchain)
- **Cron**: Installed automatically on setup (`crontab -l` to verify)
- **Logs**: `~/.acme.sh/acme.sh.log`
- **Install**: `curl https://get.acme.sh | sh` or `apt install acme.sh` (some distros)
- **Supported CAs**: Let's Encrypt (default), ZeroSSL, Buypass, Google Trust Services, SSL.com

## Quick Start

```bash
curl https://get.acme.sh | sh -s email=you@example.com
source ~/.bashrc                       # reload to get acme.sh in PATH
acme.sh --issue -d example.com -w /var/www/html       # webroot mode
acme.sh --install-cert -d example.com \
  --key-file /etc/ssl/private/example.com.key \
  --fullchain-file /etc/ssl/certs/example.com.pem \
  --reloadcmd "systemctl reload nginx"
```

## Validation Methods

| Method | Flag | Use When |
|--------|------|----------|
| Webroot | `-w /var/www/html` | Web server already running |
| Standalone | `--standalone` | No web server; acme.sh runs temporary server on :80 |
| Standalone TLS | `--alpn` | TLS-ALPN-01 challenge on :443 |
| DNS manual | `--dns` | Add TXT record manually (supports wildcards) |
| DNS API | `--dns dns_cloudflare` | Automated via DNS provider API (70+ providers) |
| Apache | `--apache` | Apache is running and accessible |
| Nginx | `--nginx` | nginx is running and accessible |

## Key Operations

| Task | Command |
|------|---------|
| Issue cert (webroot) | `acme.sh --issue -d example.com -w /var/www/html` |
| Issue wildcard (DNS) | `acme.sh --issue -d '*.example.com' -d example.com --dns dns_cloudflare` |
| Issue with standalone | `acme.sh --issue -d example.com --standalone` |
| Install cert to path | `acme.sh --install-cert -d example.com --key-file /path/key --fullchain-file /path/cert --reloadcmd "systemctl reload nginx"` |
| Renew single cert | `acme.sh --renew -d example.com` |
| Renew all certs | `acme.sh --renew-all` |
| Force renewal | `acme.sh --renew -d example.com --force` |
| List issued certs | `acme.sh --list` |
| Remove cert | `acme.sh --remove -d example.com` |
| Set default CA | `acme.sh --set-default-ca --server letsencrypt` |
| Switch to ZeroSSL | `acme.sh --set-default-ca --server zerossl` |
| Revoke cert | `acme.sh --revoke -d example.com` |
| Upgrade acme.sh | `acme.sh --upgrade` |
| Enable auto-upgrade | `acme.sh --upgrade --auto-upgrade` |

## DNS API Providers (Selection)

Set credentials as environment variables before issuing:

```bash
# Cloudflare
export CF_Token="your-api-token"
export CF_Zone_ID="your-zone-id"
acme.sh --issue -d '*.example.com' --dns dns_cf

# Route53
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
acme.sh --issue -d example.com --dns dns_aws

# cPanel (your setup)
export cPanel_Username="..."
export cPanel_Apitoken="..."
acme.sh --issue -d example.com --dns dns_cpanel
```

70+ DNS providers supported. Full list: https://github.com/acmesh-official/acme.sh/wiki/dnsapi

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Verify error" | Challenge file not accessible / DNS not propagated | Check webroot path; for DNS, wait for propagation (`--dnssleep 120`) |
| Renewal fails silently | Cron not running or cron path issue | `crontab -l` to verify; ensure `~/.acme.sh` is in cron's PATH |
| "Rate limit" error | Too many cert requests to Let's Encrypt | Use `--staging` for testing; wait 1 hour for rate limit reset |
| Wildcard won't issue via webroot | Wildcards require DNS validation | Use `--dns dns_<provider>` with API credentials |
| "Install cert" does nothing | Must specify `--reloadcmd` to restart web server | Add `--reloadcmd "systemctl reload nginx"` |
| Cert path doesn't update | Using `--issue` output directly instead of `--install-cert` | Always use `--install-cert` to copy certs to final paths |

## Pain Points

- **acme.sh runs as your user, not root.** It installs to `~/.acme.sh/` and runs via the user's crontab. For system-wide use (nginx certs in `/etc/ssl/`), either run as root or use `--install-cert` with appropriate `--reloadcmd` that includes `sudo`.

- **Always use `--install-cert`, never reference `~/.acme.sh/` directly.** The cert files in `~/.acme.sh/<domain>/` are internal. Use `--install-cert` to copy them to your desired paths. This also sets up the `--reloadcmd` for automatic service reload on renewal.

- **DNS API is the most reliable method.** Webroot and standalone have edge cases (reverse proxy issues, port conflicts). DNS validation works everywhere, supports wildcards, and doesn't require port 80/443 open. Set up API credentials once.

- **`--staging` for testing.** Let's Encrypt has rate limits (50 certs/week per domain). Use `--staging` to test with the staging server, then remove it for production. This avoids hitting rate limits during setup.

- **Renewal is automatic.** acme.sh installs a daily cron job that checks all certs and renews those expiring within 30 days. You don't need to manage renewal manually.

## See Also

- **certbot** — alternative ACME client; acme.sh is lighter (pure shell, no Python dependency)
- **nginx** — common web server; acme.sh can validate via nginx or install certs for it
- **step-ca** — private CA; acme.sh can issue certs from private CAs supporting ACME

## References
See `references/` for:
- `docs.md` — official documentation links
