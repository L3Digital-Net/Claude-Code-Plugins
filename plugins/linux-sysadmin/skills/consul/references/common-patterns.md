# Consul Common Patterns

Commands assume a running Consul agent. For ACL-enabled clusters, set `CONSUL_HTTP_TOKEN`
or pass `-token=<token>` with each command. Replace placeholder values with your own.

---

## 1. Server Agent Configuration (Production)

Minimum viable 3-server cluster. Place this in `/etc/consul.d/consul.hcl` on each server.

```hcl
# /etc/consul.d/consul.hcl -- server node

datacenter = "dc1"
node_name  = "consul-server-1"
data_dir   = "/opt/consul/data"
log_level  = "INFO"

# Server mode
server           = true
bootstrap_expect = 3

# Networking
bind_addr   = "0.0.0.0"
client_addr = "0.0.0.0"

# Cluster join -- list all server IPs (or use cloud auto-join)
retry_join = ["10.0.1.10", "10.0.1.11", "10.0.1.12"]

# Web UI
ui_config {
  enabled = true
}

# Enable Connect (service mesh)
connect {
  enabled = true
}

# Gossip encryption -- generate with: consul keygen
encrypt = "<GOSSIP_KEY>"

# TLS (recommended for production)
tls {
  defaults {
    ca_file   = "/etc/consul.d/tls/consul-agent-ca.pem"
    cert_file = "/etc/consul.d/tls/dc1-server-consul-0.pem"
    key_file  = "/etc/consul.d/tls/dc1-server-consul-0-key.pem"
    verify_incoming = true
    verify_outgoing = true
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

# Performance tuning
performance {
  raft_multiplier = 1
}
```

### Generate TLS Certificates (Built-in CA)

```bash
# Create the CA
consul tls ca create

# Create server certificates (one per server)
consul tls cert create -server -dc dc1
consul tls cert create -server -dc dc1
consul tls cert create -server -dc dc1

# Create client certificates
consul tls cert create -client -dc dc1
```

---

## 2. Client Agent Configuration

Place on every non-server node that runs services.

```hcl
# /etc/consul.d/consul.hcl -- client node

datacenter = "dc1"
node_name  = "app-server-1"
data_dir   = "/opt/consul/data"

# Client mode (server = false is default, but explicit for clarity)
server = false

bind_addr  = "0.0.0.0"
client_addr = "127.0.0.1"

retry_join = ["10.0.1.10", "10.0.1.11", "10.0.1.12"]

encrypt = "<GOSSIP_KEY>"

tls {
  defaults {
    ca_file   = "/etc/consul.d/tls/consul-agent-ca.pem"
    cert_file = "/etc/consul.d/tls/dc1-client-consul-0.pem"
    key_file  = "/etc/consul.d/tls/dc1-client-consul-0-key.pem"
    verify_incoming = false
    verify_outgoing = true
  }
}
```

---

## 3. Service Registration

### File-based (recommended for static services)

Place in `/etc/consul.d/web.hcl` and run `consul reload`.

```hcl
service {
  name = "web"
  id   = "web-1"
  port = 8080
  tags = ["production", "v2"]

  meta = {
    version = "2.1.0"
  }

  check {
    http     = "http://localhost:8080/health"
    interval = "10s"
    timeout  = "3s"
    deregister_critical_service_after = "90s"
  }

  # Enable sidecar proxy for service mesh
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "api"
            local_bind_port  = 9091
          }
        ]
      }
    }
  }
}
```

### API-based (for dynamic/ephemeral services)

```bash
# Register
curl --request PUT \
  --header "X-Consul-Token: <TOKEN>" \
  --data '{
    "Name": "api",
    "ID": "api-1",
    "Port": 3000,
    "Tags": ["production"],
    "Check": {
      "HTTP": "http://localhost:3000/health",
      "Interval": "10s",
      "Timeout": "3s"
    }
  }' http://127.0.0.1:8500/v1/agent/service/register

# Deregister
curl --request PUT \
  --header "X-Consul-Token: <TOKEN>" \
  http://127.0.0.1:8500/v1/agent/service/deregister/api-1

# List all services on this agent
curl -s http://127.0.0.1:8500/v1/agent/services | jq

# Get health of a specific service
curl -s http://127.0.0.1:8500/v1/health/service/web?passing | jq
```

