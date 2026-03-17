# Apache Kafka Common Patterns

Each section is a complete, copy-paste-ready reference. All examples assume Kafka 4.x
in KRaft mode (ZooKeeper is not supported). Adjust hostnames, ports, and paths for
your environment.

---

## 1. KRaft Single-Node Setup (Dev/Test)

Minimal configuration for a combined broker+controller on one machine.

`/opt/kafka/config/server.properties`:

```properties
# KRaft combined mode: this node is both broker and controller
process.roles=broker,controller
node.id=1
controller.quorum.bootstrap.servers=localhost:9093

# Listeners
listeners=PLAINTEXT://:9092,CONTROLLER://:9093
advertised.listeners=PLAINTEXT://localhost:9092
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT

# Storage
log.dirs=/opt/kafka/data

# Topic defaults
num.partitions=1
default.replication.factor=1
min.insync.replicas=1

# Log retention
log.retention.hours=168
log.segment.bytes=1073741824
```

Initialize and start:

```bash
KAFKA_CLUSTER_ID="$(/opt/kafka/bin/kafka-storage.sh random-uuid)"
/opt/kafka/bin/kafka-storage.sh format --standalone \
  -t "$KAFKA_CLUSTER_ID" -c /opt/kafka/config/server.properties
/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
```

---

## 2. KRaft Multi-Node Production Cluster (3 Controllers + 3 Brokers)

Six nodes total: three dedicated controllers and three dedicated brokers. This
provides fault tolerance (lose one controller or one broker without impact) and
allows independent scaling of each role.

### Controller configuration (`controller.properties` on nodes 1, 2, 3):

```properties
process.roles=controller
node.id=1                   # 2 on second controller, 3 on third
controller.quorum.bootstrap.servers=ctrl1:9093,ctrl2:9093,ctrl3:9093
controller.listener.names=CONTROLLER
listeners=CONTROLLER://:9093
log.dirs=/var/kafka/controller-data
```

### Broker configuration (`broker.properties` on nodes 4, 5, 6):

```properties
process.roles=broker
node.id=4                   # 5 on second broker, 6 on third
controller.quorum.bootstrap.servers=ctrl1:9093,ctrl2:9093,ctrl3:9093
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://:9092
advertised.listeners=PLAINTEXT://broker1:9092
inter.broker.listener.name=PLAINTEXT
log.dirs=/var/kafka/broker-data

# Production defaults
num.partitions=3
default.replication.factor=3
min.insync.replicas=2
auto.create.topics.enable=false

# Retention
log.retention.hours=168
log.retention.bytes=-1
log.segment.bytes=1073741824
```

Initialize each node with the same cluster ID:

```bash
# Generate once, share across all nodes:
KAFKA_CLUSTER_ID="$(/opt/kafka/bin/kafka-storage.sh random-uuid)"

# On the first controller (bootstrap):
/opt/kafka/bin/kafka-storage.sh format --standalone \
  -t "$KAFKA_CLUSTER_ID" -c /opt/kafka/config/kraft/controller.properties

# On all other nodes (controllers and brokers):
/opt/kafka/bin/kafka-storage.sh format \
  -t "$KAFKA_CLUSTER_ID" -c /opt/kafka/config/kraft/<role>.properties
```

Start controllers first, then brokers.

---

## 3. Docker Compose Multi-Broker Cluster

Three-broker KRaft cluster for local development and integration testing.

`docker-compose.yml`:

```yaml
services:
  kafka-1:
    image: apache/kafka:4.2.0
    container_name: kafka-1
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-1:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS: kafka-1:9093,kafka-2:9093,kafka-3:9093
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_LOG_RETENTION_HOURS: 168
      CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qg"
    volumes:
      - kafka1-data:/var/lib/kafka/data

  kafka-2:
    image: apache/kafka:4.2.0
    container_name: kafka-2
    ports:
      - "9093:9092"
    environment:
      KAFKA_NODE_ID: 2
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-2:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS: kafka-1:9093,kafka-2:9093,kafka-3:9093
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_LOG_RETENTION_HOURS: 168
      CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qg"
    volumes:
      - kafka2-data:/var/lib/kafka/data

  kafka-3:
    image: apache/kafka:4.2.0
    container_name: kafka-3
    ports:
      - "9094:9092"
    environment:
      KAFKA_NODE_ID: 3
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-3:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS: kafka-1:9093,kafka-2:9093,kafka-3:9093
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_LOG_RETENTION_HOURS: 168
      CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qg"
    volumes:
      - kafka3-data:/var/lib/kafka/data

volumes:
  kafka1-data:
  kafka2-data:
  kafka3-data:
```

