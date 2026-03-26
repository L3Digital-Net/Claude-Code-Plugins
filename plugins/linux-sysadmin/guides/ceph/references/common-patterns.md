# Ceph Common Patterns

---

## 1. Bootstrap a New Cluster with Cephadm

Cephadm deploys Ceph daemons as containers (podman or docker). The bootstrap command
creates the first MON and MGR on a single node, then you expand from there.

```bash
# Install cephadm (Debian/Ubuntu).
apt install -y cephadm

# On RHEL/CentOS, download the standalone script:
# curl --silent --remote-name --location \
#     https://download.ceph.com/rpm-squid/el9/noarch/cephadm
# chmod +x cephadm && ./cephadm add-repo --release squid && ./cephadm install

# Bootstrap. This creates the first MON + MGR, enables the dashboard,
# and writes ceph.conf + admin keyring to /etc/ceph/.
sudo cephadm bootstrap --mon-ip 192.168.1.10

# Optional flags:
#   --cluster-network 10.0.0.0/24     (separate replication traffic)
#   --single-host-defaults            (single-node lab/test cluster)
#   --log-to-file                     (write logs to /var/log/ceph/<fsid>/)

# Verify the cluster is running.
sudo ceph status
sudo ceph health detail

# Install the ceph CLI tools on the bootstrap host.
sudo cephadm install ceph-common
```

---

## 2. Expand the Cluster (Hosts, MONs, OSDs)

### Add Hosts

```bash
# Copy the SSH public key to the new host (cephadm uses SSH to deploy).
ssh-copy-id -f -i /etc/ceph/ceph.pub root@node2

# Add the host.
sudo ceph orch host add node2 192.168.1.11

# Label hosts for placement.
sudo ceph orch host label add node2 mon
sudo ceph orch host label add node2 osd
sudo ceph orch host label add node2 _admin   # Grant admin keyring access

# List hosts.
sudo ceph orch host ls
```

### Deploy Additional Monitors

A production cluster needs 3 or 5 monitors for quorum.

```bash
# Deploy 3 monitors automatically on hosts labeled "mon".
sudo ceph orch apply mon --placement="label:mon"

# Or specify exact hosts.
sudo ceph orch apply mon --placement="node1,node2,node3"

# Verify monitors.
sudo ceph mon stat
```

### Deploy OSDs

```bash
# Consume all available unused devices across the cluster.
sudo ceph orch apply osd --all-available-devices

# Deploy OSD on a specific device.
sudo ceph orch daemon add osd node2:/dev/sdb

# Verify OSD topology.
sudo ceph osd tree
sudo ceph osd status
```

---

## 3. Pool Management

### Replicated Pools

```bash
# Create a replicated pool with PG autoscaling.
ceph osd pool create mypool
ceph osd pool set mypool pg_autoscale_mode on

# Set replication factor (default is 3).
ceph osd pool set mypool size 3
ceph osd pool set mypool min_size 2

# Tag the pool for its application.
ceph osd pool application enable mypool rbd
```

### Erasure-Coded Pools

```bash
# Create an EC profile: k=4 data chunks, m=2 parity chunks.
# Tolerates 2 OSD failures. Usable capacity = 4/6 = 66%.
ceph osd erasure-code-profile set ec-42 k=4 m=2

# View the profile.
ceph osd erasure-code-profile get ec-42

# Create an EC pool using the profile.
ceph osd pool create ec-pool 128 erasure ec-42
ceph osd pool application enable ec-pool rgw
```

### Pool Quotas and Deletion

```bash
# Set pool quota.
ceph osd pool set-quota mypool max_bytes $((100 * 1024 * 1024 * 1024))  # 100 GB
ceph osd pool set-quota mypool max_objects 1000000

# Delete a pool (requires double-naming as a safety check).
ceph osd pool delete mypool mypool --yes-i-really-really-mean-it
# Note: mon_allow_pool_delete must be true in config.
```

---

## 4. RBD (Block Device) Operations

### Create, Map, and Use an RBD Image

```bash
# Initialize the pool for RBD.
rbd pool init mypool

# Create a 50 GB image.
rbd create --size 51200 mypool/myimage

# For kernel mapping compatibility, limit features:
rbd create --size 51200 --image-feature layering mypool/myimage

# List images.
rbd ls mypool
rbd info mypool/myimage

# Map the image to a block device.
sudo rbd map mypool/myimage
# Returns /dev/rbd0 (or similar)

# Create a filesystem and mount.
sudo mkfs.ext4 /dev/rbd0
sudo mount /dev/rbd0 /mnt/rbd

# Resize (online grow).
rbd resize --size 102400 mypool/myimage
# Then expand the filesystem:
sudo resize2fs /dev/rbd0

# Unmap when done.
sudo umount /mnt/rbd
sudo rbd unmap /dev/rbd0
```

