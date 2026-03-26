# Linux Sysadmin Single Dispatcher Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 137 individual skills with one dispatcher skill + 137 guide files, eliminating skill list pollution.

**Architecture:** A single `skills/sysadmin/SKILL.md` carries a keyword index and dispatcher instructions. Current skill content moves to `guides/{topic}/guide.md` (frontmatter stripped). Claude reads the right guide on demand.

**Tech Stack:** Markdown, Python (migration script), bash

**Spec:** `docs/superpowers/specs/2026-03-26-linux-sysadmin-single-skill-design.md`

---

### Task 1: Write the Migration Script

**Files:**
- Create: `plugins/linux-sysadmin/scripts/migrate-skills-to-guides.py`

This script does the heavy lifting: moves 137 skill directories to `guides/`, renames `SKILL.md` to `guide.md`, strips YAML frontmatter, and adds a markdown heading.

- [ ] **Step 1: Create the migration script**

```python
#!/usr/bin/env python3
"""Migrate linux-sysadmin skills to guides directory.

Moves all skill directories (except sysadmin/) from skills/ to guides/,
renames SKILL.md to guide.md, strips YAML frontmatter, and adds a heading.
"""

import os
import shutil
import sys
import yaml

PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKILLS_DIR = os.path.join(PLUGIN_ROOT, "skills")
GUIDES_DIR = os.path.join(PLUGIN_ROOT, "guides")

# The one skill that stays
KEEP_SKILLS = {"sysadmin"}


def strip_frontmatter_and_add_heading(content: str, topic: str) -> str:
    """Remove YAML frontmatter and add a markdown H1 heading."""
    # Extract name from frontmatter for the heading
    parts = content.split("---", 2)
    if len(parts) >= 3:
        try:
            fm = yaml.safe_load(parts[1])
            name = fm.get("name", topic)
        except yaml.YAMLError:
            name = topic
        body = parts[2].lstrip("\n")
    else:
        name = topic
        body = content

    return f"# {name}\n\n{body}"


def migrate():
    os.makedirs(GUIDES_DIR, exist_ok=True)

    topics = sorted(
        d
        for d in os.listdir(SKILLS_DIR)
        if os.path.isdir(os.path.join(SKILLS_DIR, d)) and d not in KEEP_SKILLS
    )

    moved = 0
    errors = []

    for topic in topics:
        src = os.path.join(SKILLS_DIR, topic)
        dst = os.path.join(GUIDES_DIR, topic)
        skill_md = os.path.join(src, "SKILL.md")

        if not os.path.exists(skill_md):
            errors.append(f"SKIP {topic}: no SKILL.md")
            continue

        # Read and transform SKILL.md
        with open(skill_md) as f:
            content = f.read()
        transformed = strip_frontmatter_and_add_heading(content, topic)

        # Move the directory
        shutil.move(src, dst)

        # Rename SKILL.md -> guide.md with transformed content
        old_path = os.path.join(dst, "SKILL.md")
        new_path = os.path.join(dst, "guide.md")
        with open(new_path, "w") as f:
            f.write(transformed)
        if os.path.exists(old_path) and old_path != new_path:
            os.remove(old_path)

        moved += 1

    print(f"Moved {moved} topics to guides/")
    if errors:
        print("Errors:")
        for e in errors:
            print(f"  {e}")

    return moved, errors


if __name__ == "__main__":
    moved, errors = migrate()
    if errors:
        sys.exit(1)
```

Write this to `plugins/linux-sysadmin/scripts/migrate-skills-to-guides.py`.

- [ ] **Step 2: Commit the migration script**

```bash
git add plugins/linux-sysadmin/scripts/migrate-skills-to-guides.py
git commit -m "feat(linux-sysadmin): add skill-to-guide migration script"
```

---

### Task 2: Run the Migration

**Files:**
- Move: all 137 directories from `skills/` to `guides/`
- Transform: `SKILL.md` -> `guide.md` in each (strip frontmatter, add heading)

- [ ] **Step 1: Verify pre-migration state**

```bash
ls plugins/linux-sysadmin/skills/ | wc -l
# Expected: 137 directories
```

- [ ] **Step 2: Run the migration script**

```bash
cd plugins/linux-sysadmin && python3 scripts/migrate-skills-to-guides.py
```

Expected output: `Moved 137 topics to guides/`

- [ ] **Step 3: Verify post-migration state**

