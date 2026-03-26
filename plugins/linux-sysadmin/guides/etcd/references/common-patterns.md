# etcd Common Patterns

Commands assume `ETCDCTL_API=3` (the default since etcd 3.4). Replace placeholder
IPs, paths, and credentials with your own values.

---

## 1. Static Three-Node Cluster Setup

The most common production bootstrap method. All member addresses are known in advance.

```bash
# Node 1 (10.0.1.10)
etcd --name node1 \
  --data-dir /var/lib/etcd \
  --listen-client-urls http://10.0.1.10:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.10:2379 \
  --listen-peer-urls http://10.0.1.10:2380 \
  --initial-advertise-peer-urls http://10.0.1.10:2380 \
  --initial-cluster node1=http://10.0.1.10:2380,node2=http://10.0.1.11:2380,node3=http://10.0.1.12:2380 \
  --initial-cluster-token my-cluster \
  --initial-cluster-state new

# Node 2 (10.0.1.11) — same flags, change --name and IPs
etcd --name node2 \
  --data-dir /var/lib/etcd \
  --listen-client-urls http://10.0.1.11:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.11:2379 \
  --listen-peer-urls http://10.0.1.11:2380 \
  --initial-advertise-peer-urls http://10.0.1.11:2380 \
  --initial-cluster node1=http://10.0.1.10:2380,node2=http://10.0.1.11:2380,node3=http://10.0.1.12:2380 \
  --initial-cluster-token my-cluster \
  --initial-cluster-state new

# Node 3 (10.0.1.12) — same pattern
etcd --name node3 \
  --data-dir /var/lib/etcd \
  --listen-client-urls http://10.0.1.12:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.12:2379 \
  --listen-peer-urls http://10.0.1.12:2380 \
  --initial-advertise-peer-urls http://10.0.1.12:2380 \
  --initial-cluster node1=http://10.0.1.10:2380,node2=http://10.0.1.11:2380,node3=http://10.0.1.12:2380 \
  --initial-cluster-token my-cluster \
  --initial-cluster-state new
```

Verify the cluster:

```bash
etcdctl --endpoints=http://10.0.1.10:2379 member list -w table
etcdctl --endpoints=http://10.0.1.10:2379 endpoint status --cluster -w table
```

### YAML Config File Alternative

Instead of flags, create `/etc/etcd/etcd.conf.yml` per node:

```yaml
name: node1
data-dir: /var/lib/etcd
listen-client-urls: http://10.0.1.10:2379,http://127.0.0.1:2379
advertise-client-urls: http://10.0.1.10:2379
listen-peer-urls: http://10.0.1.10:2380
initial-advertise-peer-urls: http://10.0.1.10:2380
initial-cluster: node1=http://10.0.1.10:2380,node2=http://10.0.1.11:2380,node3=http://10.0.1.12:2380
initial-cluster-token: my-cluster
initial-cluster-state: new
auto-compaction-retention: "1"
auto-compaction-mode: periodic
quota-backend-bytes: 8589934592  # 8 GB
```

Start with: `etcd --config-file /etc/etcd/etcd.conf.yml`

---

## 2. TLS — Client and Peer Encryption

Generate certificates with cfssl, openssl, or step-ca. Each member needs its own
server cert with SANs covering its IP and hostname.

### Generate Certs with cfssl (Abridged)

```bash
# CA
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Server cert (include all member IPs and hostnames in the CSR's SANs)
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem \
  -config=ca-config.json -profile=server \
  server-csr.json | cfssljson -bare server

# Peer cert
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem \
  -config=ca-config.json -profile=peer \
  peer-csr.json | cfssljson -bare peer
```

### Start etcd with TLS

