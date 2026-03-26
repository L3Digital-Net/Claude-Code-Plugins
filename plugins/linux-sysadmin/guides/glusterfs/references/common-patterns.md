# GlusterFS Common Patterns

---

## 1. Build a Trusted Storage Pool

All nodes must have `glusterd` running and be reachable by hostname. Run `peer probe`
from any one node to add the others. The probing node is implicitly in its own pool.

```bash
# Install and start on all nodes
sudo apt install glusterfs-server
sudo systemctl enable --now glusterd

# From node1, probe the other nodes
sudo gluster peer probe node2
sudo gluster peer probe node3
sudo gluster peer probe node4

# Verify the pool
gluster peer status
gluster pool list
```

---

## 2. Create Volume Types

### Distributed (no redundancy, maximum capacity)

Files are spread across bricks using a DHT hash. Losing any brick loses all files on it.

```bash
# 3-node distributed volume. Total capacity = sum of all bricks.
gluster volume create dist-vol \
    node1:/data/brick1 node2:/data/brick1 node3:/data/brick1
gluster volume start dist-vol
```

### Replicated (N copies per file)

Every file exists on all bricks in a replica set. Replica 2 tolerates 1 brick failure;
replica 3 tolerates 2.

```bash
# 2-way replica across 2 nodes. Usable capacity = 1 brick.
gluster volume create rep-vol replica 2 \
    node1:/data/brick1 node2:/data/brick1
gluster volume start rep-vol
```

### Replicated with Arbiter (split-brain prevention without 3 full copies)

The third brick stores only metadata and extended attributes, not file data.
Prevents split-brain at lower storage cost than replica 3.

```bash
# Replica 2 + arbiter on a third node.
gluster volume create arb-vol replica 2 arbiter 1 \
    node1:/data/brick1 node2:/data/brick1 node3:/data/arbiter1
gluster volume start arb-vol
```

### Distributed-Replicated (scale capacity with redundancy)

Bricks are grouped into replica sets, then data is distributed across sets.
Total bricks must be a multiple of the replica count. Brick order matters:
consecutive bricks form a replica set.

```bash
# 4 bricks, replica 2 = 2 replica sets, distributed across sets.
# Replica set 1: node1+node2, Replica set 2: node3+node4.
gluster volume create dist-rep-vol replica 2 \
    node1:/data/brick1 node2:/data/brick1 \
    node3:/data/brick1 node4:/data/brick1
gluster volume start dist-rep-vol
```

### Dispersed (erasure coding)

Data is split into fragments with configurable redundancy. More space-efficient than
replication at the cost of CPU overhead.

```bash
# 6 bricks, redundancy 2 = tolerates 2 brick failures.
# Usable capacity = (6-2)/6 = 66% of total brick capacity.
gluster volume create disp-vol disperse 6 redundancy 2 \
    node1:/data/brick1 node2:/data/brick1 node3:/data/brick1 \
    node4:/data/brick1 node5:/data/brick1 node6:/data/brick1
gluster volume start disp-vol

# Minimum: 3 bricks with redundancy 1.
# Rule: total bricks > 2 * redundancy
```

### Distributed-Dispersed (scale erasure-coded volumes)

Multiple dispersed subvolumes with data distributed across them.
Total bricks must be a multiple of the disperse count.

```bash
# 12 bricks = 2 dispersed subvolumes of 6 bricks each, redundancy 2.
gluster volume create dist-disp-vol disperse 6 redundancy 2 \
    node1:/data/brick1 node2:/data/brick1 node3:/data/brick1 \
    node4:/data/brick1 node5:/data/brick1 node6:/data/brick1 \
    node7:/data/brick1 node8:/data/brick1 node9:/data/brick1 \
    node10:/data/brick1 node11:/data/brick1 node12:/data/brick1
gluster volume start dist-disp-vol
```

---

## 3. Expand a Volume (Add Bricks and Rebalance)

Adding bricks to a distributed or distributed-replicated volume increases capacity.
New data is written to new bricks, but existing data stays put until rebalanced.

