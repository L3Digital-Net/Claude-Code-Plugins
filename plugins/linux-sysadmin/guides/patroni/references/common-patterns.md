# Patroni Common Patterns

Each section is a standalone task with copy-paste-ready commands and configuration snippets.

---

## 1. Minimal Bootstrap Configuration (etcd)

A three-node Patroni cluster with etcd as the DCS. Each node gets its own
`patroni.yml` with a unique `name` and `connect_address`.

```yaml
# /etc/patroni/patroni.yml (node1 example)
scope: pg-cluster          # cluster name — same on all nodes
namespace: /service/       # DCS key prefix
name: node1                # unique per node

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.0.1.1:8008

etcd3:
  hosts: 10.0.1.10:2379,10.0.1.11:2379,10.0.1.12:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576   # 1 MB in bytes
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_log_hints: "on"
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication replicator 10.0.1.0/24 scram-sha-256
    - host all all 10.0.1.0/24 scram-sha-256
  users:
    replicator:
      password: "repl_secret"
      options:
        - replication
    admin:
      password: "admin_secret"
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
      password: "pg_super_secret"
    replication:
      username: replicator
      password: "repl_secret"
    rewind:
      username: rewind_user
      password: "rewind_secret"
  parameters:
    unix_socket_directories: "/var/run/postgresql"

watchdog:
  mode: automatic    # off, automatic, or required
  device: /dev/watchdog
  safety_margin: 5

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
```

Repeat for node2 and node3, changing `name`, `restapi.connect_address`, and
`postgresql.connect_address` to each node's IP.

---

## 2. Systemd Unit File

```ini
# /etc/systemd/system/patroni.service
[Unit]
Description=Patroni - PostgreSQL High Availability
After=syslog.target network.target

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

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now patroni
```

---

## 3. HAProxy Configuration for Patroni

HAProxy routes traffic to the correct PostgreSQL node using Patroni REST API
health checks. Two backends: one for read-write (primary) and one for
read-only (replicas).

```
# /etc/haproxy/haproxy.cfg (relevant sections)

listen pg-primary
    bind *:5000
    mode tcp
    option httpchk GET /primary
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server node1 10.0.1.1:5432 maxconn 100 check port 8008
    server node2 10.0.1.2:5432 maxconn 100 check port 8008
    server node3 10.0.1.3:5432 maxconn 100 check port 8008

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

Applications connect to HAProxy on port 5000 for writes and port 5001 for reads.
After a switchover or failover, HAProxy detects the role change within the `inter`
check interval (3 seconds in this example) and routes traffic to the new primary.

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg   # validate config
sudo systemctl reload haproxy                   # apply without dropping connections
```

---

## 4. Planned Switchover

Switchover moves the primary role to a chosen replica with minimal downtime.
The cluster must be healthy (a leader must exist).

```bash
# Check cluster state first.
patronictl -c /etc/patroni/patroni.yml list

# Switchover from current leader to a specific candidate.
patronictl -c /etc/patroni/patroni.yml switchover \
    --leader node1 \
    --candidate node2 \
    --force

# Verify the new leader.
patronictl -c /etc/patroni/patroni.yml list

# Schedule a switchover for a maintenance window.
patronictl -c /etc/patroni/patroni.yml switchover \
    --leader node1 \
    --candidate node2 \
    --scheduled "2026-03-15T02:00:00+00:00" \
    --force

# Cancel a scheduled switchover.
patronictl -c /etc/patroni/patroni.yml flush pg-cluster switchover
```

---

## 5. Emergency Failover

Failover promotes a replica when the current primary is unavailable.
Use when the cluster is unhealthy and has no leader.

```bash
# Confirm there is no leader.
patronictl -c /etc/patroni/patroni.yml list

# Force failover to a specific candidate.
patronictl -c /etc/patroni/patroni.yml failover \
    --candidate node2 \
    --force

# Verify the new leader and check that the old primary is down or rejoining.
patronictl -c /etc/patroni/patroni.yml list
```

---

## 6. Reinitialize a Failed Replica

When a replica is in `start failed` state or has diverged beyond pg_rewind's
ability, rebuild it from the current primary.

```bash
# Reinitialize the replica (streams a fresh pg_basebackup from the primary).
patronictl -c /etc/patroni/patroni.yml reinit pg-cluster node3

# Wait for completion (may take minutes to hours depending on data size).
patronictl -c /etc/patroni/patroni.yml list --watch 5

# Alternative: fetch basebackup directly from the leader.
patronictl -c /etc/patroni/patroni.yml reinit pg-cluster node3 --from-leader
```