### Multiple services in one file

```hcl
services {
  name = "redis"
  id   = "redis-primary"
  port = 6379
  tags = ["primary"]
  check {
    tcp      = "localhost:6379"
    interval = "5s"
  }
}

services {
  name = "redis"
  id   = "redis-replica"
  port = 6380
  tags = ["replica"]
  check {
    tcp      = "localhost:6380"
    interval = "5s"
  }
}
```

---

## 4. ACL Bootstrap and Token Management

### Enable and bootstrap

```bash
# 1. Add ACL config to ALL agents, then restart
#    (add to /etc/consul.d/consul.hcl)
#
#    acl {
#      enabled        = true
#      default_policy = "allow"        # start with allow; switch to deny after tokens are ready
#      enable_token_persistence = true
#    }

# 2. Restart all servers, then all clients
sudo systemctl restart consul

# 3. Bootstrap (run once, on any server)
consul acl bootstrap
# Save the SecretID -- this is your management token.
export CONSUL_HTTP_TOKEN="<bootstrap-secret-id>"
```

### Create agent tokens

```bash
# Server agent token (node identity grants node:write and service:read)
consul acl token create \
  -description "consul-server-1 agent token" \
  -node-identity "consul-server-1:dc1"

# Apply to the agent
consul acl set-agent-token agent "<agent-token-secret-id>"
```

### Create a service token with a custom policy

```hcl
# web-policy.hcl
service "web" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}
node_prefix "" {
  policy = "read"
}
```

```bash
consul acl policy create -name "web-policy" -rules @web-policy.hcl

consul acl token create \
  -description "web service token" \
  -policy-name "web-policy"
```

### Switch to default-deny

After all agents and services have tokens:

```hcl
acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true
  tokens {
    agent = "<agent-token>"
  }
}
```

Restart agents with the updated config. Services without tokens will lose access.

---

## 5. KV Store Operations

```bash
# Write a value
consul kv put config/app/db_host "db.internal"
consul kv put config/app/db_port "5432"

# Read a single key
consul kv get config/app/db_host

# Read with metadata (index, flags, session)
consul kv get -detailed config/app/db_host

# List all keys under a prefix
consul kv get -recurse config/app/

# Delete a key
consul kv delete config/app/db_port

# Delete all keys under a prefix
consul kv delete -recurse config/app/

# Export to JSON (for backup or migration)
consul kv export config/ > kv-backup.json

# Import from JSON
consul kv import @kv-backup.json

# Check-and-set (CAS) -- update only if the ModifyIndex matches
consul kv put -cas -modify-index=123 config/app/db_host "new-db.internal"

# Atomic transactions via API (read + write in one operation)
curl --request PUT \
  --data '[
    {"KV": {"Verb": "get", "Key": "config/app/db_host"}},
    {"KV": {"Verb": "set", "Key": "config/app/db_host", "Value": "'$(echo -n "new-value" | base64)'"}}
  ]' http://127.0.0.1:8500/v1/txn
```

### Watch for KV changes

```bash
# Trigger a script when a key changes
consul watch -type=key -key=config/app/db_host /usr/local/bin/on-config-change.sh

# Watch a prefix
consul watch -type=keyprefix -prefix=config/app/ /usr/local/bin/reload-app.sh
```

---

## 6. Connect (Service Mesh) with Envoy

### Enable Connect in agent config

```hcl
connect {
  enabled = true
}
```

### Start sidecar proxies

```bash
# Start the Envoy sidecar for a registered service
consul connect envoy -sidecar-for web

# With a custom admin port (avoids conflicts when multiple sidecars on one host)
consul connect envoy -sidecar-for web -admin-bind 127.0.0.1:19001

# Start sidecar for a second service
consul connect envoy -sidecar-for api -admin-bind 127.0.0.1:19002
```

