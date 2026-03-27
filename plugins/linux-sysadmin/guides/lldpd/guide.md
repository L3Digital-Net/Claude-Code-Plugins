# lldpd

> **Based on:** lldpd 1.0.19 | **Updated:** 2026-03-27

## Identity
- **Unit**: `lldpd.service`
- **Daemon**: `/usr/sbin/lldpd`
- **Client CLI**: `lldpcli` (interactive or one-shot commands)
- **Legacy client**: `lldpctl` (same binary, non-interactive output)
- **Config**: `/etc/lldpd.conf` (lldpcli commands executed at startup)
- **Config dir**: `/etc/lldpd.d/*.conf` (drop-in config files)
- **Socket**: `/var/run/lldpd.socket` (daemon ↔ client communication)
- **Logs**: `journalctl -u lldpd`
- **Install**: `apt install lldpd` / `dnf install lldpd`

## Quick Start

```bash
sudo apt install lldpd
sudo systemctl enable --now lldpd
lldpcli show neighbors                # see what's connected
lldpcli show interfaces               # see local interface advertisements
```

## What It Does

LLDP (IEEE 802.1AB) lets network devices advertise their identity, capabilities, and connections to neighbors. lldpd both transmits and receives these frames, letting you answer: "what is this server physically plugged into?"

Typical output tells you: switch name, switch port, VLAN, management IP, and system description for each local interface.

## Key Operations

| Task | Command |
|------|---------|
| Show discovered neighbors | `lldpcli show neighbors` |
| Neighbor summary (one line each) | `lldpcli show neighbors summary` |
| Detailed neighbor info | `lldpcli show neighbors details` |
| Show local interfaces | `lldpcli show interfaces` |
| Show local chassis info | `lldpcli show chassis` |
| Show daemon configuration | `lldpcli show configuration` |
| Show LLDP statistics | `lldpcli show statistics` |
| Watch for neighbor changes | `lldpcli watch` |
| JSON output | `lldpcli -f json show neighbors` |
| XML output | `lldpcli -f xml show neighbors` |
| Set system description | `lldpcli configure system description "My Server"` |
| Set transmit interval | `lldpcli configure lldp tx-interval 30` |
| Enable CDP reception | Run daemon with `-c` flag or `lldpcli configure lldp agent-type nearest-bridge` |
| Pause LLDP on interface | `lldpcli configure lldp portidsubtype ifname` |

## Protocol Support

lldpd can receive (and optionally transmit) multiple discovery protocols:

| Protocol | Flag | Origin |
|----------|------|--------|
| LLDP (802.1AB) | Default | IEEE standard |
| CDP | `-c` | Cisco |
| EDP | `-e` | Extreme Networks |
| FDP | `-f` | Foundry/Brocade |
| SONMP | `-s` | Nortel/SynOptics |

By default, only LLDP is active. Enable others if your switches use proprietary protocols.

## Expected Ports
- No TCP/UDP ports. LLDP uses Ethernet frames (EtherType 0x88CC) at Layer 2.
- The daemon communicates with the client via Unix socket (`/var/run/lldpd.socket`).

## Health Checks

1. `systemctl is-active lldpd` — daemon running
2. `lldpcli show neighbors` — returns at least one neighbor (if connected to LLDP-capable switch)
3. `lldpcli show statistics` — counters incrementing (tx/rx frame counts)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| No neighbors discovered | Switch doesn't send LLDP, or wrong protocol | Check switch config; try enabling CDP (`-c`) if Cisco gear |
| "Permission denied" from lldpcli | User not in `lldpd` group or socket permissions | `sudo usermod -aG lldpd $USER` then re-login; or use `sudo lldpcli` |
| Only loopback/virtual interfaces shown | lldpd filters virtual interfaces by default | Use `-I` flag to specify which interfaces to monitor |
| Neighbor data stale or missing | TTL expired (default 120s) and no new frames received | Check cable, switch port status; `lldpcli show statistics` for rx errors |
| SNMP subagent not connecting | AgentX socket mismatch | Start with `-x` flag; ensure snmpd has `master agentx` in config |
| Bond/bridge interfaces not working | lldpd needs explicit config for bonded interfaces | Use `-I` to include the bond/bridge; set `configure system bond-slave-src-mac-type fixed` |

## Pain Points

- **Switches must have LLDP enabled too.** lldpd can only discover neighbors that are transmitting LLDP (or CDP/EDP) frames. If the switch port has LLDP disabled, lldpd sees nothing. Check switch config first when debugging empty neighbor tables.

- **Virtual interfaces are filtered by default.** Docker bridges, veth pairs, and other virtual interfaces are excluded from LLDP transmission. Use `-I` with patterns (e.g., `-I eth*,eno*`) to control which interfaces participate.

- **Config file is just lldpcli commands.** `/etc/lldpd.conf` contains the same commands you'd type in `lldpcli`. One command per line, executed at startup. Changes made via `lldpcli configure ...` are persisted automatically to the running config but not to the file — add them to `lldpd.conf` for persistence across restarts.

- **LLDP-MED for VoIP/PoE.** If you need to advertise location data or network policies (for VoIP phones, PoE devices), use the `-M` flag with a device class. This is niche but critical in VoIP environments.

- **Output formats for scripting.** `lldpcli -f json show neighbors` gives structured output for parsing. The `json0` format is more verbose but stable across different neighbor counts (consistent structure whether there's one neighbor or ten).

## See Also

- **nmap** — active network scanning; lldpd is passive Layer 2 discovery
- **avahi** — mDNS/zeroconf service discovery at Layer 3+; different scope than LLDP
- **ss** — socket statistics; complementary network diagnostics

## References
See `references/` for:
- `docs.md` — official documentation links
