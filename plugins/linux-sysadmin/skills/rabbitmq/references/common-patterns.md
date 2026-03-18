# RabbitMQ Common Patterns

Each section is a complete, copy-paste-ready example. Commands run via
`rabbitmqctl`, `rabbitmq-plugins`, or `rabbitmqadmin` (bundled with management plugin).

---

## 1. Vhost and User Setup

Isolate applications with dedicated vhosts and least-privilege users. A vhost is a
logical grouping of exchanges, queues, and bindings with independent permissions.

```bash
# Create a vhost for the billing application
rabbitmqctl add_vhost billing --description "Billing service messages"

# Create a service user
rabbitmqctl add_user billing-svc 'B1ll!ngP@ss2026'

# Grant configure/write/read on all resources in the billing vhost
# Pattern format: "configure-regex" "write-regex" "read-regex"
rabbitmqctl set_permissions -p billing billing-svc ".*" ".*" ".*"

# Create a monitoring user with read-only access
rabbitmqctl add_user mon-user 'M0n!torP@ss'
rabbitmqctl set_user_tags mon-user monitoring
rabbitmqctl set_permissions -p billing mon-user "^$" "^$" ".*"

# Restrict a user to specific queue/exchange name prefixes
# Only allow configure/write/read on resources starting with "orders."
rabbitmqctl set_permissions -p billing orders-svc "^orders\." "^orders\." "^orders\."

# Set vhost limits (max queues and connections)
rabbitmqctl set_vhost_limits -p billing '{"max-queues": 100, "max-connections": 500}'

# List all permissions in a vhost
rabbitmqctl list_permissions -p billing

# List what a specific user can access across all vhosts
rabbitmqctl list_user_permissions billing-svc
```

User tags control management UI access levels:
- `management` -- basic UI access, own vhost only
- `monitoring` -- read-only across all vhosts
- `policymaker` -- management + create/delete policies
- `administrator` -- full control

---

## 2. Queue, Exchange, and Binding Declaration

Core AMQP concepts: producers publish to exchanges, exchanges route to queues via
bindings, consumers read from queues. RabbitMQ ships with a default direct exchange
(`""`) that routes by queue name.

Using `rabbitmqadmin` (download from `http://host:15672/cli/rabbitmqadmin`):

```bash
# Declare a durable direct exchange
rabbitmqadmin declare exchange name=orders.direct type=direct durable=true -V billing

# Declare a durable classic queue
rabbitmqadmin declare queue name=orders.new durable=true -V billing

# Bind the queue to the exchange with routing key "order.created"
rabbitmqadmin declare binding source=orders.direct destination=orders.new \
  routing_key=order.created -V billing

# Declare a fanout exchange (broadcasts to all bound queues)
rabbitmqadmin declare exchange name=events.fanout type=fanout durable=true -V billing

# Declare a topic exchange (wildcard routing: * matches one word, # matches zero or more)
rabbitmqadmin declare exchange name=logs.topic type=topic durable=true -V billing
rabbitmqadmin declare queue name=logs.errors durable=true -V billing
rabbitmqadmin declare binding source=logs.topic destination=logs.errors \
  routing_key="*.error.#" -V billing

# Publish a test message
rabbitmqadmin publish exchange=orders.direct routing_key=order.created \
  payload='{"order_id": 12345}' -V billing

# Consume (get) a message from a queue
rabbitmqadmin get queue=orders.new ackmode=ack_requeue_false -V billing

# List queues with message counts
rabbitmqctl list_queues -p billing name type messages consumers
```

Exchange types:
- **direct** -- routes to queues whose binding key exactly matches the routing key
- **fanout** -- broadcasts to every bound queue regardless of routing key
- **topic** -- pattern matching with `.`-delimited routing keys (`*` = one word, `#` = zero or more)
- **headers** -- routes based on message header attributes instead of routing key

---

## 3. Quorum Queue Setup

Quorum queues use Raft consensus for replication across cluster nodes. They replace
deprecated classic mirrored queues with better throughput and data safety.

```bash
# Declare a quorum queue (via policy -- applies to all queues matching the pattern)
rabbitmqctl set_policy -p billing quorum-all "^orders\." \
  '{"queue-type": "quorum"}' --apply-to queues

# Or declare with explicit initial member count (3 replicas)
rabbitmqadmin declare queue name=orders.priority durable=true \
  arguments='{"x-queue-type": "quorum", "x-quorum-initial-group-size": 3}' -V billing

# Set delivery limit for poison message handling (redelivery cap before dead-lettering)
rabbitmqctl set_policy -p billing dlx-orders "^orders\." \
  '{"queue-type": "quorum", "delivery-limit": 5, "dead-letter-exchange": "orders.dlx", "dead-letter-strategy": "at-least-once", "overflow": "reject-publish"}' \
  --apply-to queues

# Check quorum queue member status
rabbitmq-queues quorum_status orders.new -p billing

# Add a replica to a quorum queue (e.g., after adding a new cluster node)
rabbitmq-queues add_member orders.new rabbit@node3 -p billing

# Remove a replica (e.g., decommissioning a node)
rabbitmq-queues delete_member orders.new rabbit@node2 -p billing

# Rebalance leaders across the cluster (after node additions/removals)
rabbitmq-queues rebalance quorum
```

