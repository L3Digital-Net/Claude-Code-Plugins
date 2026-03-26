# Cassandra Common Patterns

Each section is a complete, copy-paste-ready reference. Always test schema changes
in a non-production keyspace first.

---

## 1. Create a Keyspace

Keyspaces define replication strategy. Choose `SimpleStrategy` for single-datacenter
and `NetworkTopologyStrategy` for multi-datacenter (recommended even for single DC
to simplify future expansion).

```sql
-- Single datacenter with replication factor 3
CREATE KEYSPACE my_app WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'dc1': 3
};

-- SimpleStrategy (dev/test only)
CREATE KEYSPACE dev_app WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
};

-- Use the keyspace
USE my_app;

-- Alter replication (e.g., add a datacenter)
ALTER KEYSPACE my_app WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'dc1': 3,
  'dc2': 3
};
-- After altering, run nodetool repair on all nodes to replicate existing data
```

---

## 2. Create Tables

Design tables around query patterns, not entity relationships. Each table serves
one query. The primary key determines data distribution and sort order.

```sql
-- Time series: partition by sensor+day, cluster by time descending
CREATE TABLE sensor_readings (
  sensor_id text,
  day date,
  reading_time timestamp,
  value double,
  PRIMARY KEY ((sensor_id, day), reading_time)
) WITH CLUSTERING ORDER BY (reading_time DESC)
  AND compaction = {'class': 'TimeWindowCompactionStrategy',
                    'compaction_window_size': 1,
                    'compaction_window_unit': 'DAYS'}
  AND default_time_to_live = 7776000;  -- 90 days in seconds

-- User lookup by email
CREATE TABLE users_by_email (
  email text PRIMARY KEY,
  user_id uuid,
  display_name text,
  created_at timestamp
);

-- User lookup by ID (denormalized; same data, different partition key)
CREATE TABLE users_by_id (
  user_id uuid PRIMARY KEY,
  email text,
  display_name text,
  created_at timestamp
);
```

---

## 3. Consistency Level Reference

Set consistency per query in cqlsh or in your driver configuration.

```sql
-- In cqlsh
CONSISTENCY QUORUM;       -- Read/write to majority of replicas
CONSISTENCY ONE;          -- Fastest; reads may be stale
CONSISTENCY LOCAL_QUORUM; -- Quorum within local datacenter only
CONSISTENCY ALL;          -- Strongest; any node down blocks the op
CONSISTENCY LOCAL_ONE;    -- Single replica in local DC

-- Check current consistency
CONSISTENCY;

-- Serial consistency (for lightweight transactions / IF conditions)
SERIAL CONSISTENCY LOCAL_SERIAL;
```

| Level | Read guarantee | Write guarantee | Availability |
|-------|---------------|-----------------|--------------|
| ONE | May be stale | Persisted on 1 node | Highest |
| QUORUM | Linearizable (with QUORUM write) | Persisted on majority | Tolerates minority failure |
| LOCAL_QUORUM | Linearizable within DC | Persisted on DC majority | Multi-DC friendly |
| ALL | Always latest | Persisted on all replicas | Lowest (any node down = failure) |

---

## 4. Compaction Strategies

Choose based on workload pattern. Set per table.

```sql
-- SizeTieredCompactionStrategy (STCS) — default, good for write-heavy
ALTER TABLE my_table WITH compaction = {
  'class': 'SizeTieredCompactionStrategy',
  'min_threshold': 4,
  'max_threshold': 32
};

-- LeveledCompactionStrategy (LCS) — good for read-heavy, controlled disk usage
ALTER TABLE my_table WITH compaction = {
  'class': 'LeveledCompactionStrategy',
  'sstable_size_in_mb': 160
};

-- TimeWindowCompactionStrategy (TWCS) — best for time series
ALTER TABLE sensor_data WITH compaction = {
  'class': 'TimeWindowCompactionStrategy',
  'compaction_window_size': 1,
  'compaction_window_unit': 'HOURS'
};

-- Check compaction status
-- (from shell)
-- nodetool compactionstats
-- nodetool tablestats my_keyspace.my_table
```

---

## 5. Backup with Snapshots

Snapshots create hard links to SSTables, which are immutable. They are instant
and free in terms of disk until compaction creates new SSTables.

```bash
# Take a snapshot of a specific keyspace
nodetool snapshot -t backup_2026_03_14 my_keyspace

# Take a snapshot of all keyspaces
nodetool snapshot -t full_backup_2026_03_14

# List all snapshots
nodetool listsnapshots

# Snapshot files are at:
# /var/lib/cassandra/data/<keyspace>/<table-uuid>/snapshots/<tag>/

# Copy snapshots off-node for offsite backup
tar czf /backup/cassandra_backup.tar.gz \
  /var/lib/cassandra/data/my_keyspace/*/snapshots/backup_2026_03_14/

# Clear a specific snapshot (reclaim hard link space)
nodetool clearsnapshot -t backup_2026_03_14

# Clear all snapshots
nodetool clearsnapshot
```

---