```bash
# Add 2 bricks to a replica-2 volume (adds one more replica set).
gluster volume add-brick dist-rep-vol \
    node5:/data/brick1 node6:/data/brick1

# Rebalance distributes existing files across all brick sets.
gluster volume rebalance dist-rep-vol start
gluster volume rebalance dist-rep-vol status
# Wait for "completed" status before removing old bricks or heavy I/O.
```

---

## 4. Shrink a Volume (Remove Bricks)

Removing bricks migrates their data first. The process has three stages:
start (begins migration), status (check progress), commit (finalize removal).

```bash
# Remove a replica set from a dist-rep volume.
gluster volume remove-brick dist-rep-vol \
    node5:/data/brick1 node6:/data/brick1 start

# Monitor migration progress.
gluster volume remove-brick dist-rep-vol \
    node5:/data/brick1 node6:/data/brick1 status

# Once migration completes, commit the removal.
gluster volume remove-brick dist-rep-vol \
    node5:/data/brick1 node6:/data/brick1 commit
```

---

## 5. Snapshots (Requires LVM Thin Provisioning)

GlusterFS snapshots delegate to LVM thin snapshots. Every brick in the volume must
reside on a thinly-provisioned logical volume.

```bash
# Create a snapshot.
gluster snapshot create snap1 myvol
# With description and no auto-timestamp:
gluster snapshot create snap1 myvol no-timestamp description "Before upgrade"

# List all snapshots.
gluster snapshot list
gluster snapshot list myvol  # Filter to one volume

# Snapshot info and status.
gluster snapshot info snap1
gluster snapshot status snap1

# Restore a snapshot (volume must be stopped).
gluster volume stop myvol
gluster snapshot restore snap1
gluster volume start myvol
# Note: the snapshot is consumed by restore and will no longer appear in the list.

# Delete a snapshot.
gluster snapshot delete snap1
# Delete all snapshots for a volume:
gluster snapshot delete all volume myvol

# Configure snapshot limits.
gluster snapshot config snap-max-hard-limit 256
gluster snapshot config snap-max-soft-limit 90
gluster snapshot config auto-delete enable
```

---

## 6. Geo-Replication (Asynchronous Cross-Site Replication)

Replicates a primary volume to a secondary volume on a remote cluster. Requires
SSH access from primary to secondary nodes with key-based authentication.

```bash
# Prerequisites: same GlusterFS version on both clusters, NTP synchronized.

# Step 1: Create a common pem pub file.
gluster system:: execute gsec_create

# Step 2: Create the geo-replication session (pushes SSH keys to secondary).
gluster volume geo-replication myvol \
    secondary-host::secondary-vol create push-pem

# Step 3: Start the session.
gluster volume geo-replication myvol \
    secondary-host::secondary-vol start

# Check status.
gluster volume geo-replication myvol \
    secondary-host::secondary-vol status detail

# Pause and resume.
gluster volume geo-replication myvol \
    secondary-host::secondary-vol pause
gluster volume geo-replication myvol \
    secondary-host::secondary-vol resume

# Stop the session.
gluster volume geo-replication myvol \
    secondary-host::secondary-vol stop

# Delete the session.
gluster volume geo-replication myvol \
    secondary-host::secondary-vol delete

# Tune sync interval (default 5 minutes).
gluster volume geo-replication myvol \
    secondary-host::secondary-vol config sync-interval 60
```

---

## 7. Quota Management

Quotas limit storage usage per directory path within a volume.

```bash
# Enable quotas on the volume (required first).
gluster volume quota myvol enable

# Set a hard limit of 100 GB on /projects.
gluster volume quota myvol limit-usage /projects 100GB

# Set a hard limit with a soft limit at 70% (default soft limit is 80%).
gluster volume quota myvol limit-usage /projects 100GB 70%

# Set a volume-wide limit (root path).
gluster volume quota myvol limit-usage / 1TB

# List current quota usage.
gluster volume quota myvol list
gluster volume quota myvol list /projects

# Remove a quota limit.
gluster volume quota myvol remove /projects

# Disable quotas entirely.
gluster volume quota myvol disable

# Configure alert time (how long after soft-limit before alerts).
gluster volume quota myvol alert-time 1w

# Configure soft-timeout and hard-timeout for quota caching.
gluster volume quota myvol soft-timeout 120
gluster volume quota myvol hard-timeout 5
```

