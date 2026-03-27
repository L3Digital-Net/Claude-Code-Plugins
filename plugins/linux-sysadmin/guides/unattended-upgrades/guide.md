# unattended-upgrades

> **Based on:** distro-packaged (no independent version) | **Updated:** 2026-03-27

## Identity
- **Unit**: `unattended-upgrades.service`, triggered by `apt-daily-upgrade.timer`
- **Config**: `/etc/apt/apt.conf.d/50unattended-upgrades` (what to upgrade)
- **Enable**: `/etc/apt/apt.conf.d/20auto-upgrades` (turn on/off auto-updates)
- **Logs**: `/var/log/unattended-upgrades/unattended-upgrades.log`, `/var/log/unattended-upgrades/unattended-upgrades-dpkg.log`
- **Install**: `apt install unattended-upgrades` (Debian/Ubuntu only)

## Quick Start

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades    # interactive enable
# — or manually —
cat <<EOF | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
sudo unattended-upgrade --dry-run                   # test what would be upgraded
```

## Key Operations

| Task | Command |
|------|---------|
| Enable interactively | `sudo dpkg-reconfigure -plow unattended-upgrades` |
| Dry run (test) | `sudo unattended-upgrade --dry-run` |
| Run now | `sudo unattended-upgrade` |
| Verbose run | `sudo unattended-upgrade -v` |
| Debug run | `sudo unattended-upgrade -d` |
| Check timer status | `systemctl status apt-daily-upgrade.timer` |
| View log | `cat /var/log/unattended-upgrades/unattended-upgrades.log` |
| Check what would upgrade | `sudo unattended-upgrade --dry-run -v 2>&1 \| grep "Packages that will"` |

## Configuration

### `/etc/apt/apt.conf.d/20auto-upgrades`

```
APT::Periodic::Update-Package-Lists "1";    // apt update frequency (days)
APT::Periodic::Unattended-Upgrade "1";      // run unattended-upgrades (days)
APT::Periodic::Download-Upgradeable-Packages "1";  // pre-download packages
APT::Periodic::AutocleanInterval "7";       // apt autoclean frequency (days)
```

### `/etc/apt/apt.conf.d/50unattended-upgrades`

Key settings:

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
    // Add third-party repos here if desired
};

Unattended-Upgrade::Package-Blacklist {
    // "linux-image*";         // prevent kernel auto-updates
    // "postgresql*";          // prevent DB auto-updates
};

Unattended-Upgrade::Mail "admin@example.com";
Unattended-Upgrade::MailReport "on-change";     // or "always"
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";   // auto-reboot if needed
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
```

## Health Checks

1. `systemctl is-active apt-daily-upgrade.timer` — timer scheduled
2. `cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -20` — recent activity
3. `sudo unattended-upgrade --dry-run` — no errors
4. `apt-config dump | grep Periodic` — periodic settings active

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Not running at all | `20auto-upgrades` missing or set to "0" | Create/edit file with values set to "1" |
| Only security updates applied | Default config only allows security origins | Add desired origins to `Allowed-Origins` |
| Upgrade breaks a service | Auto-updated package with breaking change | Add package to `Package-Blacklist`; restore from backup |
| Email notifications not sending | No MTA configured or wrong `Mail` setting | Install `msmtp` or `postfix`; set `Mail` in config |
| Pending reboot not happening | `Automatic-Reboot` set to "false" | Set to "true" with a `Reboot-Time`; or handle manually |
| Timer not firing | systemd timer disabled | `systemctl enable --now apt-daily-upgrade.timer` |
| Lock contention with manual apt | unattended-upgrade running while you run apt | Wait for it to finish; check with `ps aux \| grep unattended` |

## Pain Points

- **Security-only by default.** The default configuration only upgrades security packages. This is intentional — it minimizes breakage risk. To upgrade all packages, add non-security origins to `Allowed-Origins`, but accept the increased risk.

- **Blacklist critical services.** Database servers (PostgreSQL, MariaDB), custom-compiled software, and kernel packages can break on auto-update. Add them to `Package-Blacklist` and upgrade them manually during maintenance windows.

- **Automatic reboots need care.** Some security updates (kernel, glibc) require a reboot. Set `Automatic-Reboot "true"` only if your service can tolerate unscheduled restarts. Set `Automatic-Reboot-Time` to a low-traffic window.

- **Check for `/var/run/reboot-required`.** After unattended upgrades, this file indicates a reboot is needed. Monitor it with your alerting system (Netdata, Uptime Kuma, etc.) to catch pending reboots.

- **Debian/Ubuntu only.** This tool is specific to APT-based distributions. RHEL/Fedora use `dnf-automatic` for the same purpose. The concepts are similar but the config files differ.

## See Also

- **package-managers** — APT fundamentals; unattended-upgrades automates `apt upgrade`
- **systemd** — `apt-daily-upgrade.timer` triggers the upgrade run
- **lynis** — security auditing; checks whether unattended-upgrades is configured

## References
See `references/` for:
- `docs.md` — official documentation links