```bash
docker compose up -d

# Verify all brokers are up
docker exec kafka-1 /opt/kafka/bin/kafka-metadata.sh --snapshot \
  /var/lib/kafka/data/__cluster_metadata-0/00000000000000000000.log \
  --cluster-id MkU3OEVBNTcwNTJENDM2Qg

# Create a test topic
docker exec kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --create --topic test --partitions 3 --replication-factor 3 \
  --bootstrap-server kafka-1:9092
```

---

## 4. Topic Configuration and Management

### Create topics with specific settings

```bash
# High-throughput topic: many partitions, compressed, short retention
kafka-topics.sh --create --topic events.clicks \
  --partitions 12 --replication-factor 3 \
  --config retention.ms=86400000 \
  --config cleanup.policy=delete \
  --config compression.type=lz4 \
  --config min.insync.replicas=2 \
  --bootstrap-server localhost:9092

# Compacted topic: keeps latest value per key forever (changelog pattern)
kafka-topics.sh --create --topic state.users \
  --partitions 6 --replication-factor 3 \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.5 \
  --config delete.retention.ms=86400000 \
  --bootstrap-server localhost:9092

# Combined delete+compact: retain recent history, compact older segments
kafka-topics.sh --create --topic hybrid.example \
  --partitions 6 --replication-factor 3 \
  --config cleanup.policy=delete,compact \
  --config retention.ms=604800000 \
  --bootstrap-server localhost:9092
```

### Modify topic configuration at runtime

```bash
# Change retention to 3 days
kafka-configs.sh --alter --entity-type topics --entity-name events.clicks \
  --add-config retention.ms=259200000 \
  --bootstrap-server localhost:9092

# View current topic config overrides
kafka-configs.sh --describe --entity-type topics --entity-name events.clicks \
  --bootstrap-server localhost:9092

# Remove a config override (reverts to broker default)
kafka-configs.sh --alter --entity-type topics --entity-name events.clicks \
  --delete-config retention.ms \
  --bootstrap-server localhost:9092
```

---

## 5. Producer and Consumer Patterns

### Producer with keys (controls partition assignment)

```bash
# Produce key:value pairs (default partitioner hashes the key)
kafka-console-producer.sh --topic events.clicks \
  --property parse.key=true \
  --property key.separator=: \
  --bootstrap-server localhost:9092
# Then type lines like:   user123:{"event":"click","page":"/home"}

# Produce from a file
cat events.jsonl | kafka-console-producer.sh --topic events.clicks \
  --bootstrap-server localhost:9092
```

### Consumer with group and specific partition

```bash
# Consume as part of a consumer group (automatic partition assignment)
kafka-console-consumer.sh --topic events.clicks \
  --group click-processors \
  --bootstrap-server localhost:9092

# Consume from a specific partition and offset
kafka-console-consumer.sh --topic events.clicks \
  --partition 0 --offset 42 \
  --bootstrap-server localhost:9092

# Consume and print keys, timestamps, and headers
kafka-console-consumer.sh --topic events.clicks \
  --property print.key=true \
  --property print.timestamp=true \
  --property print.headers=true \
  --group debug-reader \
  --bootstrap-server localhost:9092

# Consume N messages then exit
kafka-console-consumer.sh --topic events.clicks \
  --from-beginning --max-messages 10 \
  --bootstrap-server localhost:9092
```

---

## 6. Consumer Group Management

