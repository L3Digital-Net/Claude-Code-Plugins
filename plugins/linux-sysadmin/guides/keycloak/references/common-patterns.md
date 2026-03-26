# Keycloak Common Patterns

Commands assume Keycloak is running and `kcadm.sh` has been authenticated. Replace
placeholder values with your own domains, credentials, and client IDs.

---

## 1. Production keycloak.conf

Minimal production configuration for a single-node deployment behind a reverse proxy
with PostgreSQL.

```properties
# conf/keycloak.conf

# --- Database (build-time: requires kc.sh build) ---
db=postgres
db-url-host=localhost
db-url-port=5432
db-url-database=keycloak
db-username=keycloak
db-password=<DB_PASSWORD>
db-schema=public
db-pool-max-size=100

# --- Hostname ---
hostname=https://auth.example.com
hostname-admin=https://auth.example.com
hostname-strict=true

# --- HTTP / HTTPS ---
# TLS terminated at reverse proxy; Keycloak listens on HTTP internally
http-enabled=true
http-port=8080
# Disable Keycloak's own HTTPS when the proxy handles TLS
https-port=8443

# If terminating TLS at Keycloak instead of the proxy:
# https-certificate-file=/etc/keycloak/tls/cert.pem
# https-certificate-key-file=/etc/keycloak/tls/key.pem

# --- Reverse Proxy ---
proxy-headers=xforwarded
proxy-trusted-addresses=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

# --- Health and Metrics (build-time) ---
health-enabled=true
metrics-enabled=true

# --- Logging ---
log=console,file
log-file=/var/log/keycloak/keycloak.log
log-level=info
# Per-category levels: log-level=info,org.keycloak.events:debug

# --- Cache (clustering) ---
# Single node:
cache=local
# Multi-node (default jdbc-ping discovery over the configured database):
# cache=ispn
# cache-stack=jdbc-ping
```

Build and start:

```bash
bin/kc.sh build
bin/kc.sh start --optimized
```

---

## 2. Docker Compose with PostgreSQL

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: <DB_PASSWORD>
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U keycloak"]
      interval: 10s
      timeout: 5s
      retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:26.5.5
    command: start --optimized
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: <ADMIN_PASSWORD>
      KC_DB: postgres
      KC_DB_URL_HOST: postgres
      KC_DB_URL_DATABASE: keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: <DB_PASSWORD>
      KC_HOSTNAME: https://auth.example.com
      KC_PROXY_HEADERS: xforwarded
      KC_HEALTH_ENABLED: "true"
      KC_METRICS_ENABLED: "true"
      KC_HTTP_ENABLED: "true"
    ports:
      - "127.0.0.1:8080:8080"
      - "127.0.0.1:9000:9000"
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  pgdata:
```

For an optimized image (pre-built config baked in), use a multi-stage Dockerfile:

```dockerfile
FROM quay.io/keycloak/keycloak:26.5.5 AS builder
ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.5.5
COPY --from=builder /opt/keycloak/ /opt/keycloak/
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
```

---

## 3. Reverse Proxy Configuration

### Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name auth.example.com;

    ssl_certificate     /etc/nginx/tls/auth.example.com.crt;
    ssl_certificate_key /etc/nginx/tls/auth.example.com.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host               $host;
        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
        proxy_set_header X-Forwarded-Host   $host;
        proxy_set_header X-Forwarded-Port   $server_port;

        proxy_buffer_size          128k;
        proxy_buffers              4 256k;
        proxy_busy_buffers_size    256k;
    }
}
```

Keycloak config to match:

```properties
proxy-headers=xforwarded
proxy-trusted-addresses=127.0.0.1
hostname=https://auth.example.com
http-enabled=true
```

### Caddy

```
auth.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

Caddy sets `X-Forwarded-*` headers automatically. Use the same `proxy-headers=xforwarded`
setting in keycloak.conf.

---

## 4. Realm, Client, and User Management via kcadm.sh

### Authenticate

```bash
# Authenticate to the master realm (stores session in ~/.keycloak/kcadm.config)
bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password <ADMIN_PASSWORD>
```

### Create a Realm

```bash
bin/kcadm.sh create realms \
  -s realm=mycompany \
  -s enabled=true \
  -s displayName="My Company" \
  -s loginWithEmailAllowed=true \
  -s registrationAllowed=false \
  -s resetPasswordAllowed=true
```

### Create Clients

```bash
# Confidential client (server-side app with a secret)
bin/kcadm.sh create clients -r mycompany \
  -s clientId=backend-api \
  -s secret="<CLIENT_SECRET>" \
  -s publicClient=false \
  -s directAccessGrantsEnabled=true \
  -s serviceAccountsEnabled=true \
  -s 'redirectUris=["https://api.example.com/*"]' \
  -s enabled=true

