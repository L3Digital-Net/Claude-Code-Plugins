# Vault Common Patterns

Commands assume `VAULT_ADDR` and `VAULT_TOKEN` are set. Replace placeholder values
with your own paths, domains, and credentials.

---

## 1. KV v2 — Static Secrets CRUD

KV v2 is the default secrets engine in dev mode (`secret/`). In production, you may need
to enable it explicitly.

```bash
# Enable KV v2 at a custom path
vault secrets enable -version=2 -path=kv kv

# Write a secret (creates version 1)
vault kv put kv/myapp/config db_host="db.internal" db_port="5432" db_pass="<DB_PASSWORD>"

# Read the current version
vault kv get kv/myapp/config

# Read a specific version
vault kv get -version=1 kv/myapp/config

# Read as JSON (for scripting)
vault kv get -format=json kv/myapp/config | jq -r '.data.data.db_pass'

# Patch: update one field without replacing the entire secret
vault kv patch kv/myapp/config db_pass="<NEW_DB_PASSWORD>"

# Soft delete: marks the latest version as deleted (recoverable)
vault kv delete kv/myapp/config

# Undelete: restore a soft-deleted version
vault kv undelete -versions=2 kv/myapp/config

# Destroy: permanently remove specific version data (irrecoverable)
vault kv destroy -versions=1 kv/myapp/config

# View metadata (all versions, timestamps, custom metadata)
vault kv metadata get kv/myapp/config

# Set max versions retained (per-key)
vault kv metadata put -max-versions=10 kv/myapp/config

# Delete all versions and metadata
vault kv metadata delete kv/myapp/config

# List all keys at a path
vault kv list kv/myapp/
```

### KV v2 Policy Note

KV v2 prefixes the actual API paths. A policy for `kv/myapp/*` must reference the subpaths:

```hcl
# Read and write secret data
path "kv/data/myapp/*" {
  capabilities = ["create", "read", "update", "patch"]
}

# Delete and undelete
path "kv/delete/myapp/*" {
  capabilities = ["update"]
}
path "kv/undelete/myapp/*" {
  capabilities = ["update"]
}

# Destroy versions permanently
path "kv/destroy/myapp/*" {
  capabilities = ["update"]
}

# Read and manage metadata
path "kv/metadata/myapp/*" {
  capabilities = ["list", "read", "delete"]
}
```

---

## 2. Dynamic Database Credentials (PostgreSQL)

Vault generates short-lived database users on demand and revokes them when the lease expires.

```bash
# Enable the database secrets engine
vault secrets enable database

# Configure the PostgreSQL connection
# The {{username}} and {{password}} templates are required; Vault substitutes them
# with the root credentials for initial setup and rotation.
vault write database/config/mydb \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@db.internal:5432/mydb?sslmode=require" \
  allowed_roles="readonly,readwrite" \
  username="<VAULT_DB_ADMIN_USER>" \
  password="<VAULT_DB_ADMIN_PASS>"

# Rotate the root password so only Vault knows it
vault write -f database/rotate-root/mydb

# Create a readonly role
vault write database/roles/readonly \
  db_name=mydb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl=1h \
  max_ttl=24h

# Create a readwrite role
vault write database/roles/readwrite \
  db_name=mydb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl=1h \
  max_ttl=24h

# Request dynamic credentials
vault read database/creds/readonly
# Returns: username (v-token-readonly-xxxx), password, lease_id, lease_duration

# Renew a lease before it expires
vault lease renew database/creds/readonly/<lease-id>

# Revoke credentials immediately
vault lease revoke database/creds/readonly/<lease-id>

# Revoke ALL leases under a prefix
vault lease revoke -prefix database/creds/readonly
```

### MySQL/MariaDB variant

Same pattern, different plugin and SQL syntax:

```bash
vault write database/config/mysql \
  plugin_name=mysql-database-plugin \
  connection_url="{{username}}:{{password}}@tcp(db.internal:3306)/" \
  allowed_roles="app" \
  username="<VAULT_DB_ADMIN_USER>" \
  password="<VAULT_DB_ADMIN_PASS>"

vault write database/roles/app \
  db_name=mysql \
  creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; \
    GRANT SELECT, INSERT, UPDATE ON mydb.* TO '{{name}}'@'%';" \
  default_ttl=1h \
  max_ttl=24h
```

---

## 3. PKI — Internal Certificate Authority

Set up a two-tier PKI (root + intermediate) for issuing internal TLS certificates.