---

## 7. Enable pg_rewind

pg_rewind allows a former primary to rejoin the cluster as a replica without a
full base backup, by replaying the WAL divergence. Two prerequisites must be met:

1. Data checksums enabled at initdb time (`data-checksums` in bootstrap.initdb), OR
2. `wal_log_hints = on` in PostgreSQL parameters.

```bash
# Check if data checksums are enabled.
sudo -u postgres pg_controldata /var/lib/postgresql/16/main | grep checksum

# Enable pg_rewind in dynamic config.
patronictl -c /etc/patroni/patroni.yml edit-config
# In the editor, set:
#   postgresql:
#     use_pg_rewind: true

# If data checksums are NOT enabled, add wal_log_hints to PostgreSQL parameters.
patronictl -c /etc/patroni/patroni.yml edit-config --set 'postgresql.parameters.wal_log_hints=on'
# This requires a PostgreSQL restart on all nodes.
patronictl -c /etc/patroni/patroni.yml restart pg-cluster --force
```

---

## 8. Maintenance Mode (Pause/Resume)

Pause disables automatic failover. Use during planned PostgreSQL maintenance,
OS patching, or DCS upgrades.

```bash
# Pause automatic failover. --wait blocks until all members acknowledge.
patronictl -c /etc/patroni/patroni.yml pause --wait

# Verify paused state.
patronictl -c /etc/patroni/patroni.yml list
# Output should show "Maintenance mode: on"

# Perform your maintenance...

# Resume automatic failover.
patronictl -c /etc/patroni/patroni.yml resume --wait
```

---

## 9. Monitoring with Prometheus

Patroni exposes a `/metrics` endpoint in Prometheus exposition format on
the REST API port.

```yaml
# prometheus.yml scrape config
scrape_configs:
  - job_name: patroni
    metrics_path: /metrics
    static_configs:
      - targets:
          - 10.0.1.1:8008
          - 10.0.1.2:8008
          - 10.0.1.3:8008
```

Key metrics to alert on:
- `patroni_postgres_running` (0 = PostgreSQL down)
- `patroni_master` (1 on the current primary)
- `patroni_xlog_replayed_location` vs `patroni_xlog_received_location` (replication lag)

For richer PostgreSQL metrics, add `postgres_exporter` alongside Patroni.

---

## 10. Using Consul as DCS

Replace the `etcd3` section with `consul`:

```yaml
consul:
  host: 127.0.0.1:8500
  scheme: http
  token: "your-consul-acl-token"    # optional, if ACLs are enabled
  register_service: true             # register PostgreSQL as a Consul service
  service_tags:
    - primary
    - replica
```

Consul's service catalog and health checks provide an additional discovery
mechanism. Applications can query Consul DNS (e.g.,
`primary.pg-cluster.service.consul`) to find the current primary without
HAProxy, though HAProxy is still recommended for connection pooling.

---

## 11. Using ZooKeeper as DCS

Replace the `etcd3` section with `zookeeper`:

```yaml
zookeeper:
  hosts:
    - 10.0.1.10:2181
    - 10.0.1.11:2181
    - 10.0.1.12:2181
```

ZooKeeper requires a 3+ node ensemble for quorum. Patroni uses ephemeral
znodes for leader election. If the ZooKeeper session expires (default 10s),
Patroni triggers a leader race.

---

## 12. Tuning Timing Parameters

The three critical timing parameters must satisfy `ttl > loop_wait + 2 * retry_timeout`.

```bash
# View current values.
patronictl -c /etc/patroni/patroni.yml show-config | grep -E 'ttl|loop_wait|retry_timeout'

# Adjust for a high-latency network (e.g., cross-datacenter).
patronictl -c /etc/patroni/patroni.yml edit-config \
    --set 'ttl=60' \
    --set 'loop_wait=15' \
    --set 'retry_timeout=15'
```

| Parameter | Default | Role |
|-----------|---------|------|
| `ttl` | 30 | Leader lock lease duration in the DCS |
| `loop_wait` | 10 | Sleep between Patroni HA-loop iterations |
| `retry_timeout` | 10 | How long Patroni retries DCS and PostgreSQL operations |
| `maximum_lag_on_failover` | 1048576 | Max replication lag (bytes) for a replica to be a failover candidate |
