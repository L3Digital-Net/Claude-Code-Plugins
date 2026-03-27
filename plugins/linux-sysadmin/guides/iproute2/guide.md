# iproute2

> **Based on:** distro-packaged (no independent version) | **Updated:** 2026-03-27

## Identity
- **Package**: `iproute2`
- **Primary binary**: `/usr/sbin/ip` (or `/sbin/ip`)
- **Other tools**: `ss`, `bridge`, `tc`, `nstat`, `routel`, `ip-netns`
- **Config**: No config file; `ip` modifies kernel networking state directly. Persistent config is via the distro's network manager (netplan, NetworkManager, systemd-networkd, `/etc/network/interfaces`).
- **Replaces**: `ifconfig`, `route`, `arp`, `netstat` (from the deprecated `net-tools` package)
- **Install**: Pre-installed on all modern Linux distributions

## Quick Start

```bash
ip addr show                           # show all interface addresses
ip link show                           # show link-layer state
ip route show                          # show routing table
ip neigh show                          # show ARP/neighbor table
ip -br addr                            # brief format: interface, state, addresses
```

## Object Model

The `ip` command operates on objects:

| Object | Replaces | Purpose |
|--------|----------|---------|
| `ip addr` | `ifconfig` | Manage IP addresses on interfaces |
| `ip link` | `ifconfig` | Manage network interfaces (up/down, MTU, etc.) |
| `ip route` | `route` | Manage routing table |
| `ip neigh` | `arp` | Manage ARP/neighbor cache |
| `ip netns` | — | Manage network namespaces |
| `ip tunnel` | — | Manage IP tunnels (GRE, IPIP, SIT) |
| `ip rule` | — | Policy routing rules |
| `ip maddr` | — | Multicast addresses |
| `ip monitor` | — | Watch netlink events in real time |

## Key Operations

| Task | Command |
|------|---------|
| Show all addresses (brief) | `ip -br addr` |
| Show specific interface | `ip addr show dev eth0` |
| Add IP address | `sudo ip addr add 10.0.0.5/24 dev eth0` |
| Remove IP address | `sudo ip addr del 10.0.0.5/24 dev eth0` |
| Bring interface up | `sudo ip link set eth0 up` |
| Bring interface down | `sudo ip link set eth0 down` |
| Set MTU | `sudo ip link set eth0 mtu 9000` |
| Show routing table | `ip route show` |
| Add default route | `sudo ip route add default via 10.0.0.1` |
| Add static route | `sudo ip route add 172.16.0.0/16 via 10.0.0.1 dev eth0` |
| Delete route | `sudo ip route del 172.16.0.0/16` |
| Show ARP table | `ip neigh show` |
| Flush ARP cache | `sudo ip neigh flush all` |
| Add static ARP entry | `sudo ip neigh add 10.0.0.50 lladdr aa:bb:cc:dd:ee:ff dev eth0` |
| Show route to destination | `ip route get 8.8.8.8` |
| JSON output | `ip -j addr show` |
| Color output | `ip -c addr show` |
| Show all namespaces | `ip netns list` |
| Run command in namespace | `sudo ip netns exec mynamespace ip addr show` |
| Monitor all network events | `ip monitor all` |
| Show link statistics | `ip -s link show dev eth0` |
| Add VLAN interface | `sudo ip link add link eth0 name eth0.100 type vlan id 100` |
| Create bridge | `sudo ip link add br0 type bridge` |
| Add interface to bridge | `sudo ip link set eth0 master br0` |

## iproute2 vs net-tools

| net-tools (deprecated) | iproute2 (modern) |
|------------------------|-------------------|
| `ifconfig` | `ip addr`, `ip link` |
| `ifconfig eth0 up` | `ip link set eth0 up` |
| `route` | `ip route` |
| `route add default gw 10.0.0.1` | `ip route add default via 10.0.0.1` |
| `arp` | `ip neigh` |
| `netstat` | `ss` |
| `netstat -rn` | `ip route show` |
| `ifconfig eth0 10.0.0.5` | `ip addr add 10.0.0.5/24 dev eth0` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Changes lost after reboot | `ip` modifies runtime state only | Configure persistence via netplan, NetworkManager, or `/etc/network/interfaces` |
| "RTNETLINK answers: File exists" | Address or route already exists | Use `ip addr replace` or delete first with `ip addr del` |
| Interface shows `NO-CARRIER` | Cable unplugged or link partner down | Check physical connection; `ip -s link show dev eth0` for error counters |
| Default route missing after reboot | DHCP not renewing or static route not persisted | Check DHCP client; add to netplan/interfaces config |
| "Network is unreachable" | No route to destination | `ip route get <dest>` to diagnose; add appropriate route |
| Namespace commands fail | Missing privileges | `ip netns` operations require root |

## Pain Points

- **All changes are ephemeral.** The `ip` command modifies kernel state directly. Nothing persists across reboots. You must use your distro's persistent network configuration (netplan, NetworkManager, systemd-networkd, or `/etc/network/interfaces`) for changes that survive restarts.

- **`ifconfig` is not just deprecated — it lies.** `ifconfig` can't show secondary addresses, doesn't understand modern features (network namespaces, VRFs), and misreports statistics on some interfaces. Always use `ip`.

- **JSON output for scripting.** `ip -j addr show` outputs JSON, which is far more reliable to parse than the text format. Pipe to `jq` for extraction: `ip -j route show | jq '.[0].gateway'`.

- **`ip route get` is your best diagnostic.** It shows exactly which route the kernel would use for a given destination, including the source address and interface. More useful than `ip route show` for debugging.

- **Network namespaces are how containers work.** Understanding `ip netns` helps debug Docker/Podman networking. Each container gets its own namespace with its own interfaces and routing table.

- **Brief mode saves time.** `ip -br addr` gives a one-line-per-interface summary. `ip -br link` shows just interface names and states. Use these for quick checks.

## See Also

- **ss** — socket statistics (part of iproute2); the modern replacement for `netstat`
- **tc** — traffic control (part of iproute2); QoS and traffic shaping
- **networkmanager** — persistent network configuration daemon; uses iproute2 under the hood
- **nftables** — packet filtering; `ip` configures addresses and routes, nftables controls what packets are allowed

## References
See `references/` for:
- `docs.md` — official documentation links
