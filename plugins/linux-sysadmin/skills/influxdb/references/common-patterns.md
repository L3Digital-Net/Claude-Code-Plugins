# InfluxDB Common Patterns

Each section is a complete, copy-paste-ready reference. InfluxDB 3 uses CLI flags and
environment variables for all configuration; there is no config file.

---

## 1. Start the Server (Production)

For production, use file-based or S3-backed object storage with a persistent data
directory and a unique node ID.

```bash
# File-based object store (simplest production setup)
influxdb3 serve \
  --object-store file \
  --data-dir /var/lib/influxdb3 \
  --node-id prod01 \
  --http-bind 0.0.0.0:8181

# With authentication enabled (default; create admin token on first run)
influxdb3 serve \
  --object-store file \
  --data-dir /var/lib/influxdb3 \
  --node-id prod01

# S3-backed object store
influxdb3 serve \
  --object-store s3 \
  --bucket my-influxdb-bucket \
  --aws-access-key-id "$AWS_ACCESS_KEY_ID" \
  --aws-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
  --aws-default-region us-east-1 \
  --node-id prod01

# Development mode (in-memory, no persistence)
influxdb3 serve --object-store memory --node-id dev01
```

Or via systemd (DEB/RPM install):

```bash
sudo systemctl enable --now influxdb3-core
systemctl status influxdb3-core
journalctl -u influxdb3-core -f
```

---

## 2. Database Management

InfluxDB 3 uses databases (replacing v2 "buckets"). Tables are auto-created on first write
based on the measurement name in line protocol.

```bash
# Create a database
influxdb3 create database sensors --host http://localhost:8181

# Create with retention policy (auto-delete data older than 30 days)
influxdb3 create database sensors --retention 30d --host http://localhost:8181

# List databases
influxdb3 show databases --host http://localhost:8181

# Delete a database (irreversible)
influxdb3 delete database sensors --host http://localhost:8181
```

---

## 3. Write Data (Line Protocol)

InfluxDB uses line protocol format: `<measurement>,<tag_key>=<tag_val> <field_key>=<field_val> [timestamp]`

```bash
# Single line via CLI
influxdb3 write --database sensors --host http://localhost:8181 \
  'temperature,location=office,sensor=dht22 value=23.5'

# Multiple lines via CLI
influxdb3 write --database sensors --host http://localhost:8181 \
  'temperature,location=office value=23.5
temperature,location=lab value=19.2
humidity,location=office value=45.0'

# Write from file
influxdb3 write --database sensors --host http://localhost:8181 \
  --file /path/to/data.lp

# Write via HTTP API (v3 endpoint)
curl -X POST 'http://localhost:8181/api/v3/write_lp?db=sensors' \
  -H 'Content-Type: text/plain' \
  -d 'temperature,location=office value=23.5'

# Write via v2-compatible endpoint (for Telegraf and existing tools)
curl -X POST 'http://localhost:8181/api/v2/write?bucket=sensors' \
  -H 'Content-Type: text/plain' \
  -d 'temperature,location=office value=23.5'
```

---

## 4. Query Data (SQL)

SQL is the primary query language in InfluxDB 3. All tables have a `time` column
with nanosecond precision.

```bash
# Basic query
influxdb3 query --database sensors --host http://localhost:8181 \
  "SELECT * FROM temperature ORDER BY time DESC LIMIT 10"

# Aggregation
influxdb3 query --database sensors --host http://localhost:8181 \
  "SELECT location, AVG(value) as avg_temp
   FROM temperature
   WHERE time > now() - INTERVAL '1 hour'
   GROUP BY location"

# Time bucketing (use date_bin for fixed intervals)
influxdb3 query --database sensors --host http://localhost:8181 \
  "SELECT date_bin(INTERVAL '5 minutes', time) as bucket,
          location,
          AVG(value) as avg_temp,
          MAX(value) as max_temp
   FROM temperature
   WHERE time > now() - INTERVAL '24 hours'
   GROUP BY bucket, location
   ORDER BY bucket DESC"

# Via HTTP API
curl -G 'http://localhost:8181/api/v3/query_sql' \
  --data-urlencode 'db=sensors' \
  --data-urlencode 'q=SELECT * FROM temperature LIMIT 5' \
  --data-urlencode 'format=json'
```

---

## 5. Query Data (InfluxQL)

InfluxQL is supported for backward compatibility with v1/v2 workflows.

```bash
# InfluxQL via CLI
influxdb3 query --database sensors --host http://localhost:8181 \
  --language influxql \
  "SELECT MEAN(value) FROM temperature WHERE time > now() - 1h GROUP BY time(5m), location"

# Via HTTP API (v1-compatible endpoint)
curl -G 'http://localhost:8181/api/v1/query' \
  --data-urlencode 'db=sensors' \
  --data-urlencode 'q=SELECT MEAN(value) FROM temperature WHERE time > now() - 1h GROUP BY time(5m)'
```