# Public client (SPA or mobile app, no secret)
bin/kcadm.sh create clients -r mycompany \
  -s clientId=frontend-app \
  -s publicClient=true \
  -s 'redirectUris=["https://app.example.com/*","http://localhost:3000/*"]' \
  -s 'webOrigins=["https://app.example.com","http://localhost:3000"]' \
  -s enabled=true
```

### Create Users and Set Passwords

```bash
# Create a user
bin/kcadm.sh create users -r mycompany \
  -s username=jdoe \
  -s email=jdoe@example.com \
  -s firstName=John \
  -s lastName=Doe \
  -s emailVerified=true \
  -s enabled=true

# Set password (--temporary forces change on next login)
bin/kcadm.sh set-password -r mycompany \
  --username jdoe \
  --new-password "<USER_PASSWORD>"

# Set temporary password
bin/kcadm.sh set-password -r mycompany \
  --username jdoe \
  --new-password "<TEMP_PASSWORD>" \
  --temporary
```

### Create Roles and Assign to Users

```bash
# Create realm roles
bin/kcadm.sh create roles -r mycompany -s name=admin
bin/kcadm.sh create roles -r mycompany -s name=user
bin/kcadm.sh create roles -r mycompany -s name=viewer

# Assign realm role to user
bin/kcadm.sh add-roles -r mycompany \
  --uusername jdoe \
  --rolename admin

# Create client-level role (get client UUID first)
CLIENT_UUID=$(bin/kcadm.sh get clients -r mycompany -q clientId=backend-api \
  --fields id --format csv --noquotes)
bin/kcadm.sh create clients/$CLIENT_UUID/roles -r mycompany \
  -s name=api-admin

# Assign client role to user
bin/kcadm.sh add-roles -r mycompany \
  --uusername jdoe \
  --cclientid backend-api \
  --rolename api-admin
```

### Create Groups

```bash
# Create a group
bin/kcadm.sh create groups -r mycompany -s name=engineering

# Add user to group (get group ID first)
GROUP_ID=$(bin/kcadm.sh get groups -r mycompany -q search=engineering \
  --fields id --format csv --noquotes)
USER_ID=$(bin/kcadm.sh get users -r mycompany -q username=jdoe \
  --fields id --format csv --noquotes)
bin/kcadm.sh update users/$USER_ID/groups/$GROUP_ID -r mycompany -s realm=mycompany -s userId=$USER_ID -s groupId=$GROUP_ID -n
```

---

## 5. Identity Provider Configuration

### OpenID Connect Provider

```bash
bin/kcadm.sh create identity-provider/instances -r mycompany \
  -s alias=corporate-sso \
  -s providerId=oidc \
  -s enabled=true \
  -s 'config.authorizationUrl=https://sso.corp.example.com/authorize' \
  -s 'config.tokenUrl=https://sso.corp.example.com/token' \
  -s 'config.userInfoUrl=https://sso.corp.example.com/userinfo' \
  -s 'config.clientId=<IDP_CLIENT_ID>' \
  -s 'config.clientSecret=<IDP_CLIENT_SECRET>' \
  -s 'config.defaultScope=openid email profile' \
  -s 'config.useJwksUrl=true' \
  -s 'config.jwksUrl=https://sso.corp.example.com/.well-known/jwks.json'
```

### SAML v2.0 Provider

```bash
# Import from IdP metadata URL
bin/kcadm.sh create identity-provider/instances -r mycompany \
  -s alias=saml-idp \
  -s providerId=saml \
  -s enabled=true \
  -s 'config.singleSignOnServiceUrl=https://idp.example.com/sso' \
  -s 'config.singleLogoutServiceUrl=https://idp.example.com/slo' \
  -s 'config.nameIDPolicyFormat=urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' \
  -s 'config.postBindingResponse=true' \
  -s 'config.postBindingAuthnRequest=true' \
  -s 'config.wantAssertionsSigned=true'
```

The SAML SP metadata for Keycloak is available at:
`https://auth.example.com/realms/mycompany/protocol/saml/descriptor`

### Social Login Providers

```bash
# GitHub
bin/kcadm.sh create identity-provider/instances -r mycompany \
  -s alias=github \
  -s providerId=github \
  -s enabled=true \
  -s 'config.clientId=<GITHUB_CLIENT_ID>' \
  -s 'config.clientSecret=<GITHUB_CLIENT_SECRET>'

# Google
bin/kcadm.sh create identity-provider/instances -r mycompany \
  -s alias=google \
  -s providerId=google \
  -s enabled=true \
  -s 'config.clientId=<GOOGLE_CLIENT_ID>' \
  -s 'config.clientSecret=<GOOGLE_CLIENT_SECRET>' \
  -s 'config.defaultScope=openid email profile'

# Microsoft / Azure AD
bin/kcadm.sh create identity-provider/instances -r mycompany \
  -s alias=microsoft \
  -s providerId=microsoft \
  -s enabled=true \
  -s 'config.clientId=<AZURE_CLIENT_ID>' \
  -s 'config.clientSecret=<AZURE_CLIENT_SECRET>'
```

