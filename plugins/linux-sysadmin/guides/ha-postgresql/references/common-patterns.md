# HA PostgreSQL Common Patterns

Full 3-node setup walkthrough. Each section is self-contained with copy-paste-ready configuration.
Adjust IPs, passwords, and paths to match your environment.

Node layout used throughout:

| Node | IP | Roles |
|------|----|-------|
| node1 | 10.0.1.1 | etcd + Patroni + PostgreSQL |
| node2 | 10.0.1.2 | etcd + Patroni + PostgreSQL |
| node3 | 10.0.1.3 | etcd + Patroni + PostgreSQL |
| haproxy | 10.0.1.100 | HAProxy (can also run on one of the above) |

---

## 1. etcd Cluster Setup

Install etcd on all three nodes and configure a static bootstrap cluster.

```bash
# On all 3 nodes
sudo apt-get install -y etcd
```

### etcd config: node1

```bash
# /etc/default/etcd
ETCD_NAME="etcd1"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://10.0.1.1:2380"
ETCD_LISTEN_CLIENT_URLS="http://10.0.1.1:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.1.1:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://10.0.1.1:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://10.0.1.1:2380,etcd2=http://10.0.1.2:2380,etcd3=http://10.0.1.3:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="pg-etcd-cluster"
```

### etcd config: node2

```bash
# /etc/default/etcd
ETCD_NAME="etcd2"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://10.0.1.2:2380"
ETCD_LISTEN_CLIENT_URLS="http://10.0.1.2:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.1.2:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://10.0.1.2:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://10.0.1.1:2380,etcd2=http://10.0.1.2:2380,etcd3=http://10.0.1.3:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="pg-etcd-cluster"
```

### etcd config: node3

```bash
# /etc/default/etcd
ETCD_NAME="etcd3"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://10.0.1.3:2380"
ETCD_LISTEN_CLIENT_URLS="http://10.0.1.3:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.1.3:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://10.0.1.3:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://10.0.1.1:2380,etcd2=http://10.0.1.2:2380,etcd3=http://10.0.1.3:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="pg-etcd-cluster"
```

### Start and verify etcd

```bash
# On all 3 nodes
sudo systemctl enable --now etcd

# Verify cluster health (from any node)
etcdctl endpoint health --cluster \
    --endpoints=http://10.0.1.1:2379,http://10.0.1.2:2379,http://10.0.1.3:2379

# Check member list
etcdctl member list \
    --endpoints=http://10.0.1.1:2379,http://10.0.1.2:2379,http://10.0.1.3:2379
```

---

## 2. Patroni Configuration

Install Patroni and PostgreSQL on all three nodes, then deploy node-specific configs.

```bash
# On all 3 nodes
sudo apt-get install -y postgresql-16 postgresql-client-16
sudo systemctl stop postgresql
sudo systemctl disable postgresql

sudo pip install patroni[etcd3] psycopg2-binary
sudo mkdir -p /etc/patroni
```

### Patroni config: node1

```yaml
# /etc/patroni/patroni.yml (node1)
scope: pg-ha-cluster
namespace: /service/
name: node1

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.0.1.1:8008

etcd3:
  hosts: 10.0.1.1:2379,10.0.1.2:2379,10.0.1.3:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    failsafe_mode: true
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_log_hints: "on"
        wal_keep_size: "1GB"
        max_connections: 200
        shared_buffers: "256MB"
        effective_cache_size: "768MB"
        work_mem: "4MB"
        maintenance_work_mem: "64MB"
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication replicator 10.0.1.0/24 scram-sha-256
    - host all all 10.0.1.0/24 scram-sha-256
    - host all all 0.0.0.0/0 scram-sha-256
  users:
    replicator:
      password: "CHANGE_ME_repl"
      options:
        - replication
    admin:
      password: "CHANGE_ME_admin"
      options:
        - createrole
        - createdb

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.0.1.1:5432
  data_dir: /var/lib/postgresql/16/main
  bin_dir: /usr/lib/postgresql/16/bin
  authentication:
    superuser:
      username: postgres
      password: "CHANGE_ME_super"
    replication:
      username: replicator
      password: "CHANGE_ME_repl"
    rewind:
      username: rewind_user
      password: "CHANGE_ME_rewind"
  parameters:
    unix_socket_directories: "/var/run/postgresql"

watchdog:
  mode: automatic
  device: /dev/watchdog
  safety_margin: 5

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
```