```bash
ls plugins/linux-sysadmin/guides/ | wc -l
# Expected: 137

ls plugins/linux-sysadmin/skills/
# Expected: only sysadmin/

# Verify a guide was transformed correctly
head -5 plugins/linux-sysadmin/guides/docker/guide.md
# Expected: starts with "# docker" then content (no YAML frontmatter)

# Verify references survived the move
ls plugins/linux-sysadmin/guides/docker/references/
# Expected: daemon.json.annotated  dockerfile-patterns.md  docs.md

# Verify no SKILL.md files remain in guides
find plugins/linux-sysadmin/guides -name "SKILL.md" | wc -l
# Expected: 0
```

- [ ] **Step 4: Commit the migration**

```bash
git add plugins/linux-sysadmin/guides/ plugins/linux-sysadmin/skills/
git commit -m "refactor(linux-sysadmin): move 137 skills to guides directory

Each SKILL.md renamed to guide.md with frontmatter stripped.
Reference subdirectories preserved unchanged."
```

---

### Task 3: Create the Dispatcher Skill

**Files:**
- Create: `plugins/linux-sysadmin/skills/sysadmin/SKILL.md`

- [ ] **Step 1: Generate the topic index**

Run this to produce the index table from the guide files (the frontmatter is gone, but we can derive topic names from directory names and the first heading/paragraph):

```bash
python3 -c "
import os
guides = 'plugins/linux-sysadmin/guides'
for topic in sorted(os.listdir(guides)):
    guide = os.path.join(guides, topic, 'guide.md')
    if not os.path.exists(guide):
        continue
    with open(guide) as f:
        lines = f.readlines()
    # Find first non-heading, non-empty line after Identity/Quick Start for a description
    # Or just use the heading
    heading = lines[0].strip().lstrip('# ') if lines else topic
    # Find the ## Identity section to get a one-liner
    desc = ''
    for i, line in enumerate(lines):
        if line.startswith('## Identity') or line.startswith('## Quick Start'):
            # Grab the unit/package line
            for j in range(i+1, min(i+5, len(lines))):
                if lines[j].strip().startswith('- **'):
                    desc = lines[j].strip().lstrip('- ').split(':')[0].replace('**','')
                    break
            break
    print(f'| {topic} | {desc or heading} |')
"
```

Use this output as the basis for the topic index table. But the actual SKILL.md content should be written manually to ensure quality. The table below is pre-generated from the current 137 skills.

- [ ] **Step 2: Create the dispatcher SKILL.md**

Create `plugins/linux-sysadmin/skills/sysadmin/SKILL.md` with this content:

