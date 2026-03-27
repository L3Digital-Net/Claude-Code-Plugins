# networkmanager

> **Based on:** networkmanager 1.56 | **Updated:** 2026-03-27

## Identity
- **Unit**: `NetworkManager.service`
- **Config**: `/etc/NetworkManager/NetworkManager.conf`
- **Config dir**: `/etc/NetworkManager/conf.d/*.conf` (drop-in overrides)
- **Connection profiles**: `/etc/NetworkManager/system-connections/` (keyfile format, `.nmconnection`)
- **CLI**: `nmcli` (scriptable), `nmtui` (TUI), nm-connection-editor (GUI)
- **Dispatcher**: `/etc/NetworkManager/dispatcher.d/` (scripts run on network events)
- **Logs**: `journalctl -u NetworkManager`
- **Install**: `apt install network-manager` / `dnf install NetworkManager` (pre-installed on RHEL, Fedora, Ubuntu Desktop)

## Quick Start

```bash
nmcli device status                    # show all interfaces and their state
nmcli connection show                  # list configured connections
nmcli device wifi list                 # scan WiFi networks
nmcli connection up "My Connection"    # activate a connection
nmtui                                  # interactive TUI for config
```

## Key Operations

| Task | Command |
|------|---------|
| Show all devices | `nmcli device status` |
| Show all connections | `nmcli connection show` |
| Show active connections | `nmcli connection show --active` |
| Show connection details | `nmcli connection show "My Connection"` |
| Show device details | `nmcli device show eth0` |
| Create static IP connection | `nmcli connection add type ethernet con-name myconn ifname eth0 ipv4.addresses 10.0.0.5/24 ipv4.gateway 10.0.0.1 ipv4.dns 8.8.8.8 ipv4.method manual` |
| Create DHCP connection | `nmcli connection add type ethernet con-name myconn ifname eth0` |
| Modify a connection | `nmcli connection modify myconn ipv4.dns "8.8.8.8 8.8.4.4"` |
| Activate connection | `nmcli connection up myconn` |
| Deactivate connection | `nmcli connection down myconn` |
| Delete connection | `nmcli connection delete myconn` |
| Reload config files | `nmcli connection reload` |
| Set DNS manually | `nmcli connection modify myconn ipv4.dns "1.1.1.1" ipv4.ignore-auto-dns yes` |
| Create bond | `nmcli connection add type bond con-name mybond ifname bond0 bond.options "mode=802.3ad,miimon=100"` |
| Add slave to bond | `nmcli connection add type ethernet con-name bond-slave1 ifname eth0 master bond0` |
| Create VLAN | `nmcli connection add type vlan con-name vlan100 ifname eth0.100 dev eth0 id 100` |
| Create bridge | `nmcli connection add type bridge con-name mybr ifname br0` |
| WiFi connect | `nmcli device wifi connect "SSID" password "pass"` |
| Show WiFi networks | `nmcli device wifi list` |
| General status | `nmcli general status` |

## Expected Ports
- No listening ports. NetworkManager configures network interfaces, it doesn't serve network traffic.
- D-Bus interface for local IPC (`org.freedesktop.NetworkManager`).

## Health Checks

1. `systemctl is-active NetworkManager` — service running
2. `nmcli general status` — shows "connected" state
3. `nmcli device status` — shows interfaces with expected states
4. `nmcli connection show --active` — expected connections are active

## Connection Profile Format

Profiles stored as keyfiles in `/etc/NetworkManager/system-connections/`:

```ini
# /etc/NetworkManager/system-connections/myconn.nmconnection
[connection]
id=myconn
type=ethernet
interface-name=eth0
autoconnect=true

[ipv4]
method=manual
addresses=10.0.0.5/24
gateway=10.0.0.1
dns=8.8.8.8;1.1.1.1;

[ipv6]
method=auto
```

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Interface "unmanaged" | NetworkManager not managing the interface | Check `/etc/NetworkManager/NetworkManager.conf` for `[keyfile] unmanaged-devices`; remove exclusion |
| Conflict with `/etc/network/interfaces` | Debian: both `ifupdown` and NM managing same interface | Use one or the other; set `managed=true` in NM conf or remove interface from `interfaces` file |
| DNS not working after NM config | NM overwriting `/etc/resolv.conf` | Use `nmcli connection modify ... ipv4.dns "1.1.1.1" ipv4.ignore-auto-dns yes` |
| Connection drops after sleep/resume | Power management on WiFi adapter | Disable with `nmcli connection modify myconn wifi.powersave 2` (2=disable) |
| nmcli shows "Error: Connection ... not found" | Connection name vs UUID mismatch | Use `nmcli connection show` to see exact names; use UUID instead of name |
| Profile changes not taking effect | Connection not reactivated | `nmcli connection up myconn` after modifications |

## Pain Points

- **NetworkManager vs systemd-networkd vs ifupdown.** Only one network manager should control each interface. Debian servers traditionally used `/etc/network/interfaces` (ifupdown). If NM is installed alongside ifupdown, configure `[main] plugins=ifupdown,keyfile` in `NetworkManager.conf` and mark interfaces as managed or unmanaged explicitly.

- **DNS management is contentious.** NM wants to manage `/etc/resolv.conf`. This conflicts with `resolvconf`, `systemd-resolved`, or manually managed DNS. Control with `[main] dns=none` (NM doesn't touch resolv.conf), `dns=default` (NM writes resolv.conf), or `dns=systemd-resolved`.

- **`nmcli` is powerful but verbose.** The syntax is long but consistent. For interactive use, `nmtui` is faster. For scripts, `nmcli -t -f NAME,UUID,TYPE connection show` gives tab-separated output. `-t` (terse) and `-f` (fields) are essential for scripting.

- **Dispatcher scripts for network events.** Drop scripts in `/etc/NetworkManager/dispatcher.d/` to run commands when interfaces go up/down, get DHCP leases, etc. Scripts receive interface name and action as arguments. Useful for VPN auto-connect, firewall rules, etc.

- **Server vs desktop.** On desktop, NM manages WiFi, VPN, and dynamic connections well. On servers, it's often overkill. Many server admins prefer `systemd-networkd` or raw `/etc/network/interfaces` for simpler static configs. RHEL defaults to NM even on servers.

## See Also

- **iproute2** — low-level network config; NM calls `ip` commands under the hood
- **systemd** — `systemd-networkd` is an alternative network manager for servers
- **cockpit** — web UI for NetworkManager via the Networking tab
- **wireguard** — NM can manage WireGuard connections natively (GNOME 42+, nmcli)

## References
See `references/` for:
- `docs.md` — official documentation links