```bash
# ── Root CA ──

# Enable PKI at the pki path
vault secrets enable pki

# Set max TTL to 10 years
vault secrets tune -max-lease-ttl=87600h pki

# Generate the root CA (internal = key never leaves Vault)
vault write -field=certificate pki/root/generate/internal \
  common_name="My Org Root CA" \
  issuer_name="root-2024" \
  ttl=87600h > root_ca.crt

# Configure CA and CRL URLs
vault write pki/config/urls \
  issuing_certificates="${VAULT_ADDR}/v1/pki/ca" \
  crl_distribution_points="${VAULT_ADDR}/v1/pki/crl"

# ── Intermediate CA ──

# Enable a second PKI mount for the intermediate
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

# Generate intermediate CSR
vault write -format=json pki_int/intermediate/generate/internal \
  common_name="My Org Intermediate CA" \
  issuer_name="intermediate-2024" \
  | jq -r '.data.csr' > intermediate.csr

# Sign the intermediate with the root
vault write -format=json pki/root/sign-intermediate \
  issuer_ref="root-2024" \
  csr=@intermediate.csr \
  format=pem_bundle \
  ttl=43800h \
  | jq -r '.data.certificate' > intermediate.cert.pem

# Import the signed intermediate back
vault write pki_int/intermediate/set-signed \
  certificate=@intermediate.cert.pem

# ── Create a role for issuing leaf certs ──

vault write pki_int/roles/internal-tls \
  allowed_domains="internal.example.com" \
  allow_subdomains=true \
  allow_bare_domains=false \
  max_ttl=720h

# ── Issue a certificate ──

vault write pki_int/issue/internal-tls \
  common_name="myservice.internal.example.com" \
  ttl=24h
# Returns: certificate, private_key, ca_chain, serial_number

# ── Revoke a certificate ──

vault write pki/revoke serial_number="xx:xx:xx:..."

# ── Tidy expired certs from storage ──

vault write pki_int/tidy \
  tidy_cert_store=true \
  tidy_revoked_certs=true \
  safety_buffer=72h
```

---

## 4. Transit — Encryption as a Service

Vault encrypts/decrypts data without storing it. The application never holds the
encryption key.

```bash
# Enable the transit engine
vault secrets enable transit

# Create a named encryption key (AES-256-GCM by default)
vault write -f transit/keys/my-app-key

# Encrypt data (plaintext must be base64-encoded)
vault write transit/encrypt/my-app-key \
  plaintext=$(echo -n "sensitive data" | base64)
# Returns: ciphertext (vault:v1:xxxxx...)

# Decrypt data
vault write -field=plaintext transit/decrypt/my-app-key \
  ciphertext="vault:v1:xxxxx..." | base64 -d
# Returns: sensitive data

# Rotate the encryption key (new version; old ciphertexts still decryptable)
vault write -f transit/keys/my-app-key/rotate

# Rewrap existing ciphertext with the latest key version (no plaintext exposure)
vault write transit/rewrap/my-app-key \
  ciphertext="vault:v1:xxxxx..."
# Returns: vault:v2:yyyyy... (re-encrypted with new key version)

# Set minimum decryption version (disables decryption of older key versions)
vault write transit/keys/my-app-key/config \
  min_decryption_version=2

# Sign data with an asymmetric key (ed25519)
vault write -f transit/keys/signing-key type=ed25519
vault write transit/sign/signing-key \
  input=$(echo -n "data to sign" | base64)

# Verify signature
vault write transit/verify/signing-key \
  input=$(echo -n "data to sign" | base64) \
  signature="vault:v1:xxxxx..."

# Generate random bytes
vault write -field=random_bytes -format=json transit/random/32 format=base64
```

---

## 5. AppRole Authentication

Machine-to-machine auth for applications and CI/CD pipelines.

```bash
# Enable AppRole
vault auth enable approle

# Create a named role with policies and constraints
vault write auth/approle/role/my-app \
  token_policies="my-app-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=10m \
  secret_id_num_uses=1

# Read the role ID (static identifier, like a username)
vault read -field=role_id auth/approle/role/my-app/role-id

# Generate a secret ID (one-time credential, like a password)
vault write -f -field=secret_id auth/approle/role/my-app/secret-id

# Authenticate (returns a Vault token)
vault write auth/approle/login \
  role_id="<ROLE_ID>" \
  secret_id="<SECRET_ID>"
# Returns: client_token, token_accessor, token_policies, lease_duration

# Typical CI/CD pattern:
#   1. Operator stores role_id in the deployment config (not secret).
#   2. A trusted orchestrator (e.g., Terraform, Ansible) generates a wrapped
#      secret_id and delivers it to the application at deploy time.
#   3. The app uses both to authenticate and get a short-lived token.
```

---

## 6. Policy Examples

Policies are deny-by-default. Attach them to tokens via auth methods.

```hcl
# ── my-app-policy.hcl ──
# Application reads its own secrets and generates dynamic DB creds.

# KV v2 read access (note the data/ prefix)
path "kv/data/myapp/*" {
  capabilities = ["read"]
}
path "kv/metadata/myapp/*" {
  capabilities = ["list", "read"]
}

# Dynamic database credentials
path "database/creds/readonly" {
  capabilities = ["read"]
}

# Transit encrypt/decrypt with a specific key
path "transit/encrypt/my-app-key" {
  capabilities = ["update"]
}
path "transit/decrypt/my-app-key" {
  capabilities = ["update"]
}

# Deny access to everything else (implicit, but explicit deny overrides any grant)
path "sys/*" {
  capabilities = ["deny"]
}
```

```hcl
# ── admin-policy.hcl ──
# Cluster administrator with broad but non-root access.

path "sys/health" {
  capabilities = ["read", "sudo"]
}
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}
```

