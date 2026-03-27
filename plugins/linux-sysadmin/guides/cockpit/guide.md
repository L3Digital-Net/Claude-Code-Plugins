# cockpit

> **Based on:** cockpit 359 | **Updated:** 2026-03-27

## Identity
- **Unit**: `cockpit.socket` (socket-activated; `cockpit.service` starts on demand)
- **Config**: `/etc/cockpit/cockpit.conf` (optional; defaults are sensible)
- **Config dir**: `/etc/cockpit/` (certificates, branding, config)
- **Web root**: `/usr/share/cockpit/` (built-in UI modules)
- **Custom modules**: `/usr/share/cockpit/` (system-wide) or `~/.local/share/cockpit/` (per-user)
- **TLS cert**: `/etc/cockpit/ws-certs.d/` (auto-generated self-signed if none provided)
- **Default port**: 9090/tcp (HTTPS)
- **Logs**: `journalctl -u cockpit`
- **Install**: `apt install cockpit` / `dnf install cockpit`

## Quick Start

```bash
sudo apt install cockpit
sudo systemctl enable --now cockpit.socket
# Open https://<host>:9090 in browser
# Login with any system user that has sudo
```

## What It Provides

Cockpit is a web-based server administration panel that uses your system's existing APIs (systemd, NetworkManager, udisks, PackageKit, etc.) rather than its own config layer. Changes made in Cockpit are the same as changes made via CLI.

Core modules (installed with `cockpit`):

| Module | Package | Manages |
|--------|---------|---------|
| System | `cockpit-system` | Overview, hostname, time, performance |
| Logs | `cockpit-system` | journalctl browsing with filters |
| Storage | `cockpit-storaged` | Disks, partitions, RAID, LVM, NFS, LUKS |
| Networking | `cockpit-networkmanager` | Interfaces, bonds, bridges, VLANs, firewall |
| Services | `cockpit-system` | systemd unit management |
| Users | `cockpit-system` | User accounts, SSH keys, groups |
| Terminal | `cockpit-system` | In-browser shell |

Optional modules:

| Module | Package | Manages |
|--------|---------|---------|
| Podman containers | `cockpit-podman` | Container lifecycle, images, pods |
| Virtual machines | `cockpit-machines` | KVM/libvirt VMs |
| Package updates | `cockpit-packagekit` | System updates |
| SELinux | `cockpit-selinux` | SELinux troubleshooting |
| kdump | `cockpit-kdump` | Kernel crash dump config |
| 389 DS | `cockpit-389-ds` | LDAP directory server |

## Key Operations

| Task | How |
|------|-----|
| Access dashboard | `https://<host>:9090` |
| Login | Any system user; needs `sudo` for admin tasks |
| Add remote host | Dashboard → "+" → enter hostname (needs SSH access) |
| Manage services | Services tab → start/stop/enable/disable units |
| View logs | Logs tab → filter by priority, unit, time range |
| Manage storage | Storage tab → create RAID, LVM, format, mount |
| Open terminal | Terminal tab → full shell in browser |
| Manage containers | Containers tab (requires `cockpit-podman`) |
| Create VM | Virtual Machines tab (requires `cockpit-machines`) |
| Change TLS cert | Place `.cert` and `.key` files in `/etc/cockpit/ws-certs.d/` |

## Expected Ports
- **9090/tcp** — HTTPS web UI (socket-activated)
- Verify: `ss -tlnp | grep 9090`
- Firewall: `sudo ufw allow 9090` or `sudo firewall-cmd --add-service=cockpit --permanent`

## Health Checks

1. `systemctl is-active cockpit.socket` — socket listening
2. `curl -sk https://localhost:9090/` — web UI responds
3. `ss -tlnp | grep 9090` — port bound
4. `journalctl -u cockpit --since "1 hour ago"` — no errors

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Can't connect on :9090 | Socket not enabled or firewall blocking | `systemctl enable --now cockpit.socket`; open port 9090 in firewall |
| Login fails | User doesn't exist or password wrong | Cockpit uses system PAM auth; test with `su - <user>` |
| No admin features | User not in sudo/wheel group | `usermod -aG sudo <user>` (Debian) or `usermod -aG wheel <user>` (RHEL) |
| Certificate warning | Using auto-generated self-signed cert | Place real cert in `/etc/cockpit/ws-certs.d/<hostname>.cert` with matching `.key` |
| Module missing (no Containers tab) | Optional package not installed | `apt install cockpit-podman` / `dnf install cockpit-podman` |
| Slow / high memory | Many browser tabs or heavy system metrics | Normal for large systems; Cockpit uses ~50-100MB per active session |

## Pain Points

- **Socket activation means idle = zero resources.** `cockpit.socket` listens on 9090 but `cockpit-ws` only runs when a browser connects. No background processes when nobody's using it.

- **It uses your existing tools, not its own.** Cockpit calls systemd, NetworkManager, udisks, PackageKit, and libvirt directly. There's no "cockpit config layer" — everything it does is equivalent to CLI commands. This means Cockpit never conflicts with your CLI workflow.

- **Multi-host management.** You can add remote hosts from the dashboard. Cockpit connects via SSH, so you just need SSH access to the remote host (and `cockpit-system` installed there). No agent required beyond the cockpit packages.

- **TLS certificate handling.** Cockpit reads `.cert` + `.key` files from `/etc/cockpit/ws-certs.d/`. It picks the file with the highest priority (alphabetical). For Let's Encrypt, symlink or copy the cert there and restart `cockpit.service`.

- **Cockpit on Proxmox.** Proxmox has its own web UI. Installing Cockpit alongside it works but is redundant for most tasks. Cockpit is more useful on standalone Debian/RHEL servers without a built-in web UI.

## See Also

- **systemd** — Cockpit's Services tab is a GUI for systemctl
- **networkmanager** — Cockpit's Networking tab is a GUI for nmcli
- **kvm-libvirt** — Cockpit's Virtual Machines tab manages KVM VMs
- **podman** — Cockpit's Containers tab manages Podman containers
- **proxmox** — Proxmox has its own web UI; Cockpit is for non-Proxmox hosts

## References
See `references/` for:
- `docs.md` — official documentation links
