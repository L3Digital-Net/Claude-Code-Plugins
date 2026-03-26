# HashiCorp Vault Documentation

## Official -- HashiCorp Developer

- Main documentation: https://developer.hashicorp.com/vault/docs
- Install guide: https://developer.hashicorp.com/vault/install
- Getting started (dev server): https://developer.hashicorp.com/vault/tutorials/get-started/setup
- Server configuration reference: https://developer.hashicorp.com/vault/docs/configuration
- Server command: https://developer.hashicorp.com/vault/docs/commands/server
- Seal/Unseal concepts: https://developer.hashicorp.com/vault/docs/concepts/seal
- Policies: https://developer.hashicorp.com/vault/docs/concepts/policies
- Authentication overview: https://developer.hashicorp.com/vault/tutorials/auth-methods
- How Vault works: https://developer.hashicorp.com/vault/docs/about-vault/how-vault-works

## Secret Engines

- Secrets engines overview: https://developer.hashicorp.com/vault/docs/secrets
- KV v2 secrets engine: https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2
- KV v2 API: https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2
- Database secrets engine: https://developer.hashicorp.com/vault/docs/secrets/databases
- PostgreSQL database plugin: https://developer.hashicorp.com/vault/docs/secrets/databases/postgresql
- MySQL/MariaDB database plugin: https://developer.hashicorp.com/vault/docs/secrets/databases/mysql-maria
- Dynamic secrets tutorial: https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets
- PKI secrets engine: https://developer.hashicorp.com/vault/docs/secrets/pki
- PKI API: https://developer.hashicorp.com/vault/api-docs/secret/pki
- Transit secrets engine: https://developer.hashicorp.com/vault/docs/secrets/transit
- Static vs dynamic secrets: https://developer.hashicorp.com/vault/tutorials/get-started/understand-static-dynamic-secrets

## Authentication Methods

- AppRole: https://developer.hashicorp.com/vault/docs/auth/approle
- AppRole tutorial: https://developer.hashicorp.com/vault/tutorials/auth-methods/approle
- AppRole best practices: https://developer.hashicorp.com/vault/docs/auth/approle/approle-pattern
- Azure auth: https://developer.hashicorp.com/vault/docs/auth/azure
- Secure introduction patterns: https://developer.hashicorp.com/vault/tutorials/app-integration/secure-introduction

## Auto-Unseal

- Auto-unseal overview: https://developer.hashicorp.com/vault/tutorials/auto-unseal
- AWS KMS seal config: https://developer.hashicorp.com/vault/docs/configuration/seal/awskms
- AWS KMS tutorial: https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-aws-kms
- Transit seal config: https://developer.hashicorp.com/vault/docs/configuration/seal/transit
- Transit seal best practices: https://developer.hashicorp.com/vault/docs/configuration/seal/transit-best-practices
- Transit seal tutorial: https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-transit
- GCP Cloud KMS tutorial: https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-gcp-kms
- Azure Key Vault tutorial: https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-azure-keyvault
- Seal HA (multi-seal): https://developer.hashicorp.com/vault/docs/configuration/seal/seal-ha

## Integrated Storage (Raft)

- Raft configuration: https://developer.hashicorp.com/vault/docs/configuration/storage/raft
- Raft internals: https://developer.hashicorp.com/vault/docs/internals/integrated-storage
- Raft deployment guide: https://developer.hashicorp.com/vault/tutorials/day-one-raft/raft-deployment-guide
- Raft reference architecture: https://developer.hashicorp.com/vault/tutorials/day-one-raft/raft-reference-architecture
- Raft cluster tutorial: https://developer.hashicorp.com/vault/tutorials/raft/raft-storage

## Vault Agent and Proxy

- Vault Agent overview: https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent
- Agent quick start: https://developer.hashicorp.com/vault/tutorials/vault-agent/agent-quick-start
- Agent auto-auth: https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth
- Agent templates: https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/template
- Agent auto-auth with AppRole: https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/approle
- Agent config generator: https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent/generate-config

## Audit

- Audit devices: https://developer.hashicorp.com/vault/docs/audit
- Audit best practices: https://developer.hashicorp.com/vault/docs/audit/best-practices
- Audit enable command: https://developer.hashicorp.com/vault/docs/commands/audit/enable
- Policy from audit logs: https://developer.hashicorp.com/vault/tutorials/policies/write-a-policy-using-audit-logs
- Query audit logs: https://developer.hashicorp.com/vault/tutorials/monitoring/query-audit-device-logs

## Operations

- Troubleshooting: https://developer.hashicorp.com/vault/tutorials/monitoring/troubleshooting-vault
- Release notes: https://developer.hashicorp.com/vault/docs/updates/release-notes
- Deprecation notices: https://developer.hashicorp.com/vault/docs/updates/deprecation
- Kubernetes deployment: https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide
- Kubernetes HA with Raft: https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm/examples/ha-with-raft
- Vault Secrets Operator (K8s): https://developer.hashicorp.com/vault/tutorials/kubernetes/vault-secrets-operator
- Password policies: https://developer.hashicorp.com/vault/tutorials/db-credentials/password-policies

## GitHub

- Source repository: https://github.com/hashicorp/vault
- Releases: https://github.com/hashicorp/vault/releases
- Changelog: https://github.com/hashicorp/vault/blob/main/CHANGELOG.md

## License

- BSL 1.1 license text: https://www.hashicorp.com/en/bsl
- License FAQ: https://www.hashicorp.com/en/license-faq

## CLI Help

```bash
vault --help
vault server --help
vault operator init --help
vault operator unseal --help
vault operator seal --help
vault status --help
vault kv --help
vault secrets --help
vault auth --help
vault policy --help
vault audit --help
vault token --help
vault lease --help
vault operator raft --help
vault agent --help
```