```bash
etcd --name node1 \
  --data-dir /var/lib/etcd \
  --cert-file=/etc/etcd/tls/server.pem \
  --key-file=/etc/etcd/tls/server-key.pem \
  --trusted-ca-file=/etc/etcd/tls/ca.pem \
  --client-cert-auth=true \
  --peer-cert-file=/etc/etcd/tls/peer.pem \
  --peer-key-file=/etc/etcd/tls/peer-key.pem \
  --peer-trusted-ca-file=/etc/etcd/tls/ca.pem \
  --peer-client-cert-auth=true \
  --listen-client-urls https://10.0.1.10:2379 \
  --advertise-client-urls https://10.0.1.10:2379 \
  --listen-peer-urls https://10.0.1.10:2380 \
  --initial-advertise-peer-urls https://10.0.1.10:2380 \
  --initial-cluster node1=https://10.0.1.10:2380,node2=https://10.0.1.11:2380,node3=https://10.0.1.12:2380 \
  --initial-cluster-token my-cluster \
  --initial-cluster-state new
```

### etcdctl with TLS

```bash
etcdctl --endpoints=https://10.0.1.10:2379 \
  --cacert=/etc/etcd/tls/ca.pem \
  --cert=/etc/etcd/tls/client.pem \
  --key=/etc/etcd/tls/client-key.pem \
  endpoint health
```

### Quick Auto-TLS (Testing Only)

Self-signed certs generated automatically; 1-year validity, no SAN control:

```bash
etcd --auto-tls --peer-auto-tls \
  --listen-client-urls https://0.0.0.0:2379 \
  --listen-peer-urls https://0.0.0.0:2380
```

---

## 3. Member Management

### Add a Voting Member

```bash
# Step 1: register the new member
etcdctl member add node4 --peer-urls=http://10.0.1.14:2380

# Step 2: start etcd on node4 with --initial-cluster-state=existing
# Use the --initial-cluster value printed by the add command.
etcd --name node4 \
  --data-dir /var/lib/etcd \
  --listen-client-urls http://10.0.1.14:2379,http://127.0.0.1:2379 \
  --advertise-client-urls http://10.0.1.14:2379 \
  --listen-peer-urls http://10.0.1.14:2380 \
  --initial-advertise-peer-urls http://10.0.1.14:2380 \
  --initial-cluster node1=http://10.0.1.10:2380,node2=http://10.0.1.11:2380,node3=http://10.0.1.12:2380,node4=http://10.0.1.14:2380 \
  --initial-cluster-token my-cluster \
  --initial-cluster-state existing
```

### Safer Add via Learner (v3.4+)

Learners receive Raft log entries but do not vote, so adding one never risks quorum.

```bash
etcdctl member add node4 --peer-urls=http://10.0.1.14:2380 --learner
# Start node4 with --initial-cluster-state=existing (same as above)

# After it catches up, promote to a voting member:
etcdctl member promote <member-id>
```

### Remove a Member

```bash
# Get the member ID
etcdctl member list -w table

# Remove it
etcdctl member remove <member-id>
```

### Replace a Failed Member

```bash
# 1. Remove the dead member
etcdctl member remove <old-member-id>

# 2. Add a replacement (use the same or different name/IP)
etcdctl member add replacement --peer-urls=http://10.0.1.15:2380

# 3. Start the replacement with a clean data dir and --initial-cluster-state=existing
```

---

## 4. Key-Value Operations

```bash
# Basic CRUD
etcdctl put /config/db_host "db.internal"
etcdctl put /config/db_port "5432"
etcdctl get /config/db_host
etcdctl get /config/db_host --print-value-only
etcdctl del /config/db_host

# Prefix operations
etcdctl get --prefix /config/
etcdctl del --prefix /config/

# Range query [start, end) — gets keys from /config/a up to but not including /config/z
etcdctl get /config/a /config/z

# Get with limit and sorting
etcdctl get --prefix --limit=5 --sort-by=KEY --order=ASCEND /app/

# Delete with previous value echoed
etcdctl del --prev-kv /config/db_port

# Watch a prefix for real-time changes
etcdctl watch --prefix /config/
# In another terminal: etcdctl put /config/db_host "db2.internal"
# Watch outputs: PUT /config/db_host db2.internal

# Watch from a specific revision (replay history)
etcdctl watch --prefix --rev=1 /config/

# Transactional compare-and-swap
etcdctl txn <<'EOF'
compares:
  value("/config/db_port") = "5432"

success requests (get, put, del):
  put /config/db_port "5433"

failure requests (get, put, del):
  get /config/db_port
EOF
```