Key settings in `rabbitmq.conf` for quorum queue defaults:
```ini
# Default replication factor for quorum queues
quorum_queue.default_member_count = 3

# Raft WAL segment size (tune for disk throughput)
raft.wal_max_size_bytes = 536870912

# Soft limit on Raft commands (back-pressure threshold)
quorum_queue.commands_soft_limit = 32
```

---

## 4. Clustering

All cluster nodes share users, vhosts, exchanges, bindings, and runtime parameters.
Queues live on one node by default; use quorum queues or streams for replication.

### Form a Cluster (CLI Method)

```bash
# On node2 and node3: copy the erlang cookie from node1
sudo scp rabbitmq@node1:/var/lib/rabbitmq/.erlang.cookie /var/lib/rabbitmq/.erlang.cookie
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
sudo chmod 600 /var/lib/rabbitmq/.erlang.cookie
sudo systemctl restart rabbitmq-server

# On node2: join the cluster
rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@node1
rabbitmqctl start_app

# On node3: join the cluster
rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@node1
rabbitmqctl start_app

# Verify from any node
rabbitmqctl cluster_status
```

### Config-Based Discovery (rabbitmq.conf)

```ini
# Peer discovery via config (no manual join needed)
cluster_formation.peer_discovery_backend = classic_config
cluster_formation.classic_config.nodes.1 = rabbit@node1
cluster_formation.classic_config.nodes.2 = rabbit@node2
cluster_formation.classic_config.nodes.3 = rabbit@node3
```

### Remove a Node from Cluster

```bash
# From the node being removed:
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl start_app    # starts as standalone

# Or remotely (if node is permanently gone):
rabbitmqctl forget_cluster_node rabbit@dead-node
```

### Partition Handling (rabbitmq.conf)

```ini
# Recommended for multi-rack / multi-AZ clusters:
cluster_partition_handling = pause_minority

# Alternative: prioritize service continuity over consistency:
# cluster_partition_handling = autoheal

# Default (not recommended for production):
# cluster_partition_handling = ignore
```

---

## 5. Shovel (Cross-Cluster Message Transfer)

Shovel moves messages unidirectionally from a source queue/exchange to a destination.
Useful for cross-datacenter replication, migration, and bridging clusters.

```bash
# Enable shovel plugins
rabbitmq-plugins enable rabbitmq_shovel
rabbitmq-plugins enable rabbitmq_shovel_management

# Create a dynamic shovel (no restart required)
rabbitmqctl set_parameter shovel dc1-to-dc2 \
  '{"src-protocol": "amqp091", "src-uri": "amqp://user:pass@dc1-node:5672/billing", "src-queue": "orders.new", "dest-protocol": "amqp091", "dest-uri": "amqp://user:pass@dc2-node:5672/billing", "dest-queue": "orders.new", "ack-mode": "on-confirm", "reconnect-delay": 5}'

# Check shovel status
rabbitmqctl shovel_status

# Delete a dynamic shovel
rabbitmqctl clear_parameter shovel dc1-to-dc2
```

Shovel modes for `ack-mode`:
- `on-confirm` -- safest; acks source after destination confirms (at-least-once)
- `on-publish` -- acks after publishing to destination (may lose messages on dest failure)
- `no-ack` -- fastest; no source acks (fire-and-forget)

---

## 6. Federation (Loose Cluster Coupling)

Federation replicates messages between independent brokers/clusters. Unlike shovel,
federation is topology-aware: federated exchanges replay published messages; federated
queues balance consumers across sites.

```bash
# Enable federation plugins
rabbitmq-plugins enable rabbitmq_federation
rabbitmq-plugins enable rabbitmq_federation_management

# Define an upstream (the remote broker)
rabbitmqctl set_parameter federation-upstream dc2 \
  '{"uri": "amqp://fed-user:fed-pass@dc2-node:5672", "expires": 3600000}'

# Federate all exchanges matching "events.*" from the upstream
rabbitmqctl set_policy --apply-to exchanges federate-events "^events\." \
  '{"federation-upstream-set": "all"}'

# Federate specific queues from a named upstream
rabbitmqctl set_policy --apply-to queues federate-orders "^orders\." \
  '{"federation-upstream": "dc2"}'

# Check federation link status
rabbitmqctl federation_status

# Remove federation
rabbitmqctl clear_policy federate-events
rabbitmqctl clear_parameter federation-upstream dc2
```

Shovel vs. Federation:
- **Shovel**: simple point-to-point pump; good for migration and one-off transfers
- **Federation**: topology-aware replication; better for ongoing multi-site architectures

