# MinIO Common Patterns

Each section is a standalone task with copy-paste-ready commands. Replace
`ALIAS` with your mc alias name and adjust paths/IPs for your environment.

---

## 1. Single-Node Deployment (Bare Metal with systemd)

For evaluation or small workloads. Provides erasure coding when given 4+ drives.

```bash
# Download and install the MinIO server binary.
curl -O https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Create a dedicated user and data directories (4 drives minimum for erasure coding).
sudo useradd -r -s /sbin/nologin minio-user
sudo mkdir -p /data/minio{1..4}
sudo chown -R minio-user:minio-user /data/minio{1..4}
```

**Environment file** (`/etc/default/minio`):
```bash
MINIO_ROOT_USER=minio-admin
MINIO_ROOT_PASSWORD=change-me-strong-password
MINIO_VOLUMES="/data/minio{1...4}"
MINIO_OPTS="--console-address :9001"
```

**Systemd unit** (`/etc/systemd/system/minio.service`):
```ini
[Unit]
Description=MinIO Object Storage
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server $MINIO_VOLUMES $MINIO_OPTS
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now minio
sudo systemctl status minio
```

---

## 2. Docker Compose Deployment

```yaml
# docker-compose.yml
services:
  minio:
    image: minio/minio:latest
    container_name: minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minio-admin
      MINIO_ROOT_PASSWORD: change-me-strong-password
    volumes:
      - minio-data:/data
    command: server /data --console-address ":9001"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  minio-data:
```

```bash
docker compose up -d
docker compose logs minio        # verify startup
```

---

## 3. Multi-Node Distributed Deployment

Four nodes, four drives each (16 drives total). Provides erasure coding across
nodes for production-grade durability.

On each node, install the MinIO binary and create `/data/minio{1..4}`.

**Environment file** (same on all nodes):
```bash
MINIO_ROOT_USER=minio-admin
MINIO_ROOT_PASSWORD=change-me-strong-password
MINIO_VOLUMES="http://minio{1...4}.example.com:9000/data/minio{1...4}"
MINIO_OPTS="--console-address :9001"
```

The `{1...4}` expansion syntax (three dots) is MinIO-specific. It tells the server
to expect nodes minio1 through minio4, each with drives /data/minio1 through
/data/minio4.

Start the service on all four nodes. They discover each other via the
`MINIO_VOLUMES` URL pattern.

---

## 4. mc Client Setup and Basic Operations

```bash
# Install mc.
curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure an alias.
mc alias set myminio http://minio.example.com:9000 minio-admin change-me-strong-password

# Verify connectivity.
mc admin info myminio

# Create a bucket.
mc mb myminio/backups

# Upload files.
mc cp /var/backups/daily.tar.gz myminio/backups/
mc cp --recursive /var/log/app/ myminio/backups/logs/

# Download files.
mc cp myminio/backups/daily.tar.gz /tmp/

# List objects.
mc ls myminio/backups/

# Get object metadata.
mc stat myminio/backups/daily.tar.gz

# Remove objects.
mc rm myminio/backups/old-file.txt
mc rm --recursive --force myminio/backups/old-prefix/

# Mirror a directory (sync with deletion -- like rclone sync).
mc mirror /var/backups/ myminio/backups/

# Mirror without deleting destination extras.
mc mirror --overwrite /var/backups/ myminio/backups/
```

---

## 5. User and Policy Management

MinIO has built-in policies: `readonly`, `readwrite`, `writeonly`,
`diagnostics`, and `consoleAdmin`.

```bash
# Create a new user.
mc admin user add myminio app-user app-password

# Attach a built-in policy.
mc admin policy attach myminio readwrite --user app-user

# Create a custom policy that grants access to one bucket only.
cat > /tmp/bucket-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::app-data",
        "arn:aws:s3:::app-data/*"
      ]
    }
  ]
}
POLICY

mc admin policy create myminio app-data-rw /tmp/bucket-policy.json
mc admin policy attach myminio app-data-rw --user app-user

# List users and their policies.
mc admin user list myminio

# Disable a user (preserves the account but blocks access).
mc admin user disable myminio app-user

# Create access keys (programmatic credentials) for a user.
mc admin accesskey create myminio app-user
```

---

## 6. Bucket Versioning

Versioning keeps all previous versions of an object. Required for replication
and object locking. Once enabled, versioning can be suspended but never fully
disabled.

```bash
# Enable versioning.
mc version enable myminio/app-data

# Verify.
mc version info myminio/app-data

# List object versions.
mc ls --versions myminio/app-data/config.json

# Restore a previous version by copying it over the current version.
mc cp --version-id VERSION_ID myminio/app-data/config.json myminio/app-data/config.json

# Permanently delete a specific version.
mc rm --version-id VERSION_ID myminio/app-data/config.json

# Suspend versioning (new objects no longer get version IDs; existing versions remain).
mc version suspend myminio/app-data
```