Redirect URI to configure in each social provider's developer console:
`https://auth.example.com/realms/mycompany/broker/<alias>/endpoint`

---

## 6. Database Configuration Patterns

### PostgreSQL (recommended for production)

```properties
# keycloak.conf
db=postgres
db-url=jdbc:postgresql://db.internal:5432/keycloak?sslmode=require
db-username=keycloak
db-password=<DB_PASSWORD>
db-pool-initial-size=10
db-pool-min-size=10
db-pool-max-size=100
```

Or using component options instead of a full JDBC URL:

```properties
db=postgres
db-url-host=db.internal
db-url-port=5432
db-url-database=keycloak
db-url-properties=?sslmode=require
db-username=keycloak
db-password=<DB_PASSWORD>
```

### PostgreSQL setup commands

```bash
# Create the database and user
sudo -u postgres createuser keycloak
sudo -u postgres createdb -O keycloak keycloak
sudo -u postgres psql -c "ALTER USER keycloak WITH ENCRYPTED PASSWORD '<DB_PASSWORD>';"
```

### MariaDB / MySQL

```properties
db=mariadb
db-url=jdbc:mariadb://db.internal:3306/keycloak?characterEncoding=UTF-8
db-username=keycloak
db-password=<DB_PASSWORD>
```

---

## 7. TLS Configuration

### Keycloak-terminated TLS (no reverse proxy)

```properties
# keycloak.conf
https-certificate-file=/etc/keycloak/tls/fullchain.pem
https-certificate-key-file=/etc/keycloak/tls/privkey.pem
https-port=8443
http-enabled=false
hostname=https://auth.example.com
```

### Using a Java KeyStore

```properties
https-key-store-file=/etc/keycloak/tls/keystore.p12
https-key-store-password=<KEYSTORE_PASSWORD>
https-key-store-type=PKCS12
```

---

## 8. Theme Deployment

### Directory structure

```
themes/
└── my-company/
    ├── login/
    │   ├── theme.properties
    │   ├── resources/
    │   │   ├── css/
    │   │   │   └── custom.css
    │   │   └── img/
    │   │       └── logo.png
    │   └── messages/
    │       └── messages_en.properties
    └── email/
        ├── theme.properties
        └── messages/
            └── messages_en.properties
```

### theme.properties (login)

```properties
parent=keycloak
import=common/keycloak
styles=css/login.css css/custom.css
```

### Deploy

Copy the theme directory into Keycloak's `themes/` folder (or `/opt/keycloak/themes/`
in the container), then select it in the realm admin console under Realm Settings > Themes.

For Docker, mount or COPY:

```dockerfile
COPY my-company /opt/keycloak/themes/my-company
```

### Development (disable caching)

```bash
bin/kc.sh start-dev \
  --spi-theme-static-max-age=-1 \
  --spi-theme-cache-themes=false \
  --spi-theme-cache-templates=false
```

---

## 9. Systemd Unit for Bare-Metal

Keycloak does not ship a systemd unit. Create one for production bare-metal deployments.

```ini
# /etc/systemd/system/keycloak.service
[Unit]
Description=Keycloak Identity and Access Management
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=exec
User=keycloak
Group=keycloak
WorkingDirectory=/opt/keycloak
ExecStart=/opt/keycloak/bin/kc.sh start --optimized
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10

# JVM memory (adjust to your node)
Environment=JAVA_OPTS_APPEND=-Xms512m -Xmx2g

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/keycloak
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now keycloak
sudo journalctl -u keycloak -f
```

---

## 10. Realm Export and Import

### Export (for backup or migration)

```bash
# Via kcadm.sh (JSON to stdout)
bin/kcadm.sh get realms/mycompany > mycompany-realm.json

# Full export including users (via kc.sh, must be done at startup or while stopped)
bin/kc.sh export --dir=/tmp/keycloak-export --realm=mycompany
```

### Import

```bash
# Import a realm at startup
bin/kc.sh start-dev --import-realm

# Place the JSON file in data/import/ before starting
cp mycompany-realm.json /opt/keycloak/data/import/

# Via kcadm.sh (partial import into existing realm)
bin/kcadm.sh create partialImport -r mycompany -f realm-fragment.json \
  -s ifResourceExists=OVERWRITE
```
