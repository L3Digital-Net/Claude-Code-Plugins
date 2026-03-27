# clickhouse

> **Based on:** clickhouse 26.2.5 | **Updated:** 2026-03-27

## Identity
- **Unit**: `clickhouse-server.service`
- **Server binary**: `/usr/bin/clickhouse-server`
- **Client binary**: `/usr/bin/clickhouse-client`
- **Config**: `/etc/clickhouse-server/config.xml` (server), `/etc/clickhouse-server/users.xml` (users/profiles/quotas)
- **Config overrides**: `/etc/clickhouse-server/config.d/*.xml` and `/etc/clickhouse-server/users.d/*.xml`
- **Data dir**: `/var/lib/clickhouse/`
- **Logs**: `/var/log/clickhouse-server/clickhouse-server.log`, `/var/log/clickhouse-server/clickhouse-server.err.log`
- **User**: `clickhouse` (runs as its own system user)
- **Install**: `apt install clickhouse-server clickhouse-client` (from ClickHouse repo) / Docker `clickhouse/clickhouse-server`

## Quick Start

```bash
# Add ClickHouse repository (Debian/Ubuntu)
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | sudo gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list
sudo apt-get update
sudo apt-get install -y clickhouse-server clickhouse-client
sudo systemctl enable --now clickhouse-server
clickhouse-client --query "SELECT version()"

# Docker
docker run -d --name clickhouse \
  -p 8123:8123 -p 9000:9000 \
  -v clickhouse-data:/var/lib/clickhouse \
  -v clickhouse-logs:/var/log/clickhouse-server \
  clickhouse/clickhouse-server
```

## Key Operations

| Task | Command |
|------|---------|
| Interactive SQL client | `clickhouse-client` |
| Run a query | `clickhouse-client --query "SELECT 1"` |
| Connect to remote server | `clickhouse-client --host <ip> --port 9000 --user default --password <pass>` |
| HTTP API query | `curl 'http://localhost:8123/?query=SELECT+version()'` |
| List databases | `clickhouse-client --query "SHOW DATABASES"` |
| List tables | `clickhouse-client --query "SHOW TABLES FROM <db>"` |
| Table schema | `clickhouse-client --query "DESCRIBE TABLE <db>.<table>"` |
| Table disk usage | `clickhouse-client --query "SELECT formatReadableSize(sum(bytes_on_disk)) FROM system.parts WHERE database='<db>' AND table='<table>'"` |
| Total disk usage | `clickhouse-client --query "SELECT formatReadableSize(sum(bytes_on_disk)) FROM system.parts"` |
| Current queries | `clickhouse-client --query "SELECT query_id, query, elapsed FROM system.processes"` |
| Kill a query | `clickhouse-client --query "KILL QUERY WHERE query_id = '<id>'"` |
| Check merges | `clickhouse-client --query "SELECT * FROM system.merges"` |
| Server metrics | `clickhouse-client --query "SELECT * FROM system.metrics"` |
| Reload config | `sudo systemctl reload clickhouse-server` or `SYSTEM RELOAD CONFIG` SQL |

## Expected Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8123 | HTTP | HTTP API and web UI (Play) |
| 8443 | HTTPS | HTTP API with TLS |
| 9000 | Native TCP | clickhouse-client protocol |
| 9440 | Native TLS | clickhouse-client with TLS |
| 9009 | Interserver | Replication and distributed queries |
| 9019 | JDBC bridge | Optional JDBC/ODBC bridge |

Default: all bound to `0.0.0.0` (controlled by `<listen_host>` in config.xml).

## Health Checks

1. `systemctl is-active clickhouse-server` — daemon running
2. `curl -sf http://localhost:8123/ping` — returns "Ok.\n"
3. `clickhouse-client --query "SELECT 1"` — native protocol reachable
4. `curl -sf 'http://localhost:8123/?query=SELECT+uptime()'` — server uptime in seconds