---

## 7. Lifecycle Rules (Expiration and Transition)

Lifecycle rules automate object deletion and tiering.

```bash
# Expire objects older than 90 days in a bucket.
mc ilm rule add myminio/logs --expire-days 90

# Expire objects with a specific prefix after 30 days.
mc ilm rule add myminio/logs --expire-days 30 --prefix "tmp/"

# Expire noncurrent versions after 7 days (versioned bucket).
mc ilm rule add myminio/app-data --noncurrent-expire-days 7

# Transition objects to a remote tier after 30 days.
# First, create the tier:
mc admin tier add s3 myminio COLD-S3 \
    --endpoint https://s3.amazonaws.com \
    --access-key ACCESS_KEY \
    --secret-key SECRET_KEY \
    --bucket my-cold-bucket \
    --region us-east-1

# Then create the transition rule:
mc ilm rule add myminio/app-data --transition-days 30 --storage-class COLD-S3

# List all rules on a bucket.
mc ilm rule ls myminio/app-data

# Remove a rule by ID.
mc ilm rule rm myminio/app-data --id RULE_ID
```

---

## 8. Bucket Replication

Replication copies objects between buckets on different MinIO deployments.
Both buckets must have versioning enabled.

```bash
# Enable versioning on source and remote.
mc version enable myminio/important-data
mc version enable remote/important-data

# Add a one-way replication rule.
mc replicate add myminio/important-data \
    --remote-bucket "https://repl-user:repl-pass@remote.example.com:9000/important-data" \
    --replicate "delete,delete-marker,existing-objects"

# Check replication status.
mc replicate status myminio/important-data

# List replication rules.
mc replicate ls myminio/important-data

# Remove a replication rule.
mc replicate rm myminio/important-data --id RULE_ID
```

For multi-site active-active replication across entire deployments (IAM, buckets,
policies), use site replication:

```bash
mc admin replicate add site1-alias site2-alias site3-alias
mc admin replicate info site1-alias
```

---

## 9. TLS Configuration

MinIO auto-enables HTTPS when it finds valid certificates in the certs directory.

```bash
# Default cert directory.
mkdir -p ~/.minio/certs

# Place certificates (file names must be exact).
cp server.crt ~/.minio/certs/public.crt
cp server.key ~/.minio/certs/private.key

# For CA-signed certs, include the CA bundle.
cp ca.crt ~/.minio/certs/CAs/

# Custom certs directory (useful for systemd).
minio server /data --certs-dir /etc/minio/certs --console-address ":9001"

# Update mc alias to use HTTPS.
mc alias set myminio https://minio.example.com:9000 minio-admin password

# MinIO auto-reloads modified certs. For new cert directories, send SIGHUP:
sudo kill -SIGHUP $(pidof minio)
```

For SNI with multiple domains, create subdirectories under `certs/`, each
containing `public.crt` and `private.key`. MinIO matches the client's requested
hostname against each certificate's SAN.

---

## 10. Monitoring with Prometheus

```bash
# Generate Prometheus scrape config.
mc admin prometheus generate myminio

# Output includes a scrape_configs block like:
# - job_name: minio-job
#   bearer_token: <token>
#   metrics_path: /minio/v2/metrics/cluster
#   scheme: http
#   static_configs:
#     - targets: ['minio.example.com:9000']
```

Key metrics to monitor:
- `minio_cluster_disk_online_total` / `minio_cluster_disk_total` (drive health)
- `minio_cluster_capacity_usable_free_bytes` (available storage)
- `minio_s3_requests_total` (request throughput)
- `minio_s3_requests_errors_total` (error rate)
- `minio_node_process_resident_memory_bytes` (memory usage)

---

## 11. Erasure Coding Reference

MinIO splits drives in each server pool into erasure sets (2-16 drives per set,
expandable to 32 with `MINIO_ERASURE_SET_DRIVE_COUNT`).

| Drives in set | Default parity (EC:M) | Usable capacity | Drives tolerated down |
|---------------|----------------------|-----------------|----------------------|
| 4 | EC:2 | 50% | 2 |
| 8 | EC:4 | 50% | 4 |
| 16 | EC:4 | 75% | 4 |

- **Read quorum**: K data shards (N - M drives must be online to read)
- **Write quorum**: K data shards (same as read; K+1 when parity = N/2, for split-brain protection)
- Erasure set size is fixed at deployment. You cannot add drives to an existing pool.
- Expand capacity by adding a new server pool with `minio server /data{1...4} http://new{1...4}:9000/data{1...4}`.

```bash
# Override default parity for a specific bucket with storage class.
mc admin config set myminio storage_class standard=EC:3

# Verify erasure coding status.
mc admin info myminio
```
