# iptables

> **Based on:** distro-packaged (no independent version) | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/sbin/iptables` (IPv4), `/usr/sbin/ip6tables` (IPv6)
- **Unit**: `iptables.service` or `netfilter-persistent.service` (Debian)
- **Persistence**: `/etc/iptables/rules.v4`, `/etc/iptables/rules.v6` (Debian); `/etc/sysconfig/iptables` (RHEL)
- **Kernel module**: `ip_tables`, `iptable_filter`, `iptable_nat`, etc.
- **Logs**: `dmesg` / `journalctl -k` for logged packets
- **Install**: `apt install iptables iptables-persistent` / `dnf install iptables-services`
- **Status**: Legacy. nftables is the successor. On modern systems, `iptables` may be the `iptables-nft` wrapper translating to nftables under the hood.

## Quick Start

```bash
sudo apt install iptables iptables-persistent
sudo iptables -L -n -v                # list current rules
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -P INPUT DROP           # set default policy
sudo netfilter-persistent save        # persist rules
```

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Table** | `filter` (default), `nat`, `mangle`, `raw`, `security` |
| **Chain** | `INPUT`, `OUTPUT`, `FORWARD` (filter); `PREROUTING`, `POSTROUTING` (nat) |
| **Rule** | Match criteria + target/action, evaluated top-to-bottom |
| **Target** | `ACCEPT`, `DROP`, `REJECT`, `LOG`, `DNAT`, `SNAT`, `MASQUERADE`, or custom chain |
| **Policy** | Default verdict when no rule matches (`ACCEPT` or `DROP`) |

## Key Operations

| Task | Command |
|------|---------|
| List all rules (verbose) | `sudo iptables -L -n -v` |
| List with line numbers | `sudo iptables -L -n --line-numbers` |
| List NAT table | `sudo iptables -t nat -L -n -v` |
| Append rule to INPUT | `sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT` |
| Insert rule at position 1 | `sudo iptables -I INPUT 1 -p tcp --dport 443 -j ACCEPT` |
| Delete rule by number | `sudo iptables -D INPUT 3` |
| Delete rule by spec | `sudo iptables -D INPUT -p tcp --dport 8080 -j ACCEPT` |
| Set default policy | `sudo iptables -P INPUT DROP` |
| Flush all rules in chain | `sudo iptables -F INPUT` |
| Flush all rules | `sudo iptables -F` |
| Save rules (Debian) | `sudo netfilter-persistent save` |
| Save rules (RHEL) | `sudo service iptables save` |
| Restore from file | `sudo iptables-restore < /etc/iptables/rules.v4` |
| NAT / masquerade | `sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE` |
| Port forward | `sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.5:80` |
| Log before dropping | `sudo iptables -A INPUT -j LOG --log-prefix "iptables-drop: " --log-level 4` |
| Rate limit connections | `sudo iptables -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above 3 -j DROP` |
| Translate to nftables | `iptables-translate -A INPUT -p tcp --dport 22 -j ACCEPT` |

## Expected Ports
- iptables itself uses no ports. It controls which ports are accessible.

## Health Checks

1. `sudo iptables -L -n | head -20` — rules are loaded
2. `sudo iptables -L INPUT -n --line-numbers` — verify expected rules present
3. `sudo iptables -L -n -v | grep -c "ACCEPT\|DROP"` — non-zero rule count
4. `cat /etc/iptables/rules.v4` — saved rules exist for persistence

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Rules lost after reboot | Not saved / persistence package missing | Install `iptables-persistent`; run `netfilter-persistent save` |
| Locked out after `iptables -P INPUT DROP` | No ACCEPT rule for SSH added before policy change | Use console access; always add SSH rule before setting policy to DROP |
| Rule order wrong | ACCEPT after DROP — first match wins | Use `-I` (insert at top) instead of `-A` (append) for priority rules |
| NAT not working | IP forwarding disabled in kernel | `echo 1 > /proc/sys/net/ipv4/ip_forward` and persist in `sysctl.conf` |
| Docker traffic not filtered | Docker bypasses INPUT chain using FORWARD + nat | Use `DOCKER-USER` chain for custom rules |
| `iptables` vs `iptables-nft` confusion | Modern systems may use nft backend with iptables syntax | Check with `iptables -V`; if it says `nf_tables`, you're on the nft backend |

## Pain Points

- **iptables is legacy.** nftables replaced iptables in 2014. Modern distros ship `iptables-nft`, which translates iptables commands to nftables rules. New deployments should use nftables directly. This guide exists because millions of existing rules and tutorials use iptables syntax.

- **Rule order is everything.** Rules are evaluated top-to-bottom; first match wins. A `DROP` rule above an `ACCEPT` rule for the same port blocks that port. Use `--line-numbers` and `-I` (insert) to control positioning.

- **Rules are not atomic.** Each `iptables` command modifies the ruleset one rule at a time. During a bulk update, there's a window where rules are partially applied. Use `iptables-restore` for atomic bulk loading.

- **IPv4 and IPv6 are separate.** `iptables` handles IPv4 only. You need `ip6tables` for IPv6, with a completely separate set of rules. This is a common source of security gaps. nftables' `inet` family solves this.

- **Docker manages its own chains.** Docker creates `DOCKER`, `DOCKER-USER`, `DOCKER-ISOLATION-STAGE-1/2` chains. Flushing iptables breaks Docker. Use `DOCKER-USER` for custom rules that filter Docker container traffic.

- **`iptables-translate` eases migration.** If you need to convert iptables rules to nftables: `iptables-translate -A INPUT -p tcp --dport 22 -j ACCEPT` outputs the equivalent `nft` command.

## See Also

- **nftables** — the modern replacement; use for new deployments
- **ufw** — simple frontend for iptables/nftables on Debian/Ubuntu
- **firewalld** — zone-based frontend on RHEL/Fedora
- **fail2ban** — injects iptables rules for banning IPs
- **tc** — traffic control / QoS; works alongside iptables for traffic shaping

## References
See `references/` for:
- `docs.md` — official documentation links