For node2 and node3, copy the same file and change:
- `name: node2` / `name: node3`
- `restapi.connect_address: 10.0.1.2:8008` / `10.0.1.3:8008`
- `postgresql.connect_address: 10.0.1.2:5432` / `10.0.1.3:5432`

### Patroni systemd unit

```ini
# /etc/systemd/system/patroni.service
[Unit]
Description=Patroni - PostgreSQL High Availability
After=syslog.target network.target etcd.service

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni/patroni.yml
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=process
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
```

### Start and verify Patroni

```bash
# Start on node1 first (it will bootstrap the cluster), then node2 and node3
sudo systemctl daemon-reload
sudo systemctl enable --now patroni

# Check cluster state
patronictl -c /etc/patroni/patroni.yml list

# Expected output:
# + Cluster: pg-ha-cluster ---+--------+---------+----+-----------+
# | Member | Host      | Role    | State   | TL | Lag in MB |
# +--------+-----------+---------+---------+----+-----------+
# | node1  | 10.0.1.1  | Leader  | running |  1 |           |
# | node2  | 10.0.1.2  | Replica | running |  1 |         0 |
# | node3  | 10.0.1.3  | Replica | running |  1 |         0 |
# +--------+-----------+---------+---------+----+-----------+
```

---

## 3. HAProxy Configuration

HAProxy routes write traffic to the primary and read traffic across replicas using
Patroni REST API health checks.

```
# /etc/haproxy/haproxy.cfg

global
    log /dev/log local0
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 4096

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    retries 3
    timeout connect 5s
    timeout client  30m
    timeout server  30m

# Stats page for monitoring
listen stats
    bind *:7000
    mode http
    stats enable
    stats uri /
    stats refresh 10s
    stats auth admin:CHANGE_ME_stats

# Read-write connections routed to the primary
listen pg-primary
    bind *:5000
    mode tcp
    option httpchk GET /primary
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server node1 10.0.1.1:5432 maxconn 100 check port 8008
    server node2 10.0.1.2:5432 maxconn 100 check port 8008
    server node3 10.0.1.3:5432 maxconn 100 check port 8008

# Read-only connections distributed across replicas
listen pg-replicas
    bind *:5001
    mode tcp
    balance roundrobin
    option httpchk GET /replica
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server node1 10.0.1.1:5432 maxconn 100 check port 8008
    server node2 10.0.1.2:5432 maxconn 100 check port 8008
    server node3 10.0.1.3:5432 maxconn 100 check port 8008
```

```bash
# Validate and start
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl enable --now haproxy

# Test write connection
psql -h 10.0.1.100 -p 5000 -U admin -d postgres -c "SELECT pg_is_in_recovery();"
# Returns: f (false = primary)

# Test read connection
psql -h 10.0.1.100 -p 5001 -U admin -d postgres -c "SELECT pg_is_in_recovery();"
# Returns: t (true = replica)

# HAProxy stats: http://10.0.1.100:7000/
```

---

## 4. PgBouncer Connection Pooling (Optional)

PgBouncer reduces the number of PostgreSQL backend connections. Install on each
database node between HAProxy and PostgreSQL.

```bash
sudo apt-get install -y pgbouncer
```

```ini
# /etc/pgbouncer/pgbouncer.ini
[databases]
* = host=127.0.0.1 port=5432

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
server_lifetime = 3600
server_idle_timeout = 600
log_connections = 0
log_disconnections = 0
stats_period = 60
admin_users = postgres
```

```bash
# /etc/pgbouncer/userlist.txt
# Format: "username" "password-hash"
# Generate scram-sha-256 hash:
psql -h 127.0.0.1 -U postgres -c "SELECT concat('\"', usename, '\" \"', passwd, '\"') FROM pg_shadow WHERE usename IN ('admin', 'replicator', 'postgres');"
```

