# clamav

> **Based on:** clamav 1.5.2 | **Updated:** 2026-03-27

## Identity
- **Scanner**: `/usr/bin/clamscan` (on-demand), `/usr/bin/clamdscan` (via daemon)
- **Daemon**: `clamav-daemon.service` (Debian) or `clamd@scan.service` (RHEL)
- **Updater**: `clamav-freshclam.service` / `freshclam`
- **Config (daemon)**: `/etc/clamav/clamd.conf` (Debian) or `/etc/clamd.d/scan.conf` (RHEL)
- **Config (freshclam)**: `/etc/clamav/freshclam.conf`
- **Virus database**: `/var/lib/clamav/` (daily.cvd, main.cvd, bytecode.cvd)
- **Socket**: `/var/run/clamav/clamd.ctl` (Unix socket for clamdscan)
- **Logs**: `journalctl -u clamav-daemon`, `/var/log/clamav/clamav.log`, `/var/log/clamav/freshclam.log`
- **Install**: `apt install clamav clamav-daemon` / `dnf install clamav clamd clamav-update`

## Quick Start

```bash
sudo apt install clamav clamav-daemon
sudo freshclam                         # download virus definitions
sudo systemctl enable --now clamav-daemon clamav-freshclam
clamscan /path/to/scan                 # on-demand scan (no daemon needed)
clamdscan /path/to/scan                # scan via daemon (faster for repeated scans)
```

## Architecture

```
freshclam (updater)
   ↓ downloads signatures hourly
/var/lib/clamav/ (virus databases)
   ↓ loaded by
clamd (daemon — always running, signatures in memory)
   ↓ accepts scan requests via
clamdscan (client) ← fast, uses daemon
clamscan (standalone) ← loads signatures per-run, slower
```

Use `clamscan` for one-off scans. Use `clamd` + `clamdscan` for production/automated scanning.

## Key Operations

| Task | Command |
|------|---------|
| Scan a directory | `clamscan -r /home/` |
| Scan with daemon (fast) | `clamdscan /path/to/scan` |
| Scan and only show infected | `clamscan -ri /path/` |
| Scan and move infected files | `clamscan -r --move=/quarantine /path/` |
| Scan and remove infected files | `clamscan -r --remove /path/` (destructive!) |
| Update virus definitions | `sudo freshclam` |
| Check daemon status | `systemctl status clamav-daemon` |
| Check database age | `sigtool --info /var/lib/clamav/daily.cvd` |
| Show ClamAV version | `clamscan --version` |
| Scan from stdin | `cat file \| clamdscan -` |
| Reload daemon signatures | `clamdscan --reload` |
| Exclude directory | `clamscan -r --exclude-dir="^/proc" /` |
| Limit scan depth | `clamscan -r --max-dir-recursion=5 /path/` |
| Limit CPU usage | `nice -n 19 clamscan -r /path/` |

## Expected Ports
- No TCP/UDP ports by default. `clamd` uses a Unix socket.
- Optional: TCP socket on port 3310 (configure `TCPSocket 3310` in clamd.conf for network scanning)

## Health Checks

1. `systemctl is-active clamav-daemon` — daemon running
2. `systemctl is-active clamav-freshclam` — updater running
3. `clamdscan --ping` — daemon responsive (newer versions)
4. `sigtool --info /var/lib/clamav/daily.cvd | grep "Build time"` — database recently updated

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Can't connect to clamd" | Daemon not running or socket path wrong | `systemctl start clamav-daemon`; check socket path in config |
| `freshclam` fails with "connection refused" | CDN mirror issues or rate limited | Wait and retry; check proxy settings in `freshclam.conf` |
| Daemon uses excessive memory | All signatures loaded in RAM (~1-1.5 GB) | Normal for `clamd`; use `clamscan` on memory-constrained systems |
| Database "outdated" warning | `freshclam` not running or failing | `systemctl enable --now clamav-freshclam`; check `/var/log/clamav/freshclam.log` |
| Scan takes forever | Scanning large/compressed archives or `/proc` | Use `--exclude-dir`, `--max-filesize`, `--max-scansize`; don't scan `/proc`, `/sys`, `/dev` |
| Permission denied on files | ClamAV runs as `clamav` user | Ensure `clamav` user can read target files; or run `clamscan` as root |
| False positive | Heuristic match on legitimate file | Report to ClamAV (https://www.clamav.net/reports/fp); whitelist with `--exclude` |

## Pain Points

- **`clamd` uses ~1-1.5 GB of RAM.** The daemon loads all virus signatures into memory for fast scanning. This is the intended trade-off: fast scans at the cost of memory. On memory-constrained systems, use `clamscan` (standalone) instead — it loads signatures per-run and exits.

- **`freshclam` rate limiting.** ClamAV's CDN limits database download frequency. If `freshclam` fails repeatedly, it's likely rate-limited. The default check interval (12 times per day) is usually fine. Don't run `freshclam` more frequently.

- **ClamAV is a scanner, not real-time protection.** Unlike Windows AV, ClamAV doesn't monitor file access in real time by default. It scans files on demand. For on-access scanning, enable `clamd`'s on-access feature (Linux kernel fanotify), but this has significant performance impact.

- **Mail server integration is the primary use case.** ClamAV was designed for mail servers. Integrate with Postfix via `clamav-milter` or Amavis. For file servers, schedule nightly scans via cron.

- **Exclude system pseudo-filesystems.** Always exclude `/proc`, `/sys`, `/dev`, `/run` from scans. They contain virtual files that waste time and can cause errors.

- **Cron-based scanning.** For production file scanning, create a cron job: `0 2 * * * clamscan -ri /srv --log=/var/log/clamav/scan.log --exclude-dir="^/proc"`. Send reports via email or monitoring.

## See Also

- **rkhunter** — rootkit detection; complements ClamAV's malware scanning
- **lynis** — security auditing; checks whether ClamAV is installed and running
- **aide** — file integrity monitoring; detects unauthorized changes, not malware signatures
- **postfix** — mail server; ClamAV integrates via milter for email scanning

## References
See `references/` for:
- `docs.md` — official documentation links