```bash
# List all consumer groups
kafka-consumer-groups.sh --list --bootstrap-server localhost:9092

# Filter by protocol type (classic or consumer)
kafka-consumer-groups.sh --list --type consumer --bootstrap-server localhost:9092

# Describe a group (shows partition assignments, current offset, lag)
kafka-consumer-groups.sh --describe --group click-processors \
  --bootstrap-server localhost:9092
# Output columns: TOPIC, PARTITION, CURRENT-OFFSET, LOG-END-OFFSET, LAG,
#                 CONSUMER-ID, HOST, CLIENT-ID

# Describe group state (Stable, PreparingRebalance, Empty, Dead)
kafka-consumer-groups.sh --describe --group click-processors --state \
  --bootstrap-server localhost:9092

# Reset offsets to earliest (must stop consumers first)
kafka-consumer-groups.sh --group click-processors --topic events.clicks \
  --reset-offsets --to-earliest --dry-run \
  --bootstrap-server localhost:9092

# Execute the reset after verifying dry run output
kafka-consumer-groups.sh --group click-processors --topic events.clicks \
  --reset-offsets --to-earliest --execute \
  --bootstrap-server localhost:9092

# Reset to a specific timestamp
kafka-consumer-groups.sh --group click-processors --topic events.clicks \
  --reset-offsets --to-datetime 2026-03-14T00:00:00.000 --execute \
  --bootstrap-server localhost:9092

# Shift offsets by a delta (e.g., rewind 100 messages per partition)
kafka-consumer-groups.sh --group click-processors --topic events.clicks \
  --reset-offsets --shift-by -100 --execute \
  --bootstrap-server localhost:9092

# Delete an empty consumer group
kafka-consumer-groups.sh --delete --group old-group \
  --bootstrap-server localhost:9092
```

---

## 7. Partition Strategy

### Choosing partition count

```bash
# Rule of thumb: partitions >= max number of consumers in any single group
# at peak throughput. Each partition can only be consumed by one consumer
# per group at a time.
#
# For a topic consumed by a group of 10 workers: use at least 10 partitions.
# Over-partitioning (e.g., 100 partitions for 10 consumers) adds some
# overhead but gives room to scale consumers later without repartitioning.

kafka-topics.sh --create --topic orders \
  --partitions 12 --replication-factor 3 \
  --bootstrap-server localhost:9092
```

### Reassign partitions across brokers

```bash
# 1. Generate a reassignment plan
cat > /tmp/topics.json <<'EOF'
{"topics": [{"topic": "orders"}], "version": 1}
EOF

kafka-reassign-partitions.sh --generate \
  --topics-to-move-json-file /tmp/topics.json \
  --broker-list "4,5,6" \
  --bootstrap-server localhost:9092

# 2. Save the proposed plan to a file, review it, then execute
kafka-reassign-partitions.sh --execute \
  --reassignment-json-file /tmp/reassignment.json \
  --bootstrap-server localhost:9092

# 3. Verify progress
kafka-reassign-partitions.sh --verify \
  --reassignment-json-file /tmp/reassignment.json \
  --bootstrap-server localhost:9092
```

### Preferred leader election

```bash
# Trigger preferred leader election for all partitions
kafka-leader-election.sh --election-type preferred --all-topic-partitions \
  --bootstrap-server localhost:9092

# Trigger for a specific topic
kafka-leader-election.sh --election-type preferred \
  --topic orders --partition 0 \
  --bootstrap-server localhost:9092
```

---

## 8. Replication and Durability

### Producer acknowledgment levels

```
acks=0    Fire-and-forget. No broker acknowledgment. Fastest, least durable.
acks=1    Leader acknowledges write. Durable unless leader fails before replication.
acks=all  All in-sync replicas acknowledge. Strongest durability guarantee.
          Combine with min.insync.replicas=2 and replication.factor=3.
```

### Configure broker-level replication defaults

```bash
# Set defaults for new topics (broker config)
kafka-configs.sh --alter --entity-type brokers --entity-default \
  --add-config default.replication.factor=3,min.insync.replicas=2 \
  --bootstrap-server localhost:9092

# Per-topic override
kafka-configs.sh --alter --entity-type topics --entity-name critical-events \
  --add-config min.insync.replicas=2 \
  --bootstrap-server localhost:9092
```

### Monitor replication health

```bash
# List under-replicated partitions
kafka-topics.sh --describe --under-replicated-partitions \
  --bootstrap-server localhost:9092

# List unavailable partitions
kafka-topics.sh --describe --unavailable-partitions \
  --bootstrap-server localhost:9092
```

---

## 9. JMX Monitoring Setup

### Enable JMX on the broker

Add to the systemd unit file (or export before starting Kafka):