```markdown
---
name: sysadmin
description: >
  Linux system administration knowledge base: 137 per-service guides covering
  daemons, CLI tools, filesystems, containers, networking, security, databases,
  monitoring, backup, and self-hosted applications. MUST consult when installing,
  configuring, troubleshooting, or administering any Linux service or tool.
triggerPhrases:
  # Web & Proxy
  - "nginx"
  - "apache"
  - "caddy"
  - "traefik"
  - "haproxy"
  - "envoy"
  - "kong"
  - "reverse proxy"
  # Containers & Orchestration
  - "docker"
  - "docker compose"
  - "podman"
  - "kubernetes"
  - "helm"
  - "argocd"
  - "buildah"
  - "container"
  # DNS
  - "bind9"
  - "dnsmasq"
  - "coredns"
  - "unbound"
  - "pihole"
  - "dig"
  # Security & Firewall
  - "ufw"
  - "firewalld"
  - "fail2ban"
  - "crowdsec"
  - "wireguard"
  - "openvpn"
  - "tailscale"
  - "sshd"
  - "nmap"
  - "trivy"
  - "vault"
  - "certbot"
  - "openssl"
  # Databases
  - "postgresql"
  - "mariadb"
  - "mysql"
  - "redis"
  - "mongodb"
  - "sqlite"
  - "cassandra"
  - "influxdb"
  # Monitoring & Observability
  - "prometheus"
  - "grafana"
  - "loki"
  - "netdata"
  - "node exporter"
  - "elk"
  - "elasticsearch"
  # System Services
  - "systemd"
  - "journald"
  - "cron"
  - "logrotate"
  - "supervisor"
  # Storage & Filesystems
  - "zfs"
  - "btrfs"
  - "lvm"
  - "ext4"
  - "xfs"
  - "nfs"
  - "samba"
  - "ceph"
  - "glusterfs"
  - "mdadm"
  # Backup
  - "borg"
  - "restic"
  - "rclone"
  - "rsync"
  # Self-Hosted Apps
  - "nextcloud"
  - "gitea"
  - "jellyfin"
  - "immich"
  - "vaultwarden"
  - "keycloak"
  # CLI Tools
  - "tmux"
  - "jq"
  - "curl"
  - "tcpdump"
  - "strace"
  - "htop"
  - "awk"
  - "sed"
  # Virtualization
  - "proxmox"
  - "kvm"
  - "lxc"
  # Mail
  - "postfix"
  - "dovecot"
  # IoT
  - "mosquitto"
  - "zigbee2mqtt"
  - "node-red"
  # Config Management
  - "ansible"
  - "terraform"
  - "packer"
  - "consul"
---

## How to Use This Skill

When a user asks about a Linux service, tool, or filesystem listed in the topic
index below, **read the matching guide file** before responding:

```
Read: ${PLUGIN_ROOT}/guides/{topic}/guide.md
```

Each guide contains: identity (config paths, ports, logs), quick start, key
operations, health checks, common failures, pain points, and cross-references.

Some guides also have a `references/` subdirectory with annotated config files,
cheatsheets, and documentation links. Read those when the user needs deeper
detail on configuration or advanced usage:

```
Read: ${PLUGIN_ROOT}/guides/{topic}/references/<file>
```

For broad "what should I use?" queries, read the `linux-overview` guide first.

## Topic Index

| Topic | Description |
|-------|-------------|
| age | File encryption with age/rage |
| ansible | Agentless automation and config management |
| apache | Apache HTTP Server |
| argocd | Argo CD GitOps for Kubernetes |
| auditd | Linux Audit Framework |
| avahi | mDNS/zeroconf daemon |
| awk-sed | awk and sed stream editors |
| bind-utils | DNS query tools (dig, nslookup, host) |
| bind9 | BIND9 authoritative DNS server |
| borg | Deduplicated encrypted backups |
| btop | Interactive terminal resource monitor |
| btrfs | Btrfs filesystem (snapshots, RAID, compression) |
| buildah | Daemonless container image building |
| caddy | Caddy web server (automatic HTTPS) |
| cassandra | Apache Cassandra distributed database |
| ceph | Ceph distributed storage |
| certbot | Let's Encrypt certificate management |
| chrony | NTP time synchronization |
| cloud-cli | AWS CLI, Azure CLI, gcloud |
| consul | HashiCorp Consul service discovery |
| container-registry | Docker Registry and Harbor |
| coredns | CoreDNS server |
| cron | cron daemon and crontab |
| crowdsec | Collaborative intrusion prevention |
| curl-wget | curl and wget HTTP clients |
| df | Disk space usage reporting |
| dhcp | ISC DHCP and Kea DHCP servers |
| dmesg | Kernel ring buffer messages |
| dnsmasq | DNS forwarder and DHCP server |
| docker | Docker container runtime |
| docker-compose | Docker Compose multi-container orchestration |
| dovecot | Dovecot IMAP/POP3 server |
| elk-stack | Elasticsearch, Logstash, Kibana |
| envoy | Envoy L4/L7 proxy |
| etcd | Distributed key-value store |
| exfat-ntfs | Cross-platform filesystem management |
| ext4 | ext4 filesystem |
| fail2ban | Intrusion prevention via log monitoring |
| falco | Cloud-native runtime security |
| fdisk-parted | Disk partition management |
| firewalld | Zone-based firewall (nftables) |
| gitea | Self-hosted Git service |
| glances | All-in-one system monitor |
| glusterfs | GlusterFS distributed filesystem |
| gotify | Self-hosted push notifications |
| grafana | Grafana dashboards and alerting |
| ha-postgresql | High-availability PostgreSQL (Patroni) |
| haproxy | HAProxy load balancer |
| helm | Helm Kubernetes package manager |
| htop | Interactive process viewer |
| immich | Self-hosted photo/video management |
| influxdb | InfluxDB time series database |
| iostat | CPU and disk I/O statistics |
| iotop | Per-process disk I/O monitor |
| iperf3 | Network throughput measurement |
| jellyfin | Jellyfin media server |
| journald | systemd journal log management |
| jq | JSON processor |
| kafka | Apache Kafka event streaming |
| keycloak | Keycloak identity management |
| kong | Kong API Gateway |
| kubernetes | Kubernetes container orchestration |
| kubernetes-stack | Production Kubernetes platform |
| kvm-libvirt | KVM/libvirt virtualization |
| linux-overview | Service and tool discovery index |
| logrotate | Log file rotation |
| loki | Grafana Loki log aggregation |
| lsblk | Block device listing |
| lsof | Open file descriptor listing |
| lvm | Logical Volume Manager |
| lxc-lxd | LXC/LXD system containers |
| mail-stack | Complete mail server deployment |
| mariadb | MariaDB/MySQL database |
| mdadm | Linux software RAID |
| minio | MinIO S3-compatible object storage |
| mongodb | MongoDB document database |
| mosquitto | Eclipse Mosquitto MQTT broker |
| mtr | Combined traceroute and ping |
| ncdu | Interactive disk usage explorer |
| netdata | Real-time monitoring agent |
| nextcloud | Self-hosted cloud storage |
| nfs | NFS server and client |
| nginx | nginx web server and reverse proxy |
| nmap | Network scanner |
| node-exporter | Prometheus Node Exporter |
| node-red | Node-RED flow automation |
| node-runtime | Node.js runtime management |
| observability-stack | Prometheus + Grafana + Loki stack |
| opendkim | OpenDKIM DKIM signing |
| openssl-cli | openssl certificate and TLS operations |
| openvpn | OpenVPN server and client |
| osquery | SQL-based endpoint monitoring |
| package-managers | apt, dnf, pacman, apk |
| packer | HashiCorp Packer image automation |
| patroni | Patroni PostgreSQL HA clusters |
| perf | Linux kernel performance profiling |
| pihole | Pi-hole DNS ad blocker |
| podman | Podman rootless containers |
| postfix | Postfix mail transfer agent |
| postgresql | PostgreSQL database server |
| prometheus | Prometheus monitoring system |
| proxmox | Proxmox VE hypervisor |
| python-runtime | Python runtime management |
| rabbitmq | RabbitMQ message broker |
| rclone | Cloud storage management |
| redis | Redis in-memory data store |
| restic | restic backup tool |
| ripgrep | ripgrep fast recursive search |
| rsync | File synchronization and backup |
| rust-runtime | Rust runtime management |
| samba | Samba file server |
| smartctl | SMART disk health monitoring |
| sqlite | SQLite embedded database |
| ss | Socket statistics (replaces netstat) |
| ssh-keygen | SSH key management |
| sshd | OpenSSH server |
| step-ca | Smallstep private CA |
| strace | System call tracing |
| supervisor | Supervisor process manager |
| systemd | systemd init and service manager |
| tailscale | Tailscale mesh VPN |
| tc | Linux traffic control / shaping |
| tcpdump | Packet capture and analysis |
| terraform | Terraform/OpenTofu IaC |
| tmux | tmux terminal multiplexer |
| traefik | Traefik reverse proxy |
| trivy | Container vulnerability scanner |
| ufw | Uncomplicated Firewall |
| unbound | Unbound recursive DNS resolver |
| vault | HashiCorp Vault secrets management |
| vaultwarden | Vaultwarden credential manager |
| vmstat | Virtual memory statistics |
| wireguard | WireGuard VPN |
| xfs | XFS filesystem |
| zfs | ZFS (OpenZFS) storage |
| zigbee2mqtt | Zigbee2MQTT bridge |
| zwave-js | Z-Wave JS controller |
```

