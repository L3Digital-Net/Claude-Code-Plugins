# HashiCorp Consul Documentation

## Official -- HashiCorp Developer

- Main documentation: https://developer.hashicorp.com/consul/docs
- Install guide: https://developer.hashicorp.com/consul/install
- Getting started (VMs): https://developer.hashicorp.com/consul/tutorials/get-started-vms
- Agent configuration reference: https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file
- Architecture overview: https://developer.hashicorp.com/consul/docs/concepts/architecture
- Required ports: https://developer.hashicorp.com/consul/docs/reference/architecture/ports
- Release notes: https://developer.hashicorp.com/consul/docs/release-notes

## Service Discovery

- Service discovery overview: https://developer.hashicorp.com/consul/docs/concepts/service-discovery
- Service definition reference: https://developer.hashicorp.com/consul/docs/reference/service
- Health check reference: https://developer.hashicorp.com/consul/docs/reference/service/health-check
- DNS overview: https://developer.hashicorp.com/consul/docs/discover/dns
- Static DNS queries: https://developer.hashicorp.com/consul/docs/discover/service/static
- Dynamic DNS queries (prepared queries): https://developer.hashicorp.com/consul/docs/discover/service/dynamic
- Configure DNS behavior: https://developer.hashicorp.com/consul/docs/discover/dns/configure
- DNS forwarding: https://developer.hashicorp.com/consul/docs/discover/dns/forwarding

## Service Mesh (Connect)

- Service mesh overview: https://developer.hashicorp.com/consul/docs/concepts/service-mesh
- Connect workloads to mesh: https://developer.hashicorp.com/consul/docs/connect
- Sidecar proxy deployment: https://developer.hashicorp.com/consul/docs/connect/proxy/sidecar
- Proxy configuration reference: https://developer.hashicorp.com/consul/docs/reference/proxy/connect-proxy
- Service mesh tutorial (VMs): https://developer.hashicorp.com/consul/tutorials/get-started-vms/virtual-machine-gs-service-mesh
- Intentions (service-to-service auth): https://developer.hashicorp.com/consul/docs/connect/intentions

## KV Store

- KV store usage: https://developer.hashicorp.com/consul/docs/dynamic-app-config/kv
- KV CLI reference: https://developer.hashicorp.com/consul/commands/kv
- KV HTTP API: https://developer.hashicorp.com/consul/api-docs/kv

## ACLs

- ACL overview: https://developer.hashicorp.com/consul/docs/secure/acl
- Bootstrap ACL system: https://developer.hashicorp.com/consul/docs/secure/acl/bootstrap
- ACL tokens: https://developer.hashicorp.com/consul/docs/secure/acl/token
- ACL policies: https://developer.hashicorp.com/consul/docs/secure/acl/policy
- ACL roles: https://developer.hashicorp.com/consul/docs/secure/acl/role
- ACL best practices: https://developer.hashicorp.com/consul/docs/secure/acl/best-practice
- Reset ACL system: https://developer.hashicorp.com/consul/docs/secure/acl/reset
- ACL CLI reference: https://developer.hashicorp.com/consul/commands/acl

## Encryption

- Gossip encryption: https://developer.hashicorp.com/consul/docs/secure/encryption/gossip
- TLS encryption: https://developer.hashicorp.com/consul/docs/secure/encryption/tls
- TLS certificate creation: https://developer.hashicorp.com/consul/commands/tls

## Traffic Management & Failover

- Failover overview: https://developer.hashicorp.com/consul/docs/manage-traffic/failover
- Prepared queries (geo-failover): https://developer.hashicorp.com/consul/docs/manage-traffic/failover/prepared-query
- Prepared queries API: https://developer.hashicorp.com/consul/api-docs/query

## Operations

- Backup and restore: https://developer.hashicorp.com/consul/docs/manage/disaster-recovery/backup-restore
- Snapshot CLI: https://developer.hashicorp.com/consul/commands/snapshot
- Operator Raft: https://developer.hashicorp.com/consul/commands/operator/raft
- Automated backups (Enterprise): https://developer.hashicorp.com/consul/docs/enterprise/backups
- Telemetry reference: https://developer.hashicorp.com/consul/docs/reference/agent/telemetry
- Watches: https://developer.hashicorp.com/consul/docs/dynamic-app-config/watches

## Kubernetes

- Consul on Kubernetes: https://developer.hashicorp.com/consul/docs/connect/k8s
- Helm chart reference: https://developer.hashicorp.com/consul/docs/reference/k8s/helm

## HTTP API

- API overview: https://developer.hashicorp.com/consul/api-docs
- Agent API: https://developer.hashicorp.com/consul/api-docs/agent
- Catalog API: https://developer.hashicorp.com/consul/api-docs/catalog
- Health API: https://developer.hashicorp.com/consul/api-docs/health
- KV API: https://developer.hashicorp.com/consul/api-docs/kv
- ACL API: https://developer.hashicorp.com/consul/api-docs/acl
- Snapshot API: https://developer.hashicorp.com/consul/api-docs/snapshot

## CLI Reference

- CLI overview: https://developer.hashicorp.com/consul/commands
- agent: https://developer.hashicorp.com/consul/commands/agent
- members: https://developer.hashicorp.com/consul/commands/members
- join: https://developer.hashicorp.com/consul/commands/join
- leave: https://developer.hashicorp.com/consul/commands/leave
- kv: https://developer.hashicorp.com/consul/commands/kv
- acl: https://developer.hashicorp.com/consul/commands/acl
- connect: https://developer.hashicorp.com/consul/commands/connect
- intention: https://developer.hashicorp.com/consul/commands/intention
- snapshot: https://developer.hashicorp.com/consul/commands/snapshot
- operator: https://developer.hashicorp.com/consul/commands/operator
- watch: https://developer.hashicorp.com/consul/commands/watch
- services: https://developer.hashicorp.com/consul/commands/services
- catalog: https://developer.hashicorp.com/consul/commands/catalog
- tls: https://developer.hashicorp.com/consul/commands/tls
- monitor: https://developer.hashicorp.com/consul/commands/monitor
- debug: https://developer.hashicorp.com/consul/commands/debug

## GitHub

- Source repository: https://github.com/hashicorp/consul
- Releases: https://github.com/hashicorp/consul/releases
- Changelog: https://github.com/hashicorp/consul/blob/main/CHANGELOG.md

## License

- BSL 1.1 license text: https://www.hashicorp.com/en/bsl
- License FAQ: https://www.hashicorp.com/en/license-faq

## CLI Help

```bash
consul --help
consul agent --help
consul members --help
consul join --help
consul leave --help
consul kv --help
consul kv put --help
consul kv get --help
consul catalog --help
consul acl --help
consul acl bootstrap --help
consul acl token --help
consul acl policy --help
consul connect --help
consul connect envoy --help
consul intention --help
consul snapshot --help
consul snapshot save --help
consul operator --help
consul operator raft --help
consul watch --help
consul services --help
consul tls --help
consul monitor --help
consul info --help
consul reload --help
```