```bash
# In /etc/systemd/system/kafka.service, under [Service]:
Environment="JMX_PORT=9999"
Environment="KAFKA_JMX_OPTS=-Dcom.sun.management.jmxremote \
  -Dcom.sun.management.jmxremote.authenticate=true \
  -Dcom.sun.management.jmxremote.ssl=false \
  -Dcom.sun.management.jmxremote.password.file=/opt/kafka/config/jmx.password \
  -Dcom.sun.management.jmxremote.access.file=/opt/kafka/config/jmx.access"
```

For quick dev setup (no auth):

```bash
export JMX_PORT=9999
/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
```

### Key MBeans to monitor

| Metric | MBean | Alert threshold |
|--------|-------|-----------------|
| Under-replicated partitions | `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions` | > 0 |
| Offline partitions | `kafka.controller:type=KafkaController,name=OfflinePartitionsCount` | > 0 |
| Active controller count | `kafka.controller:type=KafkaController,name=ActiveControllerCount` | != 1 on exactly one broker |
| Messages in/sec | `kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec` | Baseline deviation |
| Bytes in/sec | `kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec` | Capacity planning |
| Bytes out/sec | `kafka.server:type=BrokerTopicMetrics,name=BytesOutPerSec` | Capacity planning |
| Request handler idle % | `kafka.server:type=KafkaRequestHandlerPool,name=RequestHandlerAvgIdlePercent` | < 0.3 |
| Network processor idle % | `kafka.network:type=SocketServer,name=NetworkProcessorAvgIdlePercent` | < 0.3 |
| ISR shrink rate | `kafka.server:type=ReplicaManager,name=IsrShrinksPerSec` | > 0 in steady state |
| Log flush latency | `kafka.log:type=LogFlushStats,name=LogFlushRateAndTimeMs` | p99 > 100ms |

### Prometheus JMX exporter