- [ ] **Step 3: Commit the dispatcher skill**

```bash
git add plugins/linux-sysadmin/skills/sysadmin/
git commit -m "feat(linux-sysadmin): add single dispatcher skill with topic index"
```

---

### Task 4: Update Supporting Files

**Files:**
- Modify: `plugins/linux-sysadmin/scripts/sysadmin-context.sh`
- Modify: `plugins/linux-sysadmin/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update the SessionStart hook script**

In `plugins/linux-sysadmin/scripts/sysadmin-context.sh`, replace the context message (the `cat <<'CONTEXT'` heredoc) with:

```bash
cat <<'CONTEXT'
[linux-sysadmin] Sysadmin working directory detected. Before installing, configuring, or troubleshooting any Linux service, invoke Skill("linux-sysadmin:sysadmin"). It contains a topic index of 137 service guides and will load the right one.
CONTEXT
```

- [ ] **Step 2: Bump plugin.json version to 2.0.0**

This is a breaking architectural change (skills removed, replaced with guides). Update `plugins/linux-sysadmin/.claude-plugin/plugin.json`:

```json
{
  "name": "linux-sysadmin",
  "version": "2.0.0",
  "description": "Linux system administration knowledge base: 137 per-service guides covering daemons, CLI tools, and filesystems with annotated configs, cheatsheets, and a guided /sysadmin stack design workflow",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/linux-sysadmin"
}
```

- [ ] **Step 3: Update marketplace.json version**

In `.claude-plugin/marketplace.json`, update the linux-sysadmin entry version to `"2.0.0"`. The description stays the same.

- [ ] **Step 4: Commit supporting file updates**

```bash
git add plugins/linux-sysadmin/scripts/sysadmin-context.sh \
       plugins/linux-sysadmin/.claude-plugin/plugin.json \
       .claude-plugin/marketplace.json
