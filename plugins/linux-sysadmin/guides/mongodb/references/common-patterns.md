# MongoDB Common Patterns

Each section is a standalone task with copy-paste-ready commands.
Run JavaScript blocks inside `mongosh` unless noted otherwise.

---

## 1. Replica Set Setup (3-Member)

A replica set provides data redundancy, automatic failover, and is required for
multi-document transactions (even on a single node).

### Configure each member's mongod.conf

Add the same `replSetName` to all three nodes:

```yaml
# /etc/mongod.conf (on each member)
replication:
  replSetName: "rs0"

net:
  bindIp: 0.0.0.0   # or comma-separated list of specific IPs

security:
  keyFile: /etc/mongodb-keyfile   # required for authenticated replica sets
```

### Generate a shared keyfile (run once, copy to all members)

```bash
openssl rand -base64 756 > /etc/mongodb-keyfile
chmod 400 /etc/mongodb-keyfile
chown mongodb:mongodb /etc/mongodb-keyfile

# Copy the same keyfile to all replica set members.
# scp /etc/mongodb-keyfile user@mongo2:/etc/mongodb-keyfile
# scp /etc/mongodb-keyfile user@mongo3:/etc/mongodb-keyfile
```

### Restart mongod on each member, then initiate from one node

```bash
sudo systemctl restart mongod   # on all three members
```

```javascript
// Connect to one member and initiate the replica set.
// Run rs.initiate() on only ONE member.
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1.example.com:27017" },
    { _id: 1, host: "mongo2.example.com:27017" },
    { _id: 2, host: "mongo3.example.com:27017" }
  ]
})

// Verify. Wait a few seconds for election to complete.
rs.status()
```

### Add a member to an existing replica set

```javascript
// Run on the primary.
rs.add("mongo4.example.com:27017")

// Add an arbiter (votes but holds no data — use sparingly).
rs.addArb("arbiter.example.com:27017")
```

### Single-node replica set (for development / transactions)

```yaml
# /etc/mongod.conf
replication:
  replSetName: "rs0"
```

```javascript
// After restarting mongod:
rs.initiate()
```

---

## 2. User and Role Creation

MongoDB authenticates against the `admin` database by default. Create users there
for cluster-wide roles; create them in specific databases for scoped access.

### Create an admin superuser (first user via localhost exception)

```javascript
// Connect to mongosh on the same host before enabling auth.
// The localhost exception allows the first user creation without credentials.
use admin
db.createUser({
  user: "admin",
  pwd: passwordPrompt(),   // interactive prompt — never hardcode passwords
  roles: [
    { role: "root", db: "admin" }
  ]
})
```

### Enable authentication

```yaml
# /etc/mongod.conf
security:
  authorization: enabled
```

```bash
sudo systemctl restart mongod
# From now on, all connections require authentication.
mongosh -u admin -p --authenticationDatabase admin
```

### Create an application user (readWrite on one database)

```javascript
use admin
db.createUser({
  user: "appuser",
  pwd: passwordPrompt(),
  roles: [
    { role: "readWrite", db: "myapp" }
  ]
})
```

### Create a read-only user

```javascript
use admin
db.createUser({
  user: "reporter",
  pwd: passwordPrompt(),
  roles: [
    { role: "read", db: "myapp" }
  ]
})
```

### Common built-in roles

| Role | Scope | Description |
|------|-------|-------------|
| `read` | Database | Read all non-system collections |
| `readWrite` | Database | Read and write all non-system collections |
| `dbAdmin` | Database | Schema management, indexing, statistics (no data read/write) |
| `userAdmin` | Database | Create and manage users and roles for this database |
| `dbOwner` | Database | Combines readWrite, dbAdmin, userAdmin |
| `clusterAdmin` | Cluster | Full cluster management (replica set, sharding) |
| `clusterMonitor` | Cluster | Read-only monitoring access to cluster state |
| `backup` | Cluster | Sufficient privileges for mongodump |
| `restore` | Cluster | Sufficient privileges for mongorestore |
| `root` | Cluster | Superuser — all privileges on all resources |

