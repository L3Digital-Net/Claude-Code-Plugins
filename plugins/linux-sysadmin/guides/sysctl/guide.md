# sysctl

> **Based on:** distro-packaged (no independent version) | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/sbin/sysctl`
- **Config**: `/etc/sysctl.conf` (main; loaded at boot)
- **Config dir**: `/etc/sysctl.d/*.conf` (drop-in files; loaded in lexical order)
- **Vendor defaults**: `/usr/lib/sysctl.d/*.conf` (distribution defaults; overridden by `/etc/sysctl.d/`)
- **Runtime values**: `/proc/sys/` (virtual filesystem; each parameter maps to a file)
- **Logs**: `journalctl -u systemd-sysctl` (loaded at boot by systemd-sysctl.service)
- **Install**: Pre-installed (part of `procps` package)

## Quick Start

```bash
sysctl -a                              # list all parameters
sysctl net.ipv4.ip_forward             # read one parameter
sudo sysctl -w net.ipv4.ip_forward=1   # set at runtime (temporary)
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-forwarding.conf
sudo sysctl --system                   # reload all config files
```

## Key Operations

| Task | Command |
|------|---------|
| List all parameters | `sysctl -a` |
| Read a parameter | `sysctl <key>` or `cat /proc/sys/<path>` |
| Set temporarily (runtime) | `sudo sysctl -w <key>=<value>` |
| Reload all config files | `sudo sysctl --system` |
| Load specific file | `sudo sysctl -p /etc/sysctl.d/99-custom.conf` |
| Load default (`/etc/sysctl.conf`) | `sudo sysctl -p` |
| Search parameters by pattern | `sysctl -a \| grep <pattern>` |
| Show changed-from-default values | `sysctl -a --changed` (newer procps versions) |

## Essential Parameters

### Networking

```bash
# IP forwarding (required for routing, NAT, containers)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Connection tracking (tune for high-traffic servers)
net.netfilter.nf_conntrack_max = 262144

# TCP tuning
net.core.somaxconn = 65535                    # max listen backlog
net.ipv4.tcp_max_syn_backlog = 65535          # SYN queue size
net.core.rmem_max = 16777216                  # max receive buffer
net.core.wmem_max = 16777216                  # max send buffer
net.ipv4.tcp_rmem = 4096 87380 16777216       # TCP receive buffer (min default max)
net.ipv4.tcp_wmem = 4096 65536 16777216       # TCP send buffer

# Security hardening
net.ipv4.conf.all.rp_filter = 1               # reverse path filtering
net.ipv4.conf.all.accept_redirects = 0         # ignore ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1       # ignore broadcast pings
net.ipv4.conf.all.log_martians = 1             # log impossible addresses
```

### Memory and VM

```bash
vm.swappiness = 10                             # reduce swap tendency (0-100)
vm.overcommit_memory = 0                       # heuristic overcommit (default)
vm.dirty_ratio = 20                            # % RAM before sync write
vm.dirty_background_ratio = 10                 # % RAM before background flush
vm.max_map_count = 262144                      # needed by Elasticsearch, etc.
```

### File System

```bash
fs.file-max = 2097152                          # system-wide max open files
fs.inotify.max_user_watches = 524288           # for file watchers (IDEs, webpack)
fs.inotify.max_user_instances = 1024
```

### Kernel

```bash
kernel.pid_max = 4194304                       # max PID value
kernel.panic = 10                              # reboot N seconds after panic
kernel.sysrq = 1                               # enable SysRq key (0 = disable)
```

## Config File Organization

```bash
# Use numbered prefixes for load order:
/etc/sysctl.d/
├── 10-network-hardening.conf    # security baseline
├── 50-performance.conf          # TCP/memory tuning
├── 90-docker.conf               # container-specific
└── 99-custom.conf               # local overrides (loaded last, wins)
```

Higher numbers load later and override lower numbers. `/etc/sysctl.conf` loads after `/etc/sysctl.d/`.

## Health Checks

1. `sysctl net.ipv4.ip_forward` — verify critical parameters are set
2. `sudo sysctl --system 2>&1 | grep -i error` — no errors loading config
3. `sysctl -a | wc -l` — returns hundreds of parameters (kernel is responding)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Parameter reverts after reboot | Used `sysctl -w` (runtime only) | Add to `/etc/sysctl.d/*.conf` and reload with `sysctl --system` |
| "No such file or directory" | Parameter doesn't exist on this kernel | Kernel module not loaded, or parameter removed in this version |
| Docker networking broken | `net.ipv4.ip_forward` is 0 | Set to 1; Docker requires IP forwarding |
| "Too many open files" | `fs.file-max` too low or per-process limits | Raise `fs.file-max` in sysctl; also check `ulimit`/`limits.conf`/systemd `LimitNOFILE` |
| Elasticsearch fails to start | `vm.max_map_count` too low | `sysctl -w vm.max_map_count=262144` and persist |
| Webpack/IDE watch errors | `fs.inotify.max_user_watches` exhausted | Raise to 524288 or higher |
| Config file syntax error | Missing `=` or extra spaces | Format: `key = value` (one per line, `#` for comments) |

## Pain Points

- **Runtime vs persistent.** `sysctl -w` is temporary. `/etc/sysctl.d/*.conf` is persistent. This two-layer model is intentional: test with `-w`, then persist when confirmed. Always do both.

- **Load order matters.** Files load in lexical order: `/usr/lib/sysctl.d/` (vendor) → `/etc/sysctl.d/` (admin) → `/etc/sysctl.conf` (legacy). Later files override earlier ones. Use high numbers (`99-`) for local overrides.

- **Per-process limits are separate.** `fs.file-max` sets the system-wide limit. Per-process limits come from PAM's `limits.conf` or systemd's `LimitNOFILE=`. You need both to be adequate. A process hitting its per-process limit gets "Too many open files" even if the system limit is fine.

- **Some parameters require kernel modules.** `net.netfilter.nf_conntrack_max` only exists after `nf_conntrack` is loaded. If you set it in sysctl.d but the module isn't loaded at boot, you get errors. Load the module first via `/etc/modules-load.d/`.

- **Docker and sysctl.** Docker containers get their own network namespace with separate sysctl values. Host sysctl for `net.ipv4.ip_forward` must be 1 for Docker networking. Container-specific sysctl can be set with `docker run --sysctl`.

- **Don't blindly copy "tuning guides."** Many blog posts suggest aggressive TCP tuning. Wrong values for your workload cause worse performance. Benchmark before and after. Start with the defaults and only tune parameters with measured bottlenecks.

## See Also

- **pam** — `limits.conf` sets per-user resource limits; sysctl sets kernel-wide parameters
- **systemd** — systemd units use `LimitNOFILE=` etc. for per-service limits; `systemd-sysctl.service` loads sysctl configs at boot
- **perf** — performance profiling tool; use to identify bottlenecks before tuning sysctl

## References
See `references/` for:
- `docs.md` — official documentation links
