# rkhunter

> **Based on:** rkhunter 1.4.6 | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/bin/rkhunter`
- **Config**: `/etc/rkhunter.conf`
- **Config dir**: `/etc/rkhunter.conf.d/` (drop-in files)
- **Database**: `/var/lib/rkhunter/db/` (known-good file properties, rootkit signatures)
- **Log**: `/var/log/rkhunter.log`
- **Temp dir**: `/var/lib/rkhunter/tmp/`
- **Install**: `apt install rkhunter` / `dnf install rkhunter`

## Quick Start

```bash
sudo apt install rkhunter
sudo rkhunter --update                 # update rootkit signatures
sudo rkhunter --propupd                # baseline file properties (run on clean system)
sudo rkhunter --check                  # run full scan
sudo rkhunter --check --sk             # skip keypress prompts (for cron)
```

## What It Checks

rkhunter scans for:

| Category | Examples |
|----------|---------|
| **Known rootkits** | 370+ rootkit signatures (55shine, Adore, Knark, SucKIT, etc.) |
| **Suspicious files** | Hidden files in `/tmp`, `/dev`; files with unusual permissions |
| **Backdoor checks** | Bindshell, Sniffer, w55808 backdoor, etc. |
| **System command integrity** | Compares hashes of critical binaries (`ls`, `ps`, `netstat`, `ssh`, etc.) |
| **Startup files** | Suspicious entries in init scripts |
| **Network** | Listening services, promiscuous interfaces |
| **OS-specific** | Kernel module checks, loaded modules |

## Key Operations

| Task | Command |
|------|---------|
| Full system check | `sudo rkhunter --check` |
| Non-interactive check | `sudo rkhunter --check --sk` |
| Update signatures | `sudo rkhunter --update` |
| Update file properties baseline | `sudo rkhunter --propupd` |
| Show version | `rkhunter --version` |
| Check config validity | `sudo rkhunter --config-check` |
| List available tests | `sudo rkhunter --list tests` |
| Run specific test only | `sudo rkhunter --check --enable rootkits` |
| Disable specific test | `sudo rkhunter --check --disable suspscan` |
| Show warnings only (quiet) | `sudo rkhunter --check --sk --quiet` |
| View report | `sudo cat /var/log/rkhunter.log` |

## Health Checks

1. `rkhunter --version` — installed and runnable
2. `sudo rkhunter --update` — signatures can be fetched
3. `ls /var/lib/rkhunter/db/rkhunter.dat` — property database exists
4. `stat /var/log/rkhunter.log` — recent scan has been run

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Warnings on system binaries after update | Package upgrade changed file hashes | Run `sudo rkhunter --propupd` after system updates |
| "Invalid SCRIPTWHITELIST" warnings | Whitelisted files moved or renamed | Update `SCRIPTWHITELIST` paths in `/etc/rkhunter.conf` |
| `/dev/.udev` or `/dev/.initramfs` flagged | Normal on many distros | Add to `ALLOWDEVDIR` in config |
| SSH root login warning | `PermitRootLogin` set in sshd_config | Set `ALLOW_SSH_ROOT_USER=yes` in rkhunter.conf if intentional |
| Hidden directory warnings in `/dev` | False positives on device manager temp dirs | Whitelist with `ALLOWHIDDENDIR` |
| Update fails | Mirror unreachable or DNS issue | Check network; try `rkhunter --update --versioncheck` |
| Too many false positives | Default config flags normal system features | Tune `rkhunter.conf` with ALLOW* directives |

## Pain Points

- **False positives are common.** rkhunter flags many things that are normal on modern systems (hidden dirs in `/dev`, SSH root login, etc.). After a clean install, run `rkhunter --check`, review all warnings, and whitelist legitimate items in `rkhunter.conf`. Otherwise you get alert fatigue.

- **Run `--propupd` after every system update.** rkhunter compares binary hashes against its stored database. When `apt upgrade` changes system binaries, rkhunter flags them as modified. Always run `sudo rkhunter --propupd` after verified package updates to update the baseline.

- **Cron integration.** Use `--check --sk --quiet` in cron to get only warnings. Configure `MAIL-ON-WARNING=root` in `rkhunter.conf` to email alerts. Or pipe output to your monitoring system.

- **rkhunter checks known rootkits, not zero-days.** The signature database covers known rootkits. It won't detect novel or custom rootkits. Use alongside other layers (AIDE for integrity, auditd for access logging, ClamAV for malware).

- **The log file is the real output.** Console output is summarized. The full details (what was checked, what was found, what was skipped) are in `/var/log/rkhunter.log`. Always check the log when investigating a warning.

- **Debian's defaults need tuning.** The Debian package ships with `/etc/default/rkhunter` controlling cron behavior. Set `CRON_DAILY_RUN="true"` and `APT_AUTOGEN="true"` (auto-update props after apt runs).

## See Also

- **clamav** — malware/virus scanning; rkhunter focuses on rootkits and backdoors
- **aide** — file integrity monitoring; complements rkhunter's binary hash checking
- **lynis** — comprehensive security auditing; broader scope than rkhunter
- **auditd** — kernel-level access logging; catches suspicious activity in real time

## References
See `references/` for:
- `docs.md` — official documentation links
