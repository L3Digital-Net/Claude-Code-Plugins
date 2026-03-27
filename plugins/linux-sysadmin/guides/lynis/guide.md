# lynis

> **Based on:** lynis 3.1.4 | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/bin/lynis` (package install) or `./lynis` (tarball)
- **Config**: `/etc/lynis/default.prf` (default profile)
- **Custom profiles**: `/etc/lynis/custom.prf` or specified with `--profile`
- **Log**: `/var/log/lynis.log` (detailed scan log — purged each run)
- **Report**: `/var/log/lynis-report.dat` (machine-readable key=value pairs)
- **Test database**: `/usr/share/lynis/include/` (test scripts) and `/usr/share/lynis/db/` (data files)
- **Plugins dir**: `/usr/share/lynis/plugins/`
- **Install**: `apt install lynis` / from CISOfy repository / tarball from https://cisofy.com/lynis/

## Quick Start

```bash
sudo apt install lynis
sudo lynis audit system                # full system audit
sudo lynis show details BOOT-5122      # explain a specific test
sudo lynis show profiles               # list available profiles
```

## Key Operations

| Task | Command |
|------|---------|
| Full system audit | `sudo lynis audit system` |
| Quick audit (no pauses) | `sudo lynis audit system -Q` |
| Cron-friendly audit | `sudo lynis audit system --cronjob` |
| Named audit | `sudo lynis audit system --auditor "Chris"` |
| Show all options | `lynis show options` |
| Show specific test details | `lynis show details <TEST-ID>` |
| Show host identifiers | `lynis show hostids` |
| Check for Lynis updates | `lynis update info` |
| List test categories | `lynis show categories` |
| List all tests | `lynis show tests` |
| Run specific test group only | `sudo lynis audit system --tests-from-group "firewalls"` |
| Skip specific tests | `sudo lynis audit system --skip-test KRNL-5820` |
| Pentest mode (non-root) | `lynis audit system --pentest` |
| Remote audit (Lynis on target) | `lynis audit system remote <host>` |

## Scan Categories

Lynis tests span 30+ categories. Key groups:

| Category | Covers |
|----------|--------|
| `boot_services` | GRUB passwords, systemd, startup scripts |
| `kernel` | Core dumps, sysctl hardening, PAE/NX |
| `authentication` | PAM, password policies, account consistency |
| `file_systems` | Partition separation, mount options, sticky bits |
| `file_integrity` | AIDE/OSSEC/Samhain presence and config |
| `firewalls` | iptables/nftables rules, pf config |
| `ssh` | sshd_config hardening, root login, protocol version |
| `networking` | Nameservers, promiscuous mode, WAIT connections |
| `webservers` | nginx/Apache SSL, mod_security, logging |
| `databases` | MySQL/PostgreSQL/MongoDB/Redis auth and binding |
| `logging` | syslog, journald, remote logging, log rotation |
| `crypto` | Certificate expiry, TLS settings |
| `containers` | Docker daemon security, unused containers |
| `hardening` | Compiler restrictions, malware scanners |

## Health Checks

1. `lynis --version` — installed and runnable
2. `sudo lynis audit system -Q 2>&1 | tail -20` — scan completes, shows hardening index
3. Check `/var/log/lynis.log` exists and was recently updated
4. Check `/var/log/lynis-report.dat` for `hardening_index=` line

## Hardening Index

Lynis produces a score from 0-100 after each scan. This is a rough indicator, not a compliance certification. The score improves as you address suggestions and warnings. Typical starting scores:

- Fresh Debian/Ubuntu: 55-65
- Hardened server: 75-85
- Fully tuned: 85-95+ (diminishing returns above 90)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Score is 0 or very low | Running as non-root skips most tests | Run with `sudo`; non-root only gets pentest-level checks |
| "Outdated version" warning | Package repo has older Lynis | Add CISOfy repo or use tarball for latest |
| Tests hang or pause | Interactive mode waiting for keypress | Use `-Q` or `--cronjob` for non-interactive |
| False positives on containers | Lynis expects full OS, not minimal container | Skip irrelevant tests with `--skip-test` or tune profile |
| "Program update available" | `update info` checks cisofy.com | Update package or tarball |
| Report file missing | Permissions issue or first-run | Check `/var/log/` permissions; run as root |

## Pain Points

- **Warnings are not all equal.** A `[WARNING]` does not always mean something is wrong. Lynis flags deviations from a generic hardened baseline. Some warnings are irrelevant to your specific use case. Review each one; don't chase a perfect score blindly.

- **The log is purged each run.** `/var/log/lynis.log` is overwritten on every scan. If you need historical logs, copy or rotate them before the next run (e.g., via a cron pre-hook).

- **Profile customization is the key to useful scans.** Edit `custom.prf` to skip tests that don't apply (e.g., `skip-test=KRNL-5820`), set compliance requirements, or change thresholds. Without tuning, the noise-to-signal ratio is high.

- **CISOfy repo vs distro package**: Distro packages lag significantly. The CISOfy community repo tracks the latest release. For security auditing tools, running the latest matters more than for most packages.

- **Cron scheduling**: Use `--cronjob` (implies `-c -Q`) for automated runs. Pipe output to a file or monitoring system. The report file (`lynis-report.dat`) is machine-parseable for integration with dashboards.

- **Enterprise features are separate.** Lynis Enterprise (paid) adds central dashboards, compliance mapping, and API access. The open-source version is fully functional for single-host auditing.

## See Also

- **aide** — file integrity monitoring; Lynis checks whether AIDE is installed and configured but doesn't replace it
- **auditd** — kernel-level audit logging; Lynis verifies auditd is running and rules are configured
- **crowdsec** — active intrusion prevention; Lynis is passive assessment only
- **osquery** — SQL-based endpoint querying; overlapping visibility with a different operational model

## References
See `references/` for:
- `docs.md` — official documentation links