git commit -m "chore(linux-sysadmin): update hook, version, and marketplace for v2.0.0"
```

---

### Task 5: Update Documentation

**Files:**
- Modify: `plugins/linux-sysadmin/README.md`
- Modify: `plugins/linux-sysadmin/CHANGELOG.md`

- [ ] **Step 1: Update README.md**

Key changes to `plugins/linux-sysadmin/README.md`:

1. **Summary paragraph** (line 7-9): Change "This plugin gives Claude that domain knowledge as skills: one per service" to describe the single-skill + guides architecture.

2. **Principles [P2]** (line 19): Change from "One Skill, One Service" to "One Guide, One Service" and update the description to reflect guides instead of skills.

3. **How It Works mermaid diagram** (lines 49-61): Update to show the dispatcher skill loading guides instead of individual service skills triggering directly.

4. **Skills table** (lines 93-101): Replace the two-row table (linux-overview + 136 per-service) with a single row for the `sysadmin` dispatcher skill. Note that it covers all 137 topics via guide files.

5. **Known Issues** (lines 116-117): Remove the `linux-overview trigger breadth` issue — the dispatcher skill replaces this pattern. Remove the `[P2] tension` note about awk-sed/curl-wget — P2 is now about guides, not skills.

- [ ] **Step 2: Update CHANGELOG.md**

Add a new `## [2.0.0] - 2026-03-26` section at the top (after the format header):

```markdown
## [2.0.0] - 2026-03-26

### Changed
- **Architecture: single dispatcher skill replaces 137 individual skills.** The `sysadmin` skill contains a topic index of all 137 services and loads the right guide file on demand. This eliminates skill list pollution while preserving all service knowledge.
- Skill content moved to `guides/{topic}/guide.md` (YAML frontmatter stripped, content preserved verbatim)
- SessionStart hook now references the single `linux-sysadmin:sysadmin` skill
- README updated to reflect new architecture

### Removed
- 137 individual per-service skills (replaced by guide files under `guides/`)
```

- [ ] **Step 3: Commit documentation updates**

```bash
git add plugins/linux-sysadmin/README.md plugins/linux-sysadmin/CHANGELOG.md
git commit -m "docs(linux-sysadmin): update README and CHANGELOG for v2.0.0 architecture"
```

---

### Task 6: Validate and Clean Up

- [ ] **Step 1: Run marketplace validation**

```bash
./scripts/validate-marketplace.sh
```

Expected: PASS with no errors.

- [ ] **Step 2: Verify skill count**

```bash
find plugins/linux-sysadmin/skills -name "SKILL.md" | wc -l
# Expected: 1

find plugins/linux-sysadmin/guides -name "guide.md" | wc -l
# Expected: 137
```

- [ ] **Step 3: Verify no orphaned files**

```bash
# No SKILL.md in guides/
find plugins/linux-sysadmin/guides -name "SKILL.md" | wc -l
# Expected: 0

# All references directories survived
find plugins/linux-sysadmin/guides -type d -name "references" | wc -l
# Expected: 136 (linux-overview has no references/)
```

- [ ] **Step 4: Spot-check a few guides**

```bash
# Docker guide starts with heading, no frontmatter
head -3 plugins/linux-sysadmin/guides/docker/guide.md
# Expected: # docker

# Nginx references intact
ls plugins/linux-sysadmin/guides/nginx/references/

# linux-overview guide exists
test -f plugins/linux-sysadmin/guides/linux-overview/guide.md && echo OK
```

- [ ] **Step 5: Delete the migration script**

The migration script is single-use. Remove it:

```bash
rm plugins/linux-sysadmin/scripts/migrate-skills-to-guides.py
git add plugins/linux-sysadmin/scripts/migrate-skills-to-guides.py
git commit -m "chore(linux-sysadmin): remove single-use migration script"
```