### Change a user's password

```javascript
use admin
db.changeUserPassword("appuser", passwordPrompt())
```

### Grant additional roles

```javascript
use admin
db.grantRolesToUser("appuser", [
  { role: "read", db: "analytics" }
])
```

### Remove a user

```javascript
use admin
db.dropUser("olduser")
```

---

## 3. Backup Strategies

### mongodump / mongorestore (logical backup)

Best for: small to medium databases, selective collection backup, cross-version migration.
Not ideal for: databases over ~100 GB (slow; consider filesystem snapshots instead).

**Dump a single database (compressed archive)**
```bash
mongodump \
  --uri="mongodb://backupuser:password@localhost:27017/myapp?authSource=admin" \
  --gzip \
  --archive=/var/backups/mongodb/myapp_$(date +%Y%m%d).gz
```

**Dump all databases**
```bash
mongodump \
  -u backupuser -p --authenticationDatabase admin \
  --gzip \
  --archive=/var/backups/mongodb/full_$(date +%Y%m%d).gz
```

**Dump a single collection**
```bash
mongodump \
  -u backupuser -p --authenticationDatabase admin \
  --db=myapp --collection=orders \
  --gzip --archive=/var/backups/mongodb/orders_$(date +%Y%m%d).gz
```

**Restore from archive (drop existing collections first)**
```bash
mongorestore \
  -u admin -p --authenticationDatabase admin \
  --gzip --archive=/var/backups/mongodb/myapp_20260101.gz \
  --drop
```

**Restore a single collection**
```bash
mongorestore \
  -u admin -p --authenticationDatabase admin \
  --gzip --archive=/var/backups/mongodb/orders_20260101.gz \
  --nsInclude="myapp.orders" \
  --drop
```

**Point-in-time backup with oplog**
```bash
# Capture oplog entries during the dump for consistent snapshots on replica sets.
mongodump --oplog --gzip --archive=/var/backups/mongodb/full_oplog_$(date +%Y%m%d).gz

# Restore with oplog replay.
mongorestore --oplogReplay --gzip --archive=/var/backups/mongodb/full_oplog_20260101.gz --drop
```

### Filesystem snapshot backup

Best for: large databases where mongodump is too slow.
Requires: WiredTiger with journaling enabled (default since MongoDB 4.0).

```bash
# Lock writes, take snapshot, unlock. Brief pause in writes.
mongosh --eval "db.fsyncLock()"

# Take an LVM or ZFS snapshot of the data volume.
lvcreate --size 10G --snapshot --name mongo-snap /dev/vg0/mongo-data
# Or for ZFS:
# zfs snapshot tank/mongodb@backup-$(date +%Y%m%d)

mongosh --eval "db.fsyncUnlock()"
```

### Automated backup cron job

```bash
# /etc/cron.d/mongodb-backup
0 2 * * * mongodb mongodump -u backupuser -p 'CHANGE_ME' --authenticationDatabase admin --gzip --archive=/var/backups/mongodb/full_$(date +\%Y\%m\%d).gz 2>&1 | logger -t mongodump

# Retention: remove backups older than 14 days.
0 3 * * * root find /var/backups/mongodb/ -name "*.gz" -mtime +14 -delete
```

---

## 4. Index Creation and Management

### Single-field index

```javascript
// Ascending index on a field. 1 = ascending, -1 = descending.
db.orders.createIndex({ customer_id: 1 })
```

### Compound index (ESR rule: Equality, Sort, Range)

```javascript
// Supports queries that filter on status (equality), sort by created_at,
// and optionally filter on amount (range).
db.orders.createIndex({ status: 1, created_at: -1, amount: 1 })
```

### Unique index

```javascript
db.users.createIndex({ email: 1 }, { unique: true })
```

### TTL index (auto-expire documents)

```javascript
// Documents expire 30 days after the createdAt field value.
db.sessions.createIndex({ createdAt: 1 }, { expireAfterSeconds: 2592000 })
```

