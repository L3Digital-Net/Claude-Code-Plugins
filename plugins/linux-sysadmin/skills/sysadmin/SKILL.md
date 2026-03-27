---
name: sysadmin
description: >
  Linux system administration knowledge base: 163 per-service guides covering
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
  - "containerd"
  - "skopeo"
  - "kubernetes"
  - "k3s"
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
  - "nftables"
  - "iptables"
  - "fail2ban"
  - "crowdsec"
  - "aide"
  - "lynis"
  - "rkhunter"
  - "clamav"
  - "apparmor"
  - "selinux"
  - "pam"
  - "wireguard"
  - "openvpn"
  - "tailscale"
  - "sshd"
  - "nmap"
  - "trivy"
  - "vault"
  - "certbot"
  - "acme.sh"
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
  - "uptime kuma"
  - "clickhouse"
  # System Services
  - "systemd"
  - "journald"
  - "cron"
  - "logrotate"
  - "supervisor"
  - "rsyslog"
  - "sysctl"
  - "lldpd"
  - "nut"
  - "ups"
  - "cockpit"
  - "unattended-upgrades"
  # Networking
  - "iproute2"
  - "ip addr"
  - "ip route"
  - "ip link"
  - "networkmanager"
  - "nmcli"
  - "socat"
  - "netcat"
  # Infrastructure Management
  - "netbox"
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
  - "authentik"
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
| acme-sh | acme.sh ACME client for TLS certificates |
| age | File encryption with age/rage |
| aide | AIDE file integrity monitoring |
| ansible | Agentless automation and config management |
| apache | Apache HTTP Server |
| apparmor | AppArmor mandatory access control (Debian/Ubuntu) |
| argocd | Argo CD GitOps for Kubernetes |
| authentik | Authentik identity provider (OAuth2, SAML, LDAP) |
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
| clamav | ClamAV antivirus scanner |
| clickhouse | ClickHouse columnar analytics database |
| cloud-cli | AWS CLI, Azure CLI, gcloud |
| cockpit | Cockpit web-based server management |
| containerd | containerd container runtime |
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
| iproute2 | ip command networking toolkit (addr, route, link, neigh) |
| iptables | iptables legacy packet filter |
| iostat | CPU and disk I/O statistics |
| iotop | Per-process disk I/O monitor |
| iperf3 | Network throughput measurement |
| jellyfin | Jellyfin media server |
| journald | systemd journal log management |
| jq | JSON processor |
| k3s | K3s lightweight Kubernetes distribution |
| kafka | Apache Kafka event streaming |
| keycloak | Keycloak identity management |
| kong | Kong API Gateway |
| kubernetes | Kubernetes container orchestration |
| kubernetes-stack | Production Kubernetes platform |
| kvm-libvirt | KVM/libvirt virtualization |
| linux-overview | Service and tool discovery index |
| lldpd | LLDP network topology discovery daemon |
| logrotate | Log file rotation |
| loki | Grafana Loki log aggregation |
| lsblk | Block device listing |
| lsof | Open file descriptor listing |
| lvm | Logical Volume Manager |
| lxc-lxd | LXC/LXD system containers |
| lynis | Lynis security auditing tool |
| mail-stack | Complete mail server deployment |
| mariadb | MariaDB/MySQL database |
| mdadm | Linux software RAID |
| minio | MinIO S3-compatible object storage |
| mongodb | MongoDB document database |
| mosquitto | Eclipse Mosquitto MQTT broker |
| mtr | Combined traceroute and ping |
| ncdu | Interactive disk usage explorer |
| netbox | NetBox IPAM and datacenter infrastructure management |
| netdata | Real-time monitoring agent |
| networkmanager | NetworkManager network configuration daemon |
| nextcloud | Self-hosted cloud storage |
| nfs | NFS server and client |
| nftables | nftables packet filter framework |
| nginx | nginx web server and reverse proxy |
| nmap | Network scanner |
| node-exporter | Prometheus Node Exporter |
| nut | Network UPS Tools (UPS monitoring and shutdown) |
| node-red | Node-RED flow automation |
| node-runtime | Node.js runtime management |
| observability-stack | Prometheus + Grafana + Loki stack |
| opendkim | OpenDKIM DKIM signing |
| openssl-cli | openssl certificate and TLS operations |
| openvpn | OpenVPN server and client |
| osquery | SQL-based endpoint monitoring |
| package-managers | apt, dnf, pacman, apk |
| packer | HashiCorp Packer image automation |
| pam | PAM Pluggable Authentication Modules |
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
| rkhunter | Rootkit Hunter rootkit and backdoor scanner |
| ripgrep | ripgrep fast recursive search |
| rsyslog | rsyslog centralized logging daemon |
| rsync | File synchronization and backup |
| rust-runtime | Rust runtime management |
| samba | Samba file server |
| selinux | SELinux mandatory access control (RHEL/Fedora) |
| skopeo | Skopeo container image inspection and transport |
| smartctl | SMART disk health monitoring |
| socat | socat multipurpose network relay |
| sqlite | SQLite embedded database |
| ss | Socket statistics (replaces netstat) |
| ssh-keygen | SSH key management |
| sshd | OpenSSH server |
| step-ca | Smallstep private CA |
| strace | System call tracing |
| supervisor | Supervisor process manager |
| sysctl | sysctl kernel parameter tuning |
| systemd | systemd init and service manager |
| tailscale | Tailscale mesh VPN |
| tc | Linux traffic control / shaping |
| tcpdump | Packet capture and analysis |
| terraform | Terraform/OpenTofu IaC |
| tmux | tmux terminal multiplexer |
| traefik | Traefik reverse proxy |
| trivy | Container vulnerability scanner |
| ufw | Uncomplicated Firewall |
| unattended-upgrades | Automated security updates (Debian/Ubuntu) |
| unbound | Unbound recursive DNS resolver |
| uptime-kuma | Uptime Kuma self-hosted uptime monitoring |
| vault | HashiCorp Vault secrets management |
| vaultwarden | Vaultwarden credential manager |
| vmstat | Virtual memory statistics |
| wireguard | WireGuard VPN |
| xfs | XFS filesystem |
| zfs | ZFS (OpenZFS) storage |
| zigbee2mqtt | Zigbee2MQTT bridge |
| zwave-js | Z-Wave JS controller |
