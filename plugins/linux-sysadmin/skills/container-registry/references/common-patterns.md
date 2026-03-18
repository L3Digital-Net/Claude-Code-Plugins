# Container Registry Common Patterns

## Distribution Registry with TLS + Basic Auth

Generate a self-signed certificate (or use a real one), create an htpasswd file, then
run the registry with both TLS and authentication enabled.

```bash
# Generate self-signed cert (replace with real cert for production)
mkdir -p certs auth
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key -x509 -days 365 \
  -out certs/domain.crt \
  -subj "/CN=registry.example.com" \
  -addext "subjectAltName=DNS:registry.example.com"

# Create htpasswd file (bcrypt format is required)
docker run --rm --entrypoint htpasswd httpd:2 -Bbn myuser mypassword > auth/htpasswd

# Run registry with TLS + basic auth
docker run -d \
  -p 443:443 \
  --restart=always \
  --name registry \
  -v "$(pwd)/certs":/certs \
  -v "$(pwd)/auth":/auth \
  -v "$(pwd)/data":/var/lib/registry \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_AUTH=htpasswd \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:3
```

Clients authenticate with `docker login registry.example.com`.

For self-signed certs, each Docker client needs the CA certificate at
`/etc/docker/certs.d/registry.example.com/ca.crt` (no daemon restart required for
this directory; Docker reads it on each pull/push).

## Distribution Registry with config.yml

A complete `config.yml` with filesystem storage, delete enabled, and TLS:

```yaml
version: 0.1
log:
  level: info
  fields:
    service: registry
storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true          # Required for API DELETE and garbage collection
  cache:
    blobdescriptor: inmemory
http:
  addr: 0.0.0.0:5000
  headers:
    X-Content-Type-Options: [nosniff]
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key
auth:
  htpasswd:
    realm: "Registry Realm"
    path: /auth/htpasswd
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

Mount this file into the container:

```bash
docker run -d -p 5000:5000 \
  -v "$(pwd)/config.yml":/etc/distribution/config.yml \
  -v "$(pwd)/certs":/certs \
  -v "$(pwd)/auth":/auth \
  -v "$(pwd)/data":/var/lib/registry \
  --restart=always --name registry \
  registry:3
```

Environment variables override config.yml values. The naming convention is
`REGISTRY_<SECTION>_<KEY>` with underscores for nesting, e.g.
`REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/data`.

## Harbor Docker Compose Setup

Harbor ships as a Docker Compose project. The standard installation flow:

```bash
# Download the installer (check https://github.com/goharbor/harbor/releases for latest)
HARBOR_VERSION=v2.14.2
curl -LO "https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-online-installer-${HARBOR_VERSION}.tgz"
tar xzf "harbor-online-installer-${HARBOR_VERSION}.tgz"
cd harbor

# Copy and edit the configuration template
cp harbor.yml.tmpl harbor.yml
```

Edit `harbor.yml` — the critical fields:

```yaml
hostname: harbor.example.com     # FQDN or IP, never localhost

http:
  port: 80                       # Disable in production by commenting out

https:
  port: 443
  certificate: /etc/ssl/certs/harbor.crt
  private_key: /etc/ssl/private/harbor.key

harbor_admin_password: ChangeMeNow   # Default is Harbor12345

database:
  password: ChangeThisToo            # Internal PostgreSQL password
  max_idle_conns: 50
  max_open_conns: 1000

data_volume: /data                    # All persistent data stored here

# Optional: external storage instead of local filesystem
# storage_service:
#   s3:
#     accesskey: <your-s3-access-key>
#     secretkey: <your-s3-secret-key>
#     region: us-east-1
#     bucket: harbor-registry

# Optional: Trivy vulnerability scanner cache
trivy:
  ignore_unfixed: false
  skip_update: false
  insecure: false