---

## 8. Self-Heal and Split-Brain Resolution

### Check and Trigger Self-Heal

```bash
# View files needing heal.
gluster volume heal myvol info

# Fast approximate count of pending heals.
gluster volume heal myvol statistics heal-count

# View files that healed successfully.
gluster volume heal myvol info healed

# View files where heal failed.
gluster volume heal myvol info failed

# Check for split-brain files.
gluster volume heal myvol info split-brain

# Manually trigger a full heal cycle.
gluster volume heal myvol

# Trigger heal for a specific file.
gluster volume heal myvol split-brain source-brick \
    node1:/data/brick1 /path/to/file
```

### Enable Quorum to Prevent Split-Brain

```bash
# Server-side quorum: bricks go offline when quorum is lost.
gluster volume set myvol cluster.server-quorum-type server
gluster volume set myvol cluster.server-quorum-ratio 51%

# Client-side quorum: clients reject writes without quorum.
gluster volume set myvol cluster.quorum-type auto
```

---

## 9. Client Mounting

### Native FUSE Mount (recommended for performance)

```bash
# Manual mount (server name is used only to fetch the volume config).
sudo mount -t glusterfs node1:/myvol /mnt/gluster

# With options.
sudo mount -t glusterfs \
    -o backupvolfile-server=node2,log-level=WARNING \
    node1:/myvol /mnt/gluster

# /etc/fstab entry for auto-mount at boot.
# node1:/myvol  /mnt/gluster  glusterfs  defaults,_netdev,backupvolfile-server=node2  0  0
```

### NFS-Ganesha (for clients without FUSE support)

The built-in GlusterFS NFS translator is deprecated. NFS-Ganesha is the
supported NFS gateway.

```bash
# Install NFS-Ganesha with GlusterFS FSAL.
sudo apt install nfs-ganesha nfs-ganesha-gluster

# Disable the built-in gluster NFS server first.
gluster volume set myvol nfs.disable on

# Create an export config (/etc/ganesha/exports/export.myvol.conf):
cat > /etc/ganesha/exports/export.myvol.conf <<'EOF'
EXPORT {
    Export_Id = 1;
    Path = "/myvol";
    Pseudo = "/myvol";
    Access_Type = RW;
    Squash = No_Root_Squash;
    FSAL {
        Name = GLUSTER;
        Hostname = "localhost";
        Volume = "myvol";
    }
}
EOF

# Include in main config (/etc/ganesha/ganesha.conf):
# %include "/etc/ganesha/exports/export.myvol.conf"

# Start NFS-Ganesha.
sudo systemctl enable --now nfs-ganesha

# Mount from a client via NFSv4.
sudo mount -t nfs4 ganesha-host:/myvol /mnt/nfs-gluster
```

---

## 10. Volume Tuning and Useful Options

```bash
# Enable performance translators for small-file workloads.
gluster volume set myvol performance.cache-size 256MB
gluster volume set myvol performance.write-behind-window-size 1MB

# Enable readdir-ahead for directory listings.
gluster volume set myvol performance.readdir-ahead on

# SSL/TLS encryption for transport (requires certificate setup).
gluster volume set myvol client.ssl on
gluster volume set myvol server.ssl on

# Set I/O thread count per brick.
gluster volume set myvol performance.io-thread-count 32

# Auth: restrict volume access to specific IP ranges.
gluster volume set myvol auth.allow 192.168.1.*,10.0.0.*
gluster volume set myvol auth.reject *

# View all current options for a volume.
gluster volume get myvol all
```

---

## 11. Firewall Configuration

```bash
# Open glusterd management port.
sudo ufw allow 24007/tcp

# Open brick ports (adjust count to number of bricks per node).
# Example: 4 bricks per node.
sudo ufw allow 49152:49155/tcp

# If using NFS-Ganesha:
sudo ufw allow 2049/tcp
sudo ufw allow 111/tcp
sudo ufw allow 111/udp

# firewalld alternative:
sudo firewall-cmd --permanent --add-port=24007/tcp
sudo firewall-cmd --permanent --add-port=49152-49155/tcp
sudo firewall-cmd --reload
```