### Text index (full-text search)

```javascript
// Only one text index per collection.
db.articles.createIndex({ title: "text", body: "text" })

// Query with text search:
db.articles.find({ $text: { $search: "mongodb replication" } })
```

### Partial index (index a subset of documents)

```javascript
// Index only active orders — reduces index size and write overhead.
db.orders.createIndex(
  { customer_id: 1 },
  { partialFilterExpression: { status: "active" } }
)
```

### Check query execution plan

```javascript
// executionStats shows whether the query used an index or performed a COLLSCAN.
db.orders.find({ customer_id: 42 }).explain("executionStats")

// Key fields in output:
//   winningPlan.stage: "IXSCAN" (good) vs "COLLSCAN" (full scan — needs index)
//   executionStats.totalDocsExamined vs totalKeysExamined
//   executionStats.executionTimeMillis
```

### List all indexes on a collection

```javascript
db.orders.getIndexes()
```

### Drop an index

```javascript
db.orders.dropIndex("status_1_created_at_-1_amount_1")
// Or by spec:
db.orders.dropIndex({ status: 1, created_at: -1, amount: 1 })
```

### Background index build (default in 4.2+)

Starting with MongoDB 4.2, index builds are performed in the background by default
and hold an exclusive lock only at the start and end of the build. No special flag
needed. On older versions, pass `{ background: true }`.

---

## 5. Aggregation Pipeline Examples

### Group and count

```javascript
// Count orders per status.
db.orders.aggregate([
  { $group: {
    _id: "$status",
    count: { $sum: 1 },
    totalAmount: { $sum: "$amount" }
  }},
  { $sort: { count: -1 } }
])
```

### Filter, project, and sort

```javascript
// Recent high-value orders with selected fields.
db.orders.aggregate([
  { $match: {
    status: "completed",
    amount: { $gte: 100 }
  }},
  { $project: {
    _id: 0,
    orderId: "$_id",
    customer_id: 1,
    amount: 1,
    created_at: 1
  }},
  { $sort: { created_at: -1 } },
  { $limit: 50 }
])
```

### $lookup (left outer join)

```javascript
// Join orders with customer details from another collection.
db.orders.aggregate([
  { $lookup: {
    from: "customers",
    localField: "customer_id",
    foreignField: "_id",
    as: "customer"
  }},
  { $unwind: "$customer" },
  { $project: {
    orderId: "$_id",
    amount: 1,
    customerName: "$customer.name",
    customerEmail: "$customer.email"
  }}
])
```

### $unwind and regroup (array flattening)

```javascript
// Flatten order items, then sum quantity per product.
db.orders.aggregate([
  { $unwind: "$items" },
  { $group: {
    _id: "$items.product_id",
    totalQty: { $sum: "$items.quantity" },
    revenue: { $sum: { $multiply: ["$items.quantity", "$items.price"] } }
  }},
  { $sort: { revenue: -1 } }
])
```

### $bucket (histogram)

```javascript
// Group orders into price buckets.
db.orders.aggregate([
  { $bucket: {
    groupBy: "$amount",
    boundaries: [0, 50, 100, 250, 500, 1000, Infinity],
    default: "Other",
    output: {
      count: { $sum: 1 },
      avgAmount: { $avg: "$amount" }
    }
  }}
])
```

---

## 6. Connection String Formats

### Standard format

```
mongodb://[username:password@]host[:port][/database][?options]
```

**Examples:**
```bash
# Local, no auth.
mongosh "mongodb://localhost:27017/myapp"

# With authentication (authSource specifies where the user is defined).
mongosh "mongodb://appuser:secret@localhost:27017/myapp?authSource=admin"

# Replica set (list all members for failover).
mongosh "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/myapp?replicaSet=rs0&authSource=admin"
```

### SRV format (DNS-based discovery)

```
mongodb+srv://[username:password@]hostname[/database][?options]
```

The `+srv` prefix queries DNS SRV records to discover replica set members automatically.
TLS is enabled by default when using SRV connections.