```

Run the installer:

```bash
sudo ./install.sh --with-trivy     # Omit --with-trivy if scanning not needed
```

Harbor manages its own `docker-compose.yml` via the `prepare` script. After editing
`harbor.yml`, reconfigure:

```bash
sudo ./prepare
docker compose down
docker compose up -d
```

## Configuring Docker Daemon for a Private Registry

Edit `/etc/docker/daemon.json` on every Docker client that needs to push/pull:

```json
{
  "insecure-registries": ["registry.example.com:5000"],
  "registry-mirrors": ["https://mirror.example.com"]
}
```

Then restart Docker:

```bash
sudo systemctl restart docker
```

Notes:
- `insecure-registries` allows plaintext HTTP or self-signed HTTPS — use only for
  development/testing. For self-signed certs in production, install the CA cert in
  `/etc/docker/certs.d/<registry>/ca.crt` instead.
- `registry-mirrors` configures a pull-through cache for Docker Hub only. The value
  must be a root URL with no path component.

## Registry as Pull-Through Cache

A Distribution registry can transparently proxy and cache Docker Hub images. Clients
configured to use this mirror pull from Docker Hub through the local cache, reducing
bandwidth and improving pull latency.

`config.yml` for pull-through cache:

```yaml
version: 0.1
log:
  level: info
storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true          # Required for the scheduler to clean expired entries
proxy:
  remoteurl: https://registry-1.docker.io
  # username: dockerhub-user      # Only needed for private images
  # password: dockerhub-token
  ttl: 168h                       # Cache retention; 0 disables expiration
http:
  addr: 0.0.0.0:5000
```

Run the cache registry:

```bash
docker run -d -p 5000:5000 \
  -v "$(pwd)/config.yml":/etc/distribution/config.yml \
  -v "$(pwd)/cache-data":/var/lib/registry \
  --restart=always --name registry-mirror \
  registry:3
```

Configure each Docker client to use the mirror in `/etc/docker/daemon.json`:

```json
{
  "registry-mirrors": ["http://mirror-host:5000"]
}
```

Limitations:
- Pull-through caching only works for Docker Hub (`registry-1.docker.io`), not
  arbitrary upstream registries.
- A pull-through cache cannot be used to push custom images — it is read-only for
  the upstream content.
- If you embed Docker Hub credentials in the proxy config, the mirror can access
  private images that those credentials allow. Secure the mirror accordingly.

## Garbage Collection

### Distribution Registry

GC is a stop-the-world operation. Stop the registry (or set it read-only), run GC,
then restart.

```bash
# Preview what would be deleted
docker exec registry bin/registry garbage-collect \
  --dry-run /etc/distribution/config.yml

# Execute GC
docker stop registry
docker run --rm \
  -v "$(pwd)/config.yml":/etc/distribution/config.yml \
  -v "$(pwd)/data":/var/lib/registry \
  registry:3 \
  bin/registry garbage-collect /etc/distribution/config.yml
docker start registry

# GC including untagged manifests
docker run --rm \
  -v "$(pwd)/config.yml":/etc/distribution/config.yml \
  -v "$(pwd)/data":/var/lib/registry \
  registry:3 \
  bin/registry garbage-collect --delete-untagged /etc/distribution/config.yml
```

Prerequisites for GC to work:
1. `storage.delete.enabled: true` must be set in `config.yml`
2. Manifests must be deleted via the API first (GC only removes unreferenced blobs)
3. The registry should not be accepting writes during GC

### Harbor

Harbor provides GC through the web UI and API, with scheduling support:

1. Navigate to **Administration > Clean Up > Garbage Collection**
2. Optionally enable "Delete Untagged Artifacts"
3. Click **GC Now** or set a schedule (hourly, daily, weekly, or custom cron)
4. Use **Dry Run** first to preview the space that would be freed

Harbor's GC runs online without stopping the registry. It reserves a 2-hour safety
window to avoid deleting blobs from in-progress uploads. GC can only run once per
minute.

## Replication Between Registries (Harbor)

Harbor supports push-based and pull-based replication to/from other registries
(Harbor, Docker Hub, ECR, GCR, ACR, Quay, etc.).

### Setting up replication

1. **Create an endpoint**: Administration > Registries > + New Endpoint
   - Select the provider (Harbor, Docker Hub, AWS ECR, etc.)
   - Enter the URL, access credentials, and test the connection

2. **Create a replication rule**: Administration > Replications > + New Replication Rule
   - Choose Push-based (local to remote) or Pull-based (remote to local)
   - Set source/destination registries
   - Add filters (project name, repository, tag patterns)
   - Configure trigger: Manual, Scheduled (cron), or Event-based (on push)

3. **Execute**: run manually or wait for the trigger

### Example: pull images from Docker Hub into Harbor

1. Create endpoint: Provider = Docker Hub, URL = `https://hub.docker.com`
2. Create pull-based rule: Source = Docker Hub endpoint, filter by repository name
   (e.g. `library/nginx`), destination namespace = `dockerhub-cache`
3. Schedule daily or trigger manually