## System Tables (Introspection)

ClickHouse exposes extensive system metadata:

| Table | Purpose |
|-------|---------|
| `system.processes` | Currently running queries |
| `system.query_log` | Historical query log (enable in config) |
| `system.parts` | MergeTree parts — disk usage, partition info |
| `system.merges` | Active background merges |
| `system.metrics` | Current server gauges |
| `system.events` | Cumulative server counters |
| `system.asynchronous_metrics` | Background-computed metrics |
| `system.replicas` | Replication status per table |
| `system.disks` | Configured storage disks |
| `system.clusters` | Cluster topology |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Connection refused" on 8123 or 9000 | Server not running or `listen_host` restricts access | `systemctl status clickhouse-server`; check `<listen_host>` in config.xml |
| Out of memory / killed by OOM | Query consuming too much RAM | Set `max_memory_usage` per user/query in users.xml; add `max_memory_usage_for_all_queries` server-wide |
| Slow queries / high CPU | Missing ORDER BY key in query, or too many parts | Check `EXPLAIN` plan; run `OPTIMIZE TABLE` to merge parts; review table engine choice |
| Disk space exhausted | Data retention not configured or TTL not working | Add TTL to table: `ALTER TABLE t MODIFY TTL date + INTERVAL 30 DAY`; check `system.parts` for bloat |
| "Too many parts" error | Inserts are too frequent and small | Batch inserts (aim for 1 insert/second minimum); check `parts_to_throw_insert` threshold |
| Replication lag | Network issues between replicas or ZooKeeper/Keeper problems | Check `system.replicas` for `is_leader`, `queue_size`; verify ClickHouse Keeper / ZooKeeper health |
| `default` user has no password | Fresh install with default config | Set password in `users.xml` or `users.d/default-password.xml` immediately |

## Pain Points

- **Secure the `default` user immediately.** Fresh installs have a `default` user with no password and full access. Set a password in `/etc/clickhouse-server/users.d/` or disable it and create named users. The HTTP API on 8123 is wide open otherwise.

- **MergeTree is the only production engine family.** Nearly all tables should use `MergeTree` or one of its variants (`ReplacingMergeTree`, `AggregatingMergeTree`, `ReplicatedMergeTree`). Other engines (Memory, Log, TinyLog) are for testing or temporary data only.

- **Batch your inserts.** ClickHouse is optimized for bulk writes, not row-at-a-time inserts. Each insert creates a "part" that must be merged in the background. Inserting one row at a time quickly hits the "too many parts" threshold. Aim for batches of 1,000+ rows or at most one insert per second.

- **Column-oriented means different query patterns.** `SELECT *` is expensive because it reads every column from disk. Always select only the columns you need. Queries that filter on the ORDER BY key are fast; those that scan full tables are proportionally expensive.

- **TTL for data lifecycle.** ClickHouse supports table-level TTL to automatically drop or move old data: `ALTER TABLE t MODIFY TTL timestamp + INTERVAL 90 DAY DELETE`. Without TTL, data grows indefinitely.

- **Config override files, not in-place edits.** Put customizations in `/etc/clickhouse-server/config.d/` and `/etc/clickhouse-server/users.d/` as XML files. They merge with the base config. This survives package upgrades and keeps changes auditable.

- **Memory limits are critical.** A single query can consume all available RAM. Set `max_memory_usage` in user profiles to cap per-query memory. Set `max_memory_usage_for_all_queries` to protect the server overall.

## See Also

- **postgresql** — row-oriented OLTP database; ClickHouse is columnar OLAP — they serve different workloads
- **influxdb** — time-series database; ClickHouse handles time-series workloads too but with SQL and broader analytics
- **grafana** — visualization platform with native ClickHouse data source plugin
- **prometheus** — metrics collection; ClickHouse can store Prometheus metrics via remote write adapters

## References
See `references/` for:
- `docs.md` — official documentation links