### RBD Snapshots and Cloning

```bash
# Create a snapshot.
rbd snap create mypool/myimage@snap1

# List snapshots.
rbd snap ls mypool/myimage

# Protect the snapshot (required before cloning).
rbd snap protect mypool/myimage@snap1

# Clone from the protected snapshot.
rbd clone mypool/myimage@snap1 mypool/myclone

# Flatten the clone (copies parent data, makes clone independent).
rbd flatten mypool/myclone

# After flattening, unprotect and optionally delete the snapshot.
rbd snap unprotect mypool/myimage@snap1
rbd snap rm mypool/myimage@snap1

# Rollback to a snapshot (destructive: overwrites current image data).
rbd snap rollback mypool/myimage@snap1
```

### Auto-Map RBD at Boot

```bash
# Add to /etc/ceph/rbdmap:
# mypool/myimage    id=admin,keyring=/etc/ceph/ceph.client.admin.keyring

# Enable the rbdmap service.
sudo systemctl enable rbdmap

# Add to /etc/fstab:
# /dev/rbd/mypool/myimage  /mnt/rbd  ext4  noauto,_netdev  0  0
```

---

## 5. CephFS (File System)

### Create and Mount CephFS

```bash
# Create a CephFS filesystem (deploys MDS daemons automatically).
ceph fs volume create myfs

# Check MDS status.
ceph mds stat
ceph fs status myfs

# Deploy standby MDS for HA.
ceph orch apply mds myfs --placement="count:2"
```

### Mount with Kernel Driver (higher performance)

```bash
# Install client package.
apt install ceph-common

# Get the admin secret.
ceph auth get-key client.admin

# Mount using the mount.ceph helper.
sudo mount -t ceph admin@.myfs=/ /mnt/cephfs \
    -o mon_addr=192.168.1.10:6789,secret=AQBxxxxxxx==

# /etc/fstab entry:
# admin@.myfs=/  /mnt/cephfs  ceph  mon_addr=192.168.1.10:6789,secret=AQBxxxxxxx==,_netdev  0  0
```

### Mount with FUSE (wider compatibility, easier upgrades)

```bash
# Install FUSE client.
apt install ceph-fuse

# Mount.
sudo ceph-fuse -n client.admin /mnt/cephfs

# /etc/fstab entry:
# none  /mnt/cephfs  fuse.ceph  ceph.id=admin,_netdev,defaults  0  0

# Enable systemd mount.
sudo systemctl enable ceph-fuse@/mnt/cephfs
```

---

## 6. RGW (S3-Compatible Object Storage)

### Deploy RGW with Cephadm

```bash
# Simple single-site deployment.
ceph orch apply rgw myrgw --placement="node1"

# With custom port.
ceph orch apply rgw myrgw --placement="node1" --port=8080

# Verify.
ceph orch ls --service-type rgw
ceph orch ps --daemon-type rgw
```

### Multi-Site with Realm/Zone (using the rgw module)

```bash
# Bootstrap a realm (creates realm, zonegroup, zone, and deploys RGW).
ceph rgw realm bootstrap --realm myrealm --zonegroup mygroup \
    --zone myzone --placement="node1 node2"

# Or manual realm/zone setup:
radosgw-admin realm create --rgw-realm=myrealm --default
radosgw-admin zonegroup create --rgw-zonegroup=mygroup \
    --rgw-realm=myrealm --default --master
radosgw-admin zone create --rgw-zone=myzone \
    --rgw-zonegroup=mygroup --default --master
radosgw-admin period update --commit
```

### Create an S3 User and Test

```bash
# Create an S3 user.
radosgw-admin user create --uid=myuser --display-name="My User"
# Output includes access_key and secret_key.

# Test with the AWS CLI.
aws --endpoint-url http://node1:7480 s3 mb s3://mybucket
aws --endpoint-url http://node1:7480 s3 cp testfile.txt s3://mybucket/
aws --endpoint-url http://node1:7480 s3 ls s3://mybucket/
```

---

## 7. CRUSH Map Management

The CRUSH algorithm determines how data is placed across the cluster hierarchy.
Failure domains control where replicas land (host, rack, datacenter).

```bash
# View the current CRUSH tree.
ceph osd crush tree
ceph osd tree

# Create a CRUSH rule that places replicas on different hosts (default).
ceph osd crush rule create-replicated replicated_host default host

# Create a rule that places replicas on different racks.
ceph osd crush rule create-replicated replicated_rack default rack

# Create a rule targeting SSD devices only.
ceph osd crush rule create-replicated ssd_only default host ssd

# Apply a rule to a pool.
ceph osd pool set mypool crush_rule ssd_only

# Set OSD device classes.
ceph osd crush set-device-class ssd osd.0 osd.1 osd.2
ceph osd crush set-device-class hdd osd.3 osd.4 osd.5

# Remove a device class (required before changing class).
ceph osd crush rm-device-class osd.0

# Export the CRUSH map for manual editing.
ceph osd getcrushmap -o crushmap.bin
crushtool -d crushmap.bin -o crushmap.txt
# Edit crushmap.txt...
crushtool -c crushmap.txt -o crushmap-new.bin
ceph osd setcrushmap -i crushmap-new.bin

# Test a CRUSH rule (dry run).
crushtool --test --show-mappings --rule 0 --num-rep 3 -i crushmap.bin
```