### Leases (TTL-Based Key Expiry)

```bash
# Grant a 300-second lease
etcdctl lease grant 300
# lease 694d5765fc71500b granted with TTL(300s)

# Attach a key to the lease — key auto-deletes when lease expires
etcdctl put /session/abc "user123" --lease=694d5765fc71500b

# Check remaining TTL and attached keys
etcdctl lease timetolive --keys 694d5765fc71500b

# Keep a lease alive (sends periodic keep-alives until Ctrl-C)
etcdctl lease keep-alive 694d5765fc71500b

# Explicitly revoke (deletes all attached keys immediately)
etcdctl lease revoke 694d5765fc71500b
```

---

## 5. Snapshot Backup and Restore

### Take a Snapshot

```bash
# From a live member (only needs one member's endpoint)
etcdctl --endpoints=https://10.0.1.10:2379 \
  --cacert=/etc/etcd/tls/ca.pem \
  --cert=/etc/etcd/tls/client.pem \
  --key=/etc/etcd/tls/client-key.pem \
  snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db

# Verify the snapshot
etcdutl snapshot status /backup/etcd-20260314-020000.db -w table
```

### Restore a Single Node

```bash
# Stop etcd
sudo systemctl stop etcd

# Restore into a new data dir
etcdutl snapshot restore /backup/etcd-20260314-020000.db \
  --data-dir /var/lib/etcd-restored

# Replace the old data dir
sudo mv /var/lib/etcd /var/lib/etcd-old
sudo mv /var/lib/etcd-restored /var/lib/etcd

# Start etcd
sudo systemctl start etcd
```

### Restore a Three-Node Cluster

Each member must restore the same snapshot independently with its own identity.

```bash
# On node1
etcdutl snapshot restore /backup/etcd-snapshot.db \
  --name node1 \
  --data-dir /var/lib/etcd \
  --initial-cluster node1=https://10.0.1.10:2380,node2=https://10.0.1.11:2380,node3=https://10.0.1.12:2380 \
  --initial-cluster-token my-cluster \
  --initial-advertise-peer-urls https://10.0.1.10:2380

# On node2
etcdutl snapshot restore /backup/etcd-snapshot.db \
  --name node2 \
  --data-dir /var/lib/etcd \
  --initial-cluster node1=https://10.0.1.10:2380,node2=https://10.0.1.11:2380,node3=https://10.0.1.12:2380 \
  --initial-cluster-token my-cluster \
  --initial-advertise-peer-urls https://10.0.1.11:2380

# On node3
etcdutl snapshot restore /backup/etcd-snapshot.db \
  --name node3 \
  --data-dir /var/lib/etcd \
  --initial-cluster node1=https://10.0.1.10:2380,node2=https://10.0.1.11:2380,node3=https://10.0.1.12:2380 \
  --initial-cluster-token my-cluster \
  --initial-advertise-peer-urls https://10.0.1.12:2380

# Start etcd on all three nodes
```

### Kubernetes Restore with Revision Bump

Prevents Kubernetes watch cache invalidation after restore:

```bash
etcdutl snapshot restore /backup/etcd-snapshot.db \
  --bump-revision 1000000000 \
  --mark-compacted \
  --data-dir /var/lib/etcd
```

---

## 6. Authentication and RBAC

etcd RBAC is disabled by default. Enable it only after creating the `root` user, which
has full administrative privileges.

