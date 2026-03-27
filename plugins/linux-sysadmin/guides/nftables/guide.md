# nftables

> **Based on:** distro-packaged (no independent version) | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/sbin/nft`
- **Unit**: `nftables.service` (loads saved ruleset on boot)
- **Config**: `/etc/nftables.conf` (ruleset loaded by the systemd unit)
- **Config dir**: `/etc/nftables.d/` (optional drop-in files, included from main config)
- **Kernel module**: `nf_tables` (loaded automatically when `nft` is used)
- **Logs**: `journalctl -u nftables`, kernel log for logged packets (`dmesg` / `journalctl -k`)
- **Install**: `apt install nftables` / `dnf install nftables`

## Quick Start

```bash
sudo apt install nftables
sudo systemctl enable --now nftables
sudo nft list ruleset                  # show current rules
sudo nft add table inet filter         # create a table
sudo nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
sudo nft add rule inet filter input tcp dport 22 accept
```

## How nftables Relates to Other Firewall Tools

```
                    nftables (kernel framework)
                   /          |           \
              ufw          firewalld     raw nft commands
           (Debian)      (RHEL/Fedora)   (direct control)
```

ufw and firewalld are frontends. They generate nftables (or iptables) rules under the hood. When you need rules those frontends can't express, you use `nft` directly.

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Table** | Container for chains. Has a family: `inet` (IPv4+6), `ip`, `ip6`, `arp`, `bridge`, `netdev` |
| **Chain** | Container for rules. Base chains attach to netfilter hooks (input, output, forward, etc.) |
| **Rule** | Match + action. Evaluated top-to-bottom within a chain |
| **Set** | Named collection of values for efficient matching (IPs, ports, etc.) |
| **Map** | Key→value lookup (e.g., port→verdict) |
| **Verdict** | `accept`, `drop`, `reject`, `jump`, `goto`, `return`, `queue` |

## Key Operations

| Task | Command |
|------|---------|
| List entire ruleset | `sudo nft list ruleset` |
| List tables | `sudo nft list tables` |
| List specific table | `sudo nft list table inet filter` |
| Add a table | `sudo nft add table inet filter` |
| Add a base chain | `sudo nft add chain inet filter input '{ type filter hook input priority 0; policy drop; }'` |
| Add a rule | `sudo nft add rule inet filter input tcp dport 443 accept` |
| Insert rule at top | `sudo nft insert rule inet filter input tcp dport 80 accept` |
| Delete a rule by handle | `sudo nft delete rule inet filter input handle 7` |
| Show handles (for deletion) | `sudo nft -a list chain inet filter input` |
| Add a named set | `sudo nft add set inet filter allowed_ips '{ type ipv4_addr; }'` |
| Add element to set | `sudo nft add element inet filter allowed_ips '{ 10.0.0.1, 10.0.0.2 }'` |
| Rule with set match | `sudo nft add rule inet filter input ip saddr @allowed_ips accept` |
| Flush a chain | `sudo nft flush chain inet filter input` |
| Flush entire ruleset | `sudo nft flush ruleset` |
| Save current ruleset | `sudo nft list ruleset > /etc/nftables.conf` |
| Load ruleset from file | `sudo nft -f /etc/nftables.conf` |
| Validate syntax (dry run) | `sudo nft -c -f /etc/nftables.conf` |
| Enable logging for a rule | `sudo nft add rule inet filter input tcp dport 25 log prefix \"mail-attempt: \" drop` |
| Monitor events in real time | `sudo nft monitor` |

## Example Ruleset

```
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    set allowed_ssh {
        type ipv4_addr
        elements = { 10.0.0.0/8, 192.168.0.0/16 }
    }

    chain input {
        type filter hook input priority 0; policy drop;

        ct state established,related accept
        iif "lo" accept
        icmp type echo-request accept
        icmpv6 type { echo-request, nd-neighbor-solicit, nd-router-advert, nd-neighbor-advert } accept
        tcp dport 22 ip saddr @allowed_ssh accept
        tcp dport { 80, 443 } accept
        log prefix "nft-drop: " counter drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
```

## Expected Ports
- nftables itself uses no ports. It is the kernel-level packet filter.
- Rules you add determine which ports are open or blocked.

## Health Checks

1. `sudo nft list ruleset | head -20` — rules are loaded
2. `systemctl is-active nftables` — service will restore rules on reboot
3. `sudo nft list chain inet filter input` — verify policy and expected rules
4. `sudo nft list ruleset | grep -c "rule"` — non-zero rule count

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Rules lost after reboot | `nftables.service` not enabled or config not saved | `sudo nft list ruleset > /etc/nftables.conf && sudo systemctl enable nftables` |
| "Error: No such file or directory" | Table or chain doesn't exist yet | Create the table first, then the chain, then rules |
| Can't delete rule | Need the handle number | `sudo nft -a list chain inet filter input` to show handles |
| Locked out after setting policy drop | No accept rule for your connection before changing policy | Always add SSH accept rule before setting `policy drop`; use `at` or console access as fallback |
| Docker breaks nftables rules | Docker manages its own iptables/nftables chains | Use `DOCKER-USER` chain for custom rules; don't flush ruleset blindly |
| Conflict with ufw or firewalld | Multiple tools managing the same tables | Pick one frontend or raw nft — don't mix |

## Pain Points

- **Flushing the ruleset can lock you out.** `nft flush ruleset` removes everything including your SSH accept rules. Always have console access or use `at` to schedule a flush-revert: `echo "nft -f /etc/nftables.conf" | at now + 5 minutes`.

- **Docker and nftables coexistence.** Docker inserts its own chains and rules. Running `nft flush ruleset` breaks Docker networking. Use the `DOCKER-USER` chain for custom filtering of Docker traffic, and never flush the entire ruleset on Docker hosts.

- **Use `inet` family for dual-stack.** The `inet` family handles both IPv4 and IPv6 in a single table. Avoid creating separate `ip` and `ip6` tables unless you need different rules per protocol.

- **Sets are dramatically faster than repeated rules.** Matching against a set of 1000 IPs is O(1) with sets vs O(n) with individual rules. Always use sets for allowlists, blocklists, and port groups.

- **Atomic ruleset loading.** `nft -f` loads an entire file atomically — there's no window where rules are partially applied. This is a major advantage over iptables, which applied rules one at a time.

- **nft syntax is not iptables syntax.** The rule language is different. `nft` uses a structured, more readable syntax. There's no 1:1 flag mapping from iptables. Use `iptables-translate` to convert legacy rules.

## See Also

- **iptables** — legacy packet filter; nftables is its replacement but iptables rules are still widely used
- **ufw** — simple frontend that generates nftables/iptables rules on Debian/Ubuntu
- **firewalld** — zone-based frontend that generates nftables rules on RHEL/Fedora
- **fail2ban** — injects ban rules into nftables/iptables
- **crowdsec** — firewall bouncer creates nftables/iptables rules for bans

## References
See `references/` for:
- `docs.md` — official documentation links