```bash
# Apply a policy
vault policy write my-app-policy my-app-policy.hcl

# Create a token with the policy attached
vault token create -policy=my-app-policy -ttl=8h

# Verify what a token can do (from the token's perspective)
vault token capabilities <token> kv/data/myapp/config
```

### Templated Policies

Policies can reference the authenticated identity for per-user/per-entity paths:

```hcl
# Each entity gets its own secret namespace
path "kv/data/users/{{identity.entity.id}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

---

## 7. Auto-Unseal with AWS KMS

Eliminates manual unseal key entry on restart. Vault uses the KMS key to encrypt/decrypt
its root key automatically.

```hcl
# In vault.hcl on every cluster node:
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/<KMS_KEY_UUID>"
  # Prefer IAM instance profile over hardcoded keys.
  # If you must use static keys, set via env vars:
  #   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
}
```

```bash
# Initialize with auto-unseal (generates recovery keys instead of unseal keys)
vault operator init -recovery-shares=5 -recovery-threshold=3

# On restart, Vault auto-unseals by contacting KMS. No manual intervention needed.
# If KMS is unreachable, Vault stays sealed until connectivity is restored.
```

IAM policy needed by the Vault instance:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:us-east-1:123456789012:key/<KMS_KEY_UUID>"
    }
  ]
}
```

---

## 8. Auto-Unseal with Transit (Vault Unsealing Vault)

A separate "unsealer" Vault cluster provides a transit key that the production cluster
uses to protect its root key. No cloud provider dependency.

```bash
# ── On the unsealer Vault ──

# Enable transit and create the unseal key
vault secrets enable transit
vault write -f transit/keys/vault-autounseal

# Create a policy for the production Vault's seal token
cat <<'POLICY' > autounseal-policy.hcl
path "transit/encrypt/vault-autounseal" {
  capabilities = ["update"]
}
path "transit/decrypt/vault-autounseal" {
  capabilities = ["update"]
}
POLICY
vault policy write autounseal autounseal-policy.hcl

# Create a periodic token (auto-renewing, no max TTL expiry)
vault token create -orphan -policy=autounseal -period=24h
# Save this token securely (e.g., in a credential manager).
```

```hcl
# ── On the production Vault (vault.hcl) ──
seal "transit" {
  address     = "https://unsealer-vault.example.com:8200"
  token       = "<UNSEALER_TOKEN>"   # or set VAULT_TRANSIT_SEAL_TOKEN env var
  key_name    = "vault-autounseal"
  mount_path  = "transit/"
  tls_ca_cert = "/etc/vault.d/tls/unsealer-ca.pem"
}
```

---

## 9. Vault Agent with Auto-Auth and Templating

Vault Agent runs as a sidecar or daemon, handles authentication, token renewal, and
renders secrets into files that applications read directly.

```hcl
# /etc/vault-agent.d/agent.hcl

vault {
  address = "https://vault.internal:8200"
  tls_skip_verify = false
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/etc/vault-agent.d/role-id"
      secret_id_file_path = "/etc/vault-agent.d/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/tmp/vault-token"
      mode = 0640
    }
  }
}

template {
  source      = "/etc/vault-agent.d/templates/db-config.ctmpl"
  destination = "/etc/myapp/db.env"
  perms       = 0640
  command     = "systemctl reload myapp"
}

template {
  source      = "/etc/vault-agent.d/templates/tls-cert.ctmpl"
  destination = "/etc/myapp/tls/cert.pem"
  perms       = 0644
}
```

Template file (`db-config.ctmpl`) using Consul Template syntax:

```
{{ with secret "database/creds/readonly" -}}
DB_USERNAME={{ .Data.username }}
DB_PASSWORD={{ .Data.password }}
{{- end }}
```

TLS cert template (`tls-cert.ctmpl`):

```
{{ with secret "pki_int/issue/internal-tls" "common_name=myservice.internal.example.com" "ttl=24h" -}}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}
{{- end }}
```

```bash
# Run the agent
vault agent -config=/etc/vault-agent.d/agent.hcl

# Or as a systemd service
sudo systemctl enable --now vault-agent
```

---

## 10. Audit Device Setup

Enable audit logging immediately after initializing a new cluster. Vault blocks all API
requests (except root token operations) if no audit device can log successfully and at
least one is enabled.

```bash
# File audit device (most common)
vault audit enable file file_path=/var/log/vault/audit.log

# Syslog audit device
vault audit enable syslog tag="vault" facility="AUTH"

# Socket audit device (send to log aggregator)
vault audit enable socket address="logserver.internal:9090" socket_type="tcp"

# List enabled audit devices
vault audit list -detailed

# Disable an audit device
vault audit disable file/

# Decode HMAC'd values in audit logs (for correlation)
vault write sys/audit-hash/file input="my-secret-value"
```

Best practices:
- Enable at least two audit devices for redundancy. If the sole audit device fails,
  Vault blocks all requests to prevent unaudited access.
- Audit logs contain HMAC-SHA256 hashes of sensitive string values by default. Use
  `sys/audit-hash` to compute hashes of known values for searching logs.
- Non-string values (booleans, integers) are logged in plaintext.