Use the [Prometheus JMX Exporter](https://github.com/prometheus/jmx_exporter) as a
Java agent to expose metrics as a `/metrics` endpoint:

```bash
# Download the JMX exporter agent JAR
wget https://repo.maven.apache.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/1.0.1/jmx_prometheus_javaagent-1.0.1.jar \
  -O /opt/kafka/libs/jmx_prometheus_javaagent.jar
```

Create `/opt/kafka/config/jmx-exporter.yml`:

```yaml
rules:
  - pattern: kafka.server<type=(.+), name=(.+), topic=(.+)><>(\w+)
    name: kafka_server_$1_$4
    labels:
      name: "$2"
      topic: "$3"
  - pattern: kafka.server<type=(.+), name=(.+)><>(\w+)
    name: kafka_server_$1_$3
    labels:
      name: "$2"
  - pattern: kafka.controller<type=(.+), name=(.+)><>(\w+)
    name: kafka_controller_$1_$3
    labels:
      name: "$2"
  - pattern: kafka.network<type=(.+), name=(.+)><>(\w+)
    name: kafka_network_$1_$3
    labels:
      name: "$2"
```

Add the agent to `KAFKA_OPTS` in the systemd unit or startup script:

```bash
export KAFKA_OPTS="-javaagent:/opt/kafka/libs/jmx_prometheus_javaagent.jar=7071:/opt/kafka/config/jmx-exporter.yml"
```

Metrics available at `http://broker-host:7071/metrics`.

---

## 10. Log Retention Tuning

### Broker-level defaults (server.properties)

```properties
# Time-based: delete segments older than 7 days (168 hours)
log.retention.hours=168
# log.retention.ms takes precedence over log.retention.hours if both are set

# Size-based: -1 means unlimited (only time-based applies)
log.retention.bytes=-1

# Segment size: roll a new segment at 1 GB
log.segment.bytes=1073741824

# Segment time: roll a new segment every 7 days even if under segment size
log.roll.hours=168

# Cleanup check interval: how often the log cleaner runs (default 5 min)
log.retention.check.interval.ms=300000
```

### Per-topic retention overrides

```bash
# Set 3-day retention on a high-volume topic
kafka-configs.sh --alter --entity-type topics --entity-name events.clicks \
  --add-config retention.ms=259200000 \
  --bootstrap-server localhost:9092

# Set 500 MB per-partition size limit
kafka-configs.sh --alter --entity-type topics --entity-name events.clicks \
  --add-config retention.bytes=524288000 \
  --bootstrap-server localhost:9092

# Enable log compaction for a changelog topic
kafka-configs.sh --alter --entity-type topics --entity-name state.users \
  --add-config cleanup.policy=compact \
  --bootstrap-server localhost:9092
```

### Cleanup policies explained

```
delete   — Default. Segments past retention time or size limit are deleted.
compact  — Keeps only the latest value per key. Old values are removed during
           background compaction. Keys with null values (tombstones) are removed
           after delete.retention.ms.
delete,compact — Both apply. Segments past retention limits are deleted; within
           retention, log compaction runs to deduplicate by key.
```

---

## 11. SASL/SSL Security Setup

### Generate TLS certificates

```bash
# Create a CA key and certificate
openssl req -new -x509 -keyout ca-key.pem -out ca-cert.pem -days 365 \
  -subj "/CN=Kafka-CA" -nodes

# Create a keystore for each broker
keytool -keystore kafka.broker1.keystore.jks -alias broker1 \
  -genkey -keyalg RSA -storepass changeit -keypass changeit \
  -dname "CN=broker1.example.com" -ext SAN=DNS:broker1.example.com

# Sign the broker certificate with the CA
keytool -keystore kafka.broker1.keystore.jks -alias broker1 \
  -certreq -file broker1.csr -storepass changeit
openssl x509 -req -CA ca-cert.pem -CAkey ca-key.pem -in broker1.csr \
  -out broker1-signed.pem -days 365 -CAcreateserial

# Import CA and signed cert into keystore
keytool -keystore kafka.broker1.keystore.jks -alias CARoot \
  -importcert -file ca-cert.pem -storepass changeit -noprompt
keytool -keystore kafka.broker1.keystore.jks -alias broker1 \
  -importcert -file broker1-signed.pem -storepass changeit

# Create a truststore with the CA cert (shared by all nodes and clients)
keytool -keystore kafka.truststore.jks -alias CARoot \
  -importcert -file ca-cert.pem -storepass changeit -noprompt
```

### Broker SSL configuration (server.properties)

```properties
listeners=SSL://:9092,CONTROLLER://:9093
advertised.listeners=SSL://broker1.example.com:9092
security.inter.broker.protocol=SSL

ssl.keystore.location=/opt/kafka/config/certs/kafka.broker1.keystore.jks
ssl.keystore.password=changeit
ssl.key.password=changeit
ssl.truststore.location=/opt/kafka/config/certs/kafka.truststore.jks
ssl.truststore.password=changeit
ssl.client.auth=required
```

### SASL/PLAIN authentication (server.properties)

```properties
listeners=SASL_SSL://:9092,CONTROLLER://:9093
advertised.listeners=SASL_SSL://broker1.example.com:9092
security.inter.broker.protocol=SASL_SSL
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN

# JAAS config inline
listener.name.sasl_ssl.plain.sasl.jaas.config=\
  org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="admin" \
  password="admin-secret" \
  user_admin="admin-secret" \
  user_producer="producer-secret" \
  user_consumer="consumer-secret";
```

### Client configuration (producer/consumer)

```properties
# client.properties
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="producer" \
  password="producer-secret";
ssl.truststore.location=/path/to/kafka.truststore.jks
ssl.truststore.password=changeit
```

```bash
# Produce with authentication
kafka-console-producer.sh --topic secure-topic \
  --producer.config /opt/kafka/config/client.properties \
  --bootstrap-server broker1.example.com:9092

# Consume with authentication
kafka-console-consumer.sh --topic secure-topic --from-beginning \
  --consumer.config /opt/kafka/config/client.properties \
  --bootstrap-server broker1.example.com:9092
```

---

## 12. Kafka Performance Testing

```bash
# Producer throughput test: 1 million messages, 1 KB each, 1 thread
kafka-producer-perf-test.sh --topic perf-test \
  --num-records 1000000 --record-size 1024 --throughput -1 \
  --producer-props bootstrap.servers=localhost:9092 acks=all \
  --print-metrics

# Consumer throughput test: consume 1 million messages
kafka-consumer-perf-test.sh --topic perf-test \
  --messages 1000000 --threads 1 \
  --bootstrap-server localhost:9092

# End-to-end latency test: measure produce-to-consume latency
kafka-e2e-latency.sh localhost:9092 latency-test 10000 all 1024
# Arguments: bootstrap-server, topic, num-messages, acks, message-size
```