### Manage intentions (authorization)

```bash
# Allow web -> api
consul intention create web api

# Deny all to a sensitive service
consul intention create -deny '*' secrets-svc

# Check if a connection is allowed
consul intention check web api
# Returns: Allowed

# List all intentions
consul intention list

# Delete an intention
consul intention delete web api
```

### Config entries for L7 traffic management

```hcl
# service-defaults.hcl -- set protocol so Consul can do L7 routing
Kind     = "service-defaults"
Name     = "api"
Protocol = "http"
```

```bash
consul config write service-defaults.hcl
```

### Upstream configuration in service definition

When service "web" needs to talk to service "api" through the mesh:

```hcl
service {
  name = "web"
  port = 8080
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "api"
            local_bind_port  = 9091
          }
        ]
      }
    }
  }
}
```

The web application connects to `localhost:9091` and the sidecar transparently
routes to a healthy `api` instance over mTLS.

---

## 7. DNS Forwarding

Consul DNS listens on port 8600. To make `*.service.consul` resolvable system-wide,
forward the `.consul` domain from your system resolver.

### systemd-resolved

```ini
# /etc/systemd/resolved.conf.d/consul.conf
[Resolve]
DNS=127.0.0.1:8600
Domains=~consul
```

```bash
sudo systemctl restart systemd-resolved
# Test
resolvectl query web.service.consul
```

### dnsmasq

```
# /etc/dnsmasq.d/consul.conf
server=/consul/127.0.0.1#8600
```

```bash
sudo systemctl restart dnsmasq
```

### unbound

```yaml
# /etc/unbound/unbound.conf.d/consul.conf
server:
  do-not-query-localhost: no

stub-zone:
  name: "consul."
  stub-addr: 127.0.0.1@8600
```

### DNS query examples

```bash
# A record (IP address)
dig @127.0.0.1 -p 8600 web.service.consul

# SRV record (includes port)
dig @127.0.0.1 -p 8600 web.service.consul SRV

# Filter by tag
dig @127.0.0.1 -p 8600 production.web.service.consul

# Cross-datacenter query
dig @127.0.0.1 -p 8600 web.service.dc2.consul

# Node query
dig @127.0.0.1 -p 8600 app-server-1.node.consul

# RFC 2782 format (with underscores)
dig @127.0.0.1 -p 8600 _web._tcp.service.consul SRV

# Prepared query (by query name)
dig @127.0.0.1 -p 8600 my-failover-query.query.consul
```

---

## 8. Prepared Queries (Geo-Failover)

Prepared queries are managed exclusively through the HTTP API.

### Create a failover query

```bash
# Static failover: prefer dc1, then dc2, then dc3
curl --request POST \
  --header "X-Consul-Token: <TOKEN>" \
  --data '{
    "Name": "web-failover",
    "Service": {
      "Service": "web",
      "OnlyPassing": true,
      "Tags": ["production"]
    },
    "DNS": {
      "TTL": "10s"
    },
    "Failover": {
      "Datacenters": ["dc2", "dc3"]
    }
  }' http://127.0.0.1:8500/v1/query

# Dynamic failover: nearest N datacenters by network round-trip time
curl --request POST \
  --header "X-Consul-Token: <TOKEN>" \
  --data '{
    "Name": "api-nearest",
    "Service": {
      "Service": "api",
      "OnlyPassing": true
    },
    "Failover": {
      "NearestN": 3
    }
  }' http://127.0.0.1:8500/v1/query
```

### Query via DNS

```bash
dig @127.0.0.1 -p 8600 web-failover.query.consul
dig @127.0.0.1 -p 8600 api-nearest.query.consul
```

### Query via HTTP API

```bash
# List all prepared queries
curl -s http://127.0.0.1:8500/v1/query | jq

# Execute a query by ID
curl -s http://127.0.0.1:8500/v1/query/<query-id>/execute | jq
```