---

## 8. Dashboard Setup

```bash
# Enable the dashboard module.
ceph mgr module enable dashboard

# Generate a self-signed SSL certificate.
ceph dashboard create-self-signed-cert

# Or install CA-signed certificate:
# ceph dashboard set-ssl-certificate -i dashboard.crt
# ceph dashboard set-ssl-certificate-key -i dashboard.key

# Create an admin user.
echo 'mypassword' > /tmp/dashboard-pw.txt
ceph dashboard ac-user-create admin -i /tmp/dashboard-pw.txt administrator
rm /tmp/dashboard-pw.txt

# Find the dashboard URL.
ceph mgr services | jq .dashboard
# Typically https://<mgr-host>:8443

# Disable SSL (for testing only).
ceph config set mgr mgr/dashboard/ssl false
# Dashboard then listens on port 8080.

# Configure a specific bind address/port.
ceph config set mgr mgr/dashboard/server_addr 0.0.0.0
ceph config set mgr mgr/dashboard/server_port 8443
```

---

## 9. Monitoring and Maintenance

### Capacity Planning

```bash
# Overall cluster usage.
ceph df detail

# Per-OSD usage.
ceph osd df tree

# Check nearfull and full ratios.
ceph osd dump | grep ratio
# Defaults: nearfull 85%, backfillfull 90%, full 95%.

# Adjust full ratio (emergency, not recommended long-term).
ceph osd set-nearfull-ratio 0.80
ceph osd set-full-ratio 0.97
```

### Performance Monitoring

```bash
# Per-OSD latency (commit_latency_ms, apply_latency_ms).
ceph osd perf

# Slow operations.
ceph daemon osd.<id> dump_historic_ops

# Benchmark a pool.
rados bench -p mypool 60 write --no-cleanup
rados bench -p mypool 60 seq
rados bench -p mypool 60 rand
rados -p mypool cleanup
```

### Maintenance Operations

```bash
# Set noout flag before planned maintenance (prevents data migration).
ceph osd set noout
# ... perform maintenance (reboot host, replace disk, etc.) ...
ceph osd unset noout

# Deep scrub a specific PG.
ceph pg deep-scrub <pgid>

# Compact monitor store (if monitor is slow).
ceph tell mon.<name> compact
```

---

## 10. OSD Replacement

```bash
# Step 1: Mark the OSD out (begins data migration to other OSDs).
ceph osd out osd.5

# Step 2: Wait for recovery to complete.
ceph -w   # Watch until all PGs are active+clean

# Step 3: Stop and remove the OSD daemon.
ceph orch daemon rm osd.5

# Step 4: Purge the OSD from the cluster.
ceph osd purge osd.5 --yes-i-really-mean-it

# Step 5: Replace the physical disk.

# Step 6: Deploy a new OSD on the replacement disk.
ceph orch daemon add osd node2:/dev/sdb
```

---

## 11. Firewall Configuration

```bash
# UFW example.
sudo ufw allow 3300/tcp    # Monitor msgr2
sudo ufw allow 6789/tcp    # Monitor msgr1
sudo ufw allow 6800:7568/tcp  # OSD, MDS, MGR daemons
sudo ufw allow 8443/tcp    # Dashboard
sudo ufw allow 7480/tcp    # RGW

# firewalld example.
sudo firewall-cmd --permanent --add-port=3300/tcp
sudo firewall-cmd --permanent --add-port=6789/tcp
sudo firewall-cmd --permanent --add-port=6800-7568/tcp
sudo firewall-cmd --permanent --add-port=8443/tcp
sudo firewall-cmd --permanent --add-port=7480/tcp
sudo firewall-cmd --reload

# If using separate public and cluster networks, open 6800-7568
# on both network interfaces.
```

---

## 12. Ceph Upgrade (Cephadm)

```bash
# Check current versions.
ceph versions

# Start the upgrade (cephadm rolls through daemons automatically).
ceph orch upgrade start --ceph-version 19.2.3

# Monitor progress.
ceph orch upgrade status
ceph -s

# If something goes wrong, pause the upgrade.
ceph orch upgrade pause

# Resume after fixing the issue.
ceph orch upgrade resume

# After completion, verify.
ceph versions
ceph health detail
```