When using PgBouncer, change HAProxy server lines to point at port 6432 instead of 5432:

```
server node1 10.0.1.1:6432 maxconn 100 check port 8008
```

---

## 5. Monitoring Setup

### Prometheus scrape config for Patroni

```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: patroni
    metrics_path: /metrics
    static_configs:
      - targets:
          - 10.0.1.1:8008
          - 10.0.1.2:8008
          - 10.0.1.3:8008
```

### Key alerts

```yaml
# Patroni alert rules (Prometheus)
groups:
  - name: patroni
    rules:
      - alert: PatroniNoLeader
        expr: max(patroni_master) < 1
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "No Patroni leader detected"

      - alert: PatroniReplicaLag
        expr: patroni_xlog_replayed_location - patroni_xlog_received_location > 16777216
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Patroni replica lag exceeds 16 MB"

      - alert: PatroniPostgresDown
        expr: patroni_postgres_running == 0
        for: 15s
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is down on {{ $labels.instance }}"
```

### HAProxy stats

HAProxy exposes a stats page at `http://haproxy-host:7000/` (configured in section 3).
The stats page shows:
- Backend server health (green = UP, red = DOWN)
- Current connections per server
- Bytes in/out
- Connection error counts

For Prometheus scraping, add the HAProxy exporter or use the built-in Prometheus endpoint
(HAProxy 2.4+): add `http-request use-service prometheus-exporter if { path /metrics }` to a
frontend section.

---

## 6. Failover Testing

Validate that automatic failover works before going to production.

```bash
# 1. Note the current leader
patronictl -c /etc/patroni/patroni.yml list

# 2. Simulate leader failure (stop Patroni on the leader)
sudo systemctl stop patroni    # on the leader node

# 3. Watch the cluster converge (from another node)
patronictl -c /etc/patroni/patroni.yml list --watch 2

# Expected: within 30 seconds (ttl), a new leader is elected.
# HAProxy routes writes to the new leader within 3-10 seconds.

# 4. Verify write access through HAProxy
psql -h 10.0.1.100 -p 5000 -U admin -d postgres \
    -c "CREATE TABLE failover_test (id serial, ts timestamp default now()); INSERT INTO failover_test DEFAULT VALUES; SELECT * FROM failover_test;"

# 5. Restart the old leader — it rejoins as a replica
sudo systemctl start patroni
patronictl -c /etc/patroni/patroni.yml list

# 6. Clean up
psql -h 10.0.1.100 -p 5000 -U admin -d postgres -c "DROP TABLE failover_test;"
```

---

## 7. etcd Maintenance

etcd requires periodic maintenance to prevent unbounded growth.

```bash
# Check cluster health
etcdctl endpoint health --cluster \
    --endpoints=http://10.0.1.1:2379,http://10.0.1.2:2379,http://10.0.1.3:2379

# Check DB size (should stay under 2 GB; default quota is 2 GB)
etcdctl endpoint status --cluster \
    --endpoints=http://10.0.1.1:2379,http://10.0.1.2:2379,http://10.0.1.3:2379 \
    -w table

# Compact old revisions (get current revision first)
REV=$(etcdctl endpoint status --endpoints=http://10.0.1.1:2379 -w json | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['Status']['header']['revision'])")
etcdctl compact $REV --endpoints=http://10.0.1.1:2379

# Defragment all nodes (run during low-traffic period)
etcdctl defrag --cluster \
    --endpoints=http://10.0.1.1:2379,http://10.0.1.2:2379,http://10.0.1.3:2379

# Snapshot for backup
etcdctl snapshot save /backups/etcd-$(date +%Y%m%d).db \
    --endpoints=http://10.0.1.1:2379
etcdctl snapshot status /backups/etcd-$(date +%Y%m%d).db -w table
```

### Cron job for etcd snapshots

```bash
# /etc/cron.d/etcd-backup
0 */6 * * * root etcdctl snapshot save /backups/etcd-$(date +\%Y\%m\%d-\%H\%M).db --endpoints=http://127.0.0.1:2379 && find /backups -name 'etcd-*.db' -mtime +7 -delete
```