```bash
# Create the root user (required before enabling auth)
etcdctl user add root
# Enter password when prompted

# Enable authentication
etcdctl auth enable

# All subsequent commands require credentials
etcdctl --user root:<password> user list
```

### Create Users and Roles

```bash
# Create a role with read-only access to /app/ prefix
etcdctl --user root:<password> role add app-reader
etcdctl --user root:<password> role grant-permission app-reader read /app/ --prefix=true

# Create a role with read-write access to /app/ prefix
etcdctl --user root:<password> role add app-writer
etcdctl --user root:<password> role grant-permission app-writer readwrite /app/ --prefix=true

# Create a user and assign the role
etcdctl --user root:<password> user add appuser
etcdctl --user root:<password> user grant-role appuser app-reader

# Verify
etcdctl --user root:<password> role get app-reader
etcdctl --user root:<password> user get appuser
```

### TLS Common Name Authentication

When `--client-cert-auth=true` is set, the CN field of a client certificate maps
to an etcd user. No password needed; the TLS handshake authenticates the client.

```bash
# Create a user matching the client cert's CN (no password)
etcdctl --user root:<password> user add myservice --no-password
etcdctl --user root:<password> user grant-role myservice app-writer

# Client authenticates via cert — CN "myservice" maps to etcd user "myservice"
etcdctl --endpoints=https://10.0.1.10:2379 \
  --cacert=/etc/etcd/tls/ca.pem \
  --cert=/etc/etcd/tls/myservice.pem \
  --key=/etc/etcd/tls/myservice-key.pem \
  put /app/status "running"
```

### Disable Authentication

```bash
etcdctl --user root:<password> auth disable
```

---

## 7. Compaction and Defragmentation

Compaction removes old revisions of keys. Defragmentation reclaims the disk space
freed by compaction. Neither happens automatically unless configured.

### Auto-Compaction (Recommended for Production)

Set at startup; no manual intervention needed:

```bash
# Keep 1 hour of history, compact periodically
etcd --auto-compaction-mode=periodic --auto-compaction-retention=1h

# Keep 1000 revisions, compact when exceeded
etcd --auto-compaction-mode=revision --auto-compaction-retention=1000
```

### Manual Compaction and Defrag

```bash
# Get current revision
rev=$(etcdctl endpoint status -w json | python3 -c \
  "import sys,json; print(json.load(sys.stdin)[0]['Status']['header']['revision'])")

# Compact everything before the current revision
etcdctl compact "$rev"

# Defragment all cluster members (blocks reads/writes per member during defrag)
etcdctl defrag --cluster

# Or defragment offline (etcd must be stopped on the target node)
sudo systemctl stop etcd
etcdutl defrag --data-dir /var/lib/etcd
sudo systemctl start etcd
```

### Recover from NOSPACE Alarm

```bash
# 1. Get current revision
rev=$(etcdctl endpoint status -w json | python3 -c \
  "import sys,json; print(json.load(sys.stdin)[0]['Status']['header']['revision'])")

# 2. Compact old revisions
etcdctl compact "$rev"

# 3. Defragment to reclaim space
etcdctl defrag --cluster

# 4. Disarm the alarm to re-enable writes
etcdctl alarm disarm

# 5. Verify writes work
etcdctl put test-key "recovery-ok" && etcdctl del test-key
```

---

## 8. Kubernetes etcd Administration

### Kubernetes etcd TLS Paths (kubeadm Default)

```
/etc/kubernetes/pki/etcd/ca.crt          # etcd CA certificate
/etc/kubernetes/pki/etcd/ca.key          # etcd CA key
/etc/kubernetes/pki/etcd/server.crt      # etcd server cert
/etc/kubernetes/pki/etcd/server.key      # etcd server key
/etc/kubernetes/pki/etcd/peer.crt        # etcd peer cert
/etc/kubernetes/pki/etcd/peer.key        # etcd peer key
/etc/kubernetes/pki/etcd/healthcheck-client.crt
/etc/kubernetes/pki/etcd/healthcheck-client.key
/etc/kubernetes/pki/apiserver-etcd-client.crt   # kube-apiserver client cert
/etc/kubernetes/pki/apiserver-etcd-client.key
```