---

## 6. Token Management

InfluxDB 3 uses bearer tokens for authentication. The first admin token is created
during initial setup or via the CLI.

```bash
# Create admin token (full access)
influxdb3 create token --admin --host http://localhost:8181

# Create scoped token (read-only on specific database)
influxdb3 create token \
  --read-database sensors \
  --host http://localhost:8181

# Create read/write token
influxdb3 create token \
  --read-database sensors \
  --write-database sensors \
  --host http://localhost:8181

# List tokens
influxdb3 show tokens --host http://localhost:8181

# Delete token
influxdb3 delete token <token-id> --host http://localhost:8181

# Use token in API calls
curl -H "Authorization: Bearer $INFLUX_TOKEN" \
  'http://localhost:8181/api/v3/query_sql?db=sensors&q=SELECT+*+FROM+temperature'
```

---

## 7. Telegraf Integration

Telegraf writes to InfluxDB 3 Core via the `outputs.influxdb_v2` plugin,
using the v2-compatible write endpoint.

```toml
# /etc/telegraf/telegraf.conf (relevant sections)

[[outputs.influxdb_v2]]
  # InfluxDB 3 Core endpoint
  urls = ["http://localhost:8181"]

  # Authentication token from influxdb3 create token
  # Store in environment variable: INFLUX_TOKEN
  token = "$INFLUX_TOKEN"

  # Leave empty for InfluxDB 3 Core (not used)
  organization = ""

  # Database name (called "bucket" in v2 terminology)
  bucket = "sensors"

  # Optional: TLS configuration
  # tls_ca = "/etc/telegraf/ca.pem"
  # tls_cert = "/etc/telegraf/cert.pem"
  # tls_key = "/etc/telegraf/key.pem"
  # insecure_skip_verify = false

# Example input: system metrics
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.net]]
```

```bash
# Test Telegraf config
telegraf --config /etc/telegraf/telegraf.conf --test

# Start Telegraf
sudo systemctl enable --now telegraf

# Verify data arriving
influxdb3 query --database sensors --host http://localhost:8181 \
  "SELECT * FROM cpu ORDER BY time DESC LIMIT 5"
```

---

## 8. Retention and Storage Tuning

Retention policies control how long data is kept. Storage tuning affects write
performance and disk usage.

```bash
# Set retention on database creation
influxdb3 create database metrics --retention 90d --host http://localhost:8181

# Server-wide defaults via serve flags
influxdb3 serve \
  --object-store file \
  --data-dir /var/lib/influxdb3 \
  --node-id prod01 \
  --hard-delete-default-duration 90d \
  --retention-check-interval 30m \
  --gen1-duration 10m \
  --wal-flush-interval 1s \
  --wal-snapshot-size 600 \
  --parquet-mem-cache-size 4294967296
```

Key tuning parameters:

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `--hard-delete-default-duration` | 90d | Default retention for new databases |
| `--retention-check-interval` | 30m | How often to check for expired data |
| `--gen1-duration` | 10m | Parquet file time window (1m, 5m, 10m) |
| `--wal-flush-interval` | 1s | How often WAL flushes to disk |
| `--wal-snapshot-size` | 600 | WAL files per snapshot |
| `--parquet-mem-cache-size` | 20% RAM | Parquet read cache |
| `--exec-mem-pool-bytes` | 8 GB | Query execution memory pool |

---

## 9. TLS Configuration

Enable HTTPS for production deployments.

```bash
influxdb3 serve \
  --object-store file \
  --data-dir /var/lib/influxdb3 \
  --node-id prod01 \
  --tls-cert /etc/influxdb3/cert.pem \
  --tls-key /etc/influxdb3/key.pem \
  --http-bind 0.0.0.0:8181

# CLI access with TLS
influxdb3 show databases --host https://influxdb.example.com:8181
```

---

## 10. Docker Deployment

```bash
# Basic Docker run
docker run -d --name influxdb3 \
  -p 8181:8181 \
  -v influxdb3-data:/var/lib/influxdb3 \
  influxdb:3-core

# With custom configuration
docker run -d --name influxdb3 \
  -p 8181:8181 \
  -v influxdb3-data:/var/lib/influxdb3 \
  -e INFLUXDB3_NODE_IDENTIFIER_PREFIX=prod01 \
  -e INFLUXDB3_LOG_FILTER=info \
  influxdb:3-core \
  serve --object-store file --data-dir /var/lib/influxdb3

# Docker Compose
# version: "3"
# services:
#   influxdb:
#     image: influxdb:3-core
#     ports:
#       - "8181:8181"
#     volumes:
#       - influxdb3-data:/var/lib/influxdb3
#     environment:
#       - INFLUXDB3_NODE_IDENTIFIER_PREFIX=prod01
#     command: serve --object-store file --data-dir /var/lib/influxdb3
# volumes:
#   influxdb3-data:
```