```bash
# Atlas or DNS-configured cluster.
mongosh "mongodb+srv://appuser:secret@cluster0.example.mongodb.net/myapp"
```

### Common connection string options

| Option | Default | Description |
|--------|---------|-------------|
| `authSource` | (database in URI) | Database to authenticate against; usually `admin` |
| `replicaSet` | (none) | Replica set name for direct connections |
| `tls` | false (standard) / true (SRV) | Enable TLS encryption |
| `readPreference` | `primary` | Where to route reads: `primary`, `primaryPreferred`, `secondary`, `secondaryPreferred`, `nearest` |
| `w` | `1` | Write concern: `1`, `majority`, or a number |
| `retryWrites` | true (4.2+) | Retry failed writes automatically |
| `maxPoolSize` | 100 | Maximum connections in the driver pool |
| `connectTimeoutMS` | 10000 | Timeout for initial connection |
| `serverSelectionTimeoutMS` | 30000 | How long the driver waits to find a suitable server |

---

## 7. Monitoring and Diagnostics

### Current operations

```javascript
// Show all active operations (filter for long-running ones).
db.currentOp({ "secs_running": { $gte: 5 } })

// Kill a specific operation by opid.
db.killOp(<opid>)
```

### Server status (key sections)

```javascript
// Full server status.
db.serverStatus()

// Useful subsections:
db.serverStatus().connections     // current, available, totalCreated
db.serverStatus().opcounters      // insert, query, update, delete, getmore, command
db.serverStatus().wiredTiger.cache // bytes in cache, dirty bytes, eviction stats
db.serverStatus().globalLock      // current queue: readers + writers
db.serverStatus().network         // bytesIn, bytesOut, numRequests
```

### Database and collection stats

```javascript
db.stats()                        // current database size, collections, indexes
db.orders.stats()                 // single collection: size, count, avgObjSize, indexes
db.orders.totalSize()             // total bytes (data + indexes)
db.orders.totalIndexSize()        // total index bytes
```

### Replica set diagnostics

```javascript
rs.status()                       // member states, optimes, heartbeat info
rs.conf()                         // current replica set configuration
rs.printReplicationInfo()         // oplog size and time window
rs.printSecondaryReplicationInfo() // lag per secondary
```

### mongostat and mongotop (external tools)

```bash
# Real-time server stats (like vmstat for MongoDB).
mongostat -u admin -p --authenticationDatabase admin --rowcount 10

# Per-collection read/write time breakdown.
mongotop -u admin -p --authenticationDatabase admin 5
```

---

## 8. Common Maintenance Tasks

### Compact a collection (reclaim disk space)

```javascript
// Run on secondaries first, then step down the primary and compact it.
// compact blocks reads/writes on the target collection.
db.runCommand({ compact: "orders" })

// MongoDB 8.0+: enable automatic background compaction.
db.adminCommand({ setParameter: 1, autoCompact: true })
```

### Repair a database

```bash
# Use mongod --repair only as a last resort (e.g., after unclean shutdown
# with data corruption). This rebuilds data files and indexes.
# Stop mongod first. This process can take a long time on large databases.
sudo systemctl stop mongod
sudo -u mongodb mongod --dbpath /var/lib/mongodb --repair
sudo systemctl start mongod
```

### Rotate logs

```javascript
// Signal mongod to rotate its log file (when using logRotate: rename).
db.adminCommand({ logRotate: 1 })
```

```bash
# Or send SIGUSR1 externally.
sudo kill -SIGUSR1 $(pidof mongod)
```

### Step down a primary (for maintenance)

```javascript
// Force the primary to become a secondary for 60 seconds.
// A new primary will be elected automatically.
rs.stepDown(60)
```

### Resync a secondary

```bash
# If a secondary falls too far behind the oplog window, it must be resynced.
# Stop the secondary, delete its data, restart — it will perform an initial sync.
sudo systemctl stop mongod
sudo rm -rf /var/lib/mongodb/*
sudo systemctl start mongod
# Monitor sync progress: rs.status() on the secondary.
```