### Common etcdctl Wrapper for Kubernetes

```bash
# Alias for kubeadm-managed etcd (adjust paths for your distribution)
alias ketcdctl='etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key'

ketcdctl member list -w table
ketcdctl endpoint health --cluster -w table
ketcdctl endpoint status --cluster -w table
```

### Backup Kubernetes etcd

```bash
# Take a snapshot
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /backup/k8s-etcd-$(date +%Y%m%d-%H%M%S).db

# Verify
etcdutl snapshot status /backup/k8s-etcd-*.db -w table
```

### Restore Kubernetes etcd (Single Control Plane)

```bash
# 1. Stop the API server and etcd (kubeadm runs them as static pods)
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# 2. Wait for pods to stop
crictl ps | grep -E 'etcd|apiserver'

# 3. Back up the old data dir
sudo mv /var/lib/etcd /var/lib/etcd-old

# 4. Restore from snapshot
sudo etcdutl snapshot restore /backup/k8s-etcd-snapshot.db \
  --data-dir /var/lib/etcd \
  --bump-revision 1000000000 \
  --mark-compacted

# 5. Restore the static pod manifests
sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# 6. Wait for pods to restart and verify
kubectl get nodes
ketcdctl endpoint health
```

### Inspect Kubernetes Resources in etcd

```bash
# List all key prefixes (shows K8s resource types stored)
ketcdctl get / --prefix --keys-only | head -50

# Count keys by resource type
ketcdctl get / --prefix --keys-only | cut -d'/' -f1-4 | sort | uniq -c | sort -rn | head -20

# Read a specific resource (output is protobuf, not human-readable YAML)
ketcdctl get /registry/pods/default/my-pod
```

---

## 9. systemd Unit File

```ini
[Unit]
Description=etcd distributed key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
Type=notify
User=etcd
Group=etcd
ExecStart=/usr/local/bin/etcd --config-file /etc/etcd/etcd.conf.yml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin etcd
sudo mkdir -p /var/lib/etcd /etc/etcd/tls
sudo chown etcd:etcd /var/lib/etcd
```

---

## 10. Monitoring

etcd exposes Prometheus metrics at `/metrics` on the client port (2379) by default,
or on a dedicated port via `--listen-metrics-urls`.

```bash
# Quick check of key metrics via curl
curl -s http://127.0.0.1:2379/metrics | grep -E '^etcd_server_has_leader'
curl -s http://127.0.0.1:2379/metrics | grep -E '^etcd_mvcc_db_total_size'
curl -s http://127.0.0.1:2379/metrics | grep -E '^etcd_disk_wal_fsync_duration'
```

Key metrics to alert on:

| Metric | Meaning | Alert threshold |
|--------|---------|-----------------|
| `etcd_server_has_leader` | 1 = has leader, 0 = no leader | Alert if 0 for >30s |
| `etcd_mvcc_db_total_size_in_bytes` | Total DB file size (includes fragmentation) | Alert if approaching `--quota-backend-bytes` |
| `etcd_mvcc_db_total_size_in_use_in_bytes` | Actual data size after compaction | Compare with total to gauge fragmentation |
| `etcd_disk_wal_fsync_duration_seconds` | WAL fsync latency | Alert if p99 >10ms consistently |
| `etcd_disk_backend_commit_duration_seconds` | Backend commit latency | Alert if p99 >25ms |
| `etcd_network_peer_round_trip_time_seconds` | Peer RTT | Alert if p99 >50ms |
| `etcd_server_proposals_failed_total` | Failed Raft proposals | Alert on sustained increase |