## 6. Restore from Snapshot

Restore requires the table schema to exist first. Truncate the table before
restoring to prevent tombstones from shadowing restored data.

```bash
# 1. Ensure schema exists (recreate table if needed from schema backup)
cqlsh -e "DESCRIBE KEYSPACE my_keyspace" > schema_backup.cql

# 2. Truncate the target table (removes tombstones)
cqlsh -e "TRUNCATE my_keyspace.my_table;"

# 3. Copy snapshot SSTables to the table's data directory
cp /backup/snapshots/backup_tag/*.db \
  /var/lib/cassandra/data/my_keyspace/my_table-<uuid>/

# 4. Load the SSTables without restart
nodetool refresh my_keyspace my_table

# Alternative: use sstableloader for cross-cluster restore
sstableloader -d <seed_node_ip> \
  /backup/snapshots/backup_tag/
```

---

## 7. Repair Scheduling

Run repair on every node within `gc_grace_seconds` (default 10 days) to prevent
zombie data resurrection.

```bash
# Full repair on a keyspace (runs on all token ranges owned by this node)
nodetool repair my_keyspace

# Full repair on a specific table
nodetool repair my_keyspace my_table

# Incremental repair (repairs only unrepaired SSTables; faster)
nodetool repair my_keyspace --incremental

# Subrange repair (for large clusters; repair a portion at a time)
nodetool repair my_keyspace --partitioner-range

# Parallel repair (uses multiple threads)
nodetool repair my_keyspace --parallel

# Check repair status
nodetool netstats

# Cron job for weekly repair (run on each node)
# 0 2 * * 0 nodetool repair my_keyspace 2>&1 | logger -t cassandra-repair
```

---

## 8. Snitch Configuration

The snitch tells Cassandra which datacenter and rack each node belongs to.
Must be the same on all nodes in the cluster.

`/etc/cassandra/cassandra.yaml`:
```yaml
# GossipingPropertyFileSnitch — production standard
endpoint_snitch: GossipingPropertyFileSnitch
```

`/etc/cassandra/cassandra-rackdc.properties`:
```properties
dc=dc1
rack=rack1
# prefer_local=true  # uncomment for multi-DC to prefer local DC for internal traffic
```

Other snitch options:
- `SimpleSnitch` -- single-DC dev only, no rack awareness
- `PropertyFileSnitch` -- reads from `cassandra-topology.properties` (legacy)
- `Ec2Snitch` -- AWS single-region; region = DC, AZ = rack
- `Ec2MultiRegionSnitch` -- AWS multi-region; uses public IP for cross-region
- `GoogleCloudSnitch` -- GCP; project = DC, zone = rack

---

## 9. Useful CQL Queries for Monitoring

```sql
-- System schema: list all keyspaces
SELECT * FROM system_schema.keyspaces;

-- Table sizes and read/write counts
SELECT keyspace_name, table_name, id
FROM system_schema.tables
WHERE keyspace_name = 'my_keyspace';

-- Check cluster size info via system tables
SELECT peer, data_center, rack, release_version
FROM system.peers;

-- Local node info
SELECT cluster_name, listen_address, data_center, rack
FROM system.local;

-- Trace a slow query
TRACING ON;
SELECT * FROM my_keyspace.my_table WHERE id = 'abc123';
TRACING OFF;

-- Expand output for readability
EXPAND ON;
SELECT * FROM system.local;
EXPAND OFF;
```

---

## 10. cassandra.yaml Key Settings

The most important settings to review for a new cluster. Located at
`/etc/cassandra/cassandra.yaml`.

```yaml
# Cluster identity — must match all nodes
cluster_name: 'MyCluster'

# Token distribution (256 is default; 16 recommended for new clusters)
num_tokens: 16

# Seed nodes (2-3 per DC; a node should not list itself)
seed_provider:
  - class_name: org.apache.cassandra.locator.SimpleSeedProvider
    parameters:
      - seeds: "10.0.1.10,10.0.1.11"

# Network addresses
listen_address: 10.0.1.10          # inter-node communication
rpc_address: 0.0.0.0              # client-facing (CQL)
broadcast_rpc_address: 10.0.1.10  # advertised to clients

# Ports
native_transport_port: 9042   # CQL clients
storage_port: 7000            # inter-node
ssl_storage_port: 7001        # inter-node TLS

# Directories
data_file_directories:
  - /var/lib/cassandra/data
commitlog_directory: /var/lib/cassandra/commitlog
saved_caches_directory: /var/lib/cassandra/saved_caches
hints_directory: /var/lib/cassandra/hints

# Snitch
endpoint_snitch: GossipingPropertyFileSnitch

# Compaction throughput (MB/s; 0 = unlimited)
compaction_throughput_mb_per_sec: 64

# Memtable flush writers
memtable_flush_writers: 2

# Concurrent reads/writes
concurrent_reads: 32
concurrent_writes: 32

# Hinted handoff (deliver missed writes when node recovers)
hinted_handoff_enabled: true
max_hint_window_in_ms: 10800000  # 3 hours
```