### Template query (match multiple services)

```bash
# Catch-all: any service name queried as <name>.query.consul
# gets automatic nearest-datacenter failover
curl --request POST \
  --header "X-Consul-Token: <TOKEN>" \
  --data '{
    "Name": "",
    "Template": {
      "Type": "name_prefix_match",
      "Regexp": "^(.+)$"
    },
    "Service": {
      "Service": "${match(1)}",
      "OnlyPassing": true
    },
    "Failover": {
      "NearestN": 2
    }
  }' http://127.0.0.1:8500/v1/query
```

---

## 9. Snapshots and Disaster Recovery

```bash
# Save a point-in-time snapshot (includes KV, catalog, ACLs, sessions, prepared queries)
consul snapshot save backup-$(date +%Y%m%d-%H%M%S).snap

# Inspect a snapshot (version, size, index)
consul snapshot inspect backup.snap

# Restore a snapshot (same Consul version required)
consul snapshot restore backup.snap

# Save with stale read (reduces load on leader, may miss last ~100ms of writes)
consul snapshot save -stale backup.snap
```

### Automated backup via cron (Community Edition)

```bash
# /etc/cron.d/consul-backup
0 */6 * * * consul consul snapshot save /var/backups/consul/consul-$(date +\%Y\%m\%d-\%H\%M\%S).snap 2>&1 | logger -t consul-backup
```

Snapshots are gzipped tar archives containing Raft metadata and a binary-serialized
state dump, verified internally with SHA-256 checksums. They contain sensitive data
(ACL tokens, KV values); store them encrypted and access-controlled.

---

## 10. Gossip Encryption Key Rotation

```bash
# 1. Generate a new key
consul keygen
# Output: <NEW_KEY>

# 2. Install the new key on ALL agents (does not make it primary yet)
consul keyring -install="<NEW_KEY>"

# 3. Verify all agents have both keys
consul keyring -list

# 4. Make the new key primary on ALL agents
consul keyring -use="<NEW_KEY>"

# 5. Remove the old key from ALL agents
consul keyring -remove="<OLD_KEY>"
```

All four steps must complete across every agent before removing the old key.
If an agent misses a step, it will be unable to communicate with the cluster.

---

## 11. Health Check Examples

### HTTP check

```hcl
check {
  id       = "web-health"
  name     = "Web HTTP check"
  http     = "http://localhost:8080/health"
  method   = "GET"
  interval = "10s"
  timeout  = "3s"
}
```

### TCP check

```hcl
check {
  id       = "redis-tcp"
  name     = "Redis TCP check"
  tcp      = "localhost:6379"
  interval = "5s"
  timeout  = "2s"
}
```

### Script check

```hcl
check {
  id       = "disk-usage"
  name     = "Disk usage check"
  args     = ["/usr/local/bin/check_disk.sh"]
  interval = "30s"
  timeout  = "10s"
}
```

### TTL check (application heartbeat)

```hcl
check {
  id   = "app-ttl"
  name = "App TTL heartbeat"
  ttl  = "30s"
}
```

```bash
# Application calls this endpoint to report healthy
curl --request PUT http://127.0.0.1:8500/v1/agent/check/pass/app-ttl

# Report warning
curl --request PUT http://127.0.0.1:8500/v1/agent/check/warn/app-ttl

# Report critical
curl --request PUT http://127.0.0.1:8500/v1/agent/check/fail/app-ttl
```

### gRPC check

```hcl
check {
  id       = "grpc-svc"
  name     = "gRPC health check"
  grpc     = "localhost:50051"
  grpc_use_tls = true
  interval = "10s"
}
```

### Deregister on sustained failure

```hcl
check {
  http     = "http://localhost:8080/health"
  interval = "10s"
  deregister_critical_service_after = "90s"
}
```

The service is automatically removed from the catalog after 90 seconds of continuous
critical status. Useful for ephemeral or auto-scaling workloads.
