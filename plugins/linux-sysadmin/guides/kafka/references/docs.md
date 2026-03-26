# Apache Kafka Documentation

## Getting Started

- Quickstart: https://kafka.apache.org/quickstart/
- Downloads: https://kafka.apache.org/community/downloads/
- Docker guide: https://kafka.apache.org/42/getting-started/docker/
- Upgrading: https://kafka.apache.org/42/getting-started/upgrade/

## Configuration

- Broker configuration reference: https://kafka.apache.org/42/configuration/broker-configs/
- Topic configuration reference: https://kafka.apache.org/42/configuration/topic-configs/
- Consumer configuration reference: https://kafka.apache.org/42/configuration/consumer-configs/
- Producer configuration reference: https://kafka.apache.org/42/configuration/producer-configs/
- Connect configuration reference: https://kafka.apache.org/42/configuration/connect-configs/

## Operations

- Operations overview: https://kafka.apache.org/42/operations/
- KRaft mode: https://kafka.apache.org/42/operations/kraft/
- Monitoring (JMX metrics): https://kafka.apache.org/42/operations/monitoring/
- Security overview: https://kafka.apache.org/42/security/
- Listener configuration: https://kafka.apache.org/42/security/listener-configuration/

## Design

- Kafka design (architecture): https://kafka.apache.org/42/design/
- Replication design: https://docs.confluent.io/kafka/design/replication.html
- Log compaction: https://kafka.apache.org/42/design/log-compaction/

## CLI Tools

- CLI tools reference (Confluent docs): https://docs.confluent.io/kafka/operations-tools/kafka-tools.html
- kafka-topics.sh: https://docs.confluent.io/kafka/operations-tools/kafka-tools.html#kafka-topics-sh
- kafka-consumer-groups.sh: https://docs.confluent.io/kafka/operations-tools/manage-consumer-groups.html

## KRaft and Migration

- KRaft overview (Confluent): https://developer.confluent.io/learn/kraft/
- KRaft configuration (Confluent): https://docs.confluent.io/platform/current/kafka-metadata/config-kraft.html
- ZooKeeper to KRaft migration: https://kafka.apache.org/42/operations/kraft/#kraft_zk_migration

## Docker Images

- Official JVM image (Docker Hub): https://hub.docker.com/r/apache/kafka
- GraalVM native image (Docker Hub, experimental): https://hub.docker.com/r/apache/kafka-native
- Bitnami image (Docker Hub): https://hub.docker.com/r/bitnami/kafka

## Kafka Improvement Proposals (KIPs)

- KIP-500: ZooKeeper removal (KRaft genesis): https://cwiki.apache.org/confluence/display/KAFKA/KIP-500%3A+Replace+ZooKeeper+with+a+Self-Managed+Metadata+Quorum
- KIP-848: New consumer group protocol: https://cwiki.apache.org/confluence/display/KAFKA/KIP-848%3A+The+Next+Generation+of+the+Consumer+Rebalance+Protocol
- KIP-853: Dynamic KRaft quorum: https://cwiki.apache.org/confluence/display/KAFKA/KIP-853%3A+KRaft+Controller+Membership+Changes
- KIP-932: Queues (share groups): https://cwiki.apache.org/confluence/display/KAFKA/KIP-932%3A+Queues+for+Kafka

## Source Code

- GitHub repository: https://github.com/apache/kafka
- Default server.properties: https://github.com/apache/kafka/blob/trunk/config/server.properties
- KRaft controller.properties: https://github.com/apache/kafka/blob/trunk/config/kraft/controller.properties
- KRaft broker.properties: https://github.com/apache/kafka/blob/trunk/config/kraft/broker.properties

## Ecosystem and Community

- Apache Kafka blog: https://kafka.apache.org/blog/
- Confluent developer portal: https://developer.confluent.io/
- Conduktor Kafkademy (tutorials): https://learn.conduktor.io/kafka/
- Kafka Summit recordings: https://www.confluent.io/resources/kafka-summit/