---

## 7. TLS Configuration

### AMQP Listener TLS (rabbitmq.conf)

```ini
# Disable plain AMQP, enable TLS-only
listeners.tcp = none
listeners.ssl.default = 5671

ssl_options.cacertfile = /etc/rabbitmq/tls/ca_certificate.pem
ssl_options.certfile   = /etc/rabbitmq/tls/server_certificate.pem
ssl_options.keyfile    = /etc/rabbitmq/tls/server_key.pem
ssl_options.verify     = verify_peer
ssl_options.fail_if_no_peer_cert = false
ssl_options.versions.1 = tlsv1.2
ssl_options.versions.2 = tlsv1.3
```

### Management UI TLS

```ini
management.ssl.port       = 15671
management.ssl.cacertfile = /etc/rabbitmq/tls/ca_certificate.pem
management.ssl.certfile   = /etc/rabbitmq/tls/server_certificate.pem
management.ssl.keyfile    = /etc/rabbitmq/tls/server_key.pem
```

### Test TLS Connection

```bash
# Verify TLS handshake
openssl s_client -connect localhost:5671 -tls1_2

# Check which listeners are active
rabbitmq-diagnostics listeners

# After rotating certificates on disk, clear the cache (no restart needed):
rabbitmqctl eval 'ssl:clear_pem_cache().'
```

### Inter-Node TLS (Cluster Encryption)

Requires additional Erlang distribution TLS config in `advanced.config`. See the
official inter-node TLS guide: https://www.rabbitmq.com/docs/clustering-ssl

---

## 8. Monitoring with Prometheus

```bash
# Enable the built-in Prometheus exporter
rabbitmq-plugins enable rabbitmq_prometheus

# Metrics endpoint (default port 15692)
curl -s http://localhost:15692/metrics | head -50

# Key metrics to alert on:
# rabbitmq_queue_messages_ready        -- messages waiting for consumers
# rabbitmq_queue_messages_unacked      -- delivered but not yet acknowledged
# rabbitmq_queue_consumers             -- consumer count per queue (0 = stuck)
# rabbitmq_process_open_fds            -- file descriptors in use
# rabbitmq_resident_memory_limit_bytes -- memory watermark
# rabbitmq_disk_space_available_bytes  -- free disk on data partition
# rabbitmq_connections_opened_total    -- connection churn rate
```

In `rabbitmq.conf`, tune the scrape endpoint:
```ini
# Expose per-object (queue, exchange) metrics (more detail, higher cardinality)
prometheus.return_per_object_metrics = true
```

### Quick Health Check Script

```bash
#!/usr/bin/env bash
# rabbitmq-health.sh -- exits non-zero on any failure
set -euo pipefail

rabbitmq-diagnostics check_running -q
rabbitmq-diagnostics check_local_alarms -q
rabbitmq-diagnostics check_port_connectivity -q
rabbitmq-diagnostics check_virtual_hosts -q

echo "RabbitMQ health: OK"
```

---

## 9. Definitions Export/Import

Definitions capture users, vhosts, permissions, exchanges, queues, bindings, and
policies in a portable JSON format. Useful for disaster recovery and environment cloning.

```bash
# Export all definitions to a file
rabbitmqctl export_definitions /tmp/rabbitmq-definitions.json

# Import definitions (merges with existing state; does not delete)
rabbitmqctl import_definitions /tmp/rabbitmq-definitions.json

# Export via HTTP API (requires management plugin)
curl -s -u admin:password http://localhost:15672/api/definitions > definitions.json

# Import via HTTP API
curl -s -u admin:password -X POST -H "Content-Type: application/json" \
  -d @definitions.json http://localhost:15672/api/definitions
```

---

## 10. Production Tuning Checklist

Essential `rabbitmq.conf` settings for production:

```ini
# Memory: trigger flow control at 60% of available RAM
vm_memory_high_watermark.relative = 0.6

# Disk: alarm when free space drops below 2 GB
disk_free_limit.absolute = 2GB

# Networking: raise default channel limit per connection
channel_max = 2047

# Heartbeat: detect dead connections (seconds; 0 disables)
heartbeat = 60

# Consumer timeout: auto-close consumers that don't ack within 30 minutes
consumer_timeout = 1800000

# Logging
log.file.level = info
log.console = true
log.console.level = warning
```

OS-level tuning:

```bash
# File descriptors -- set in /etc/systemd/system/rabbitmq-server.service.d/limits.conf
# [Service]
# LimitNOFILE=65536

# Or in /etc/security/limits.conf:
# rabbitmq  soft  nofile  65536
# rabbitmq  hard  nofile  65536

# Verify effective limit
rabbitmqctl status | grep -i "file descriptors"

# Network tuning for high-throughput
sudo sysctl -w net.core.somaxconn=4096
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=4096
```
