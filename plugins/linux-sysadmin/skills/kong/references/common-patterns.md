# Kong Gateway Common Patterns

Each block is copy-paste-ready. Kong 3.x with DB-less mode is assumed unless noted.
In DB-less mode, all configuration lives in `kong.yml`; the Admin API is read-only.

---

## 1. Docker Compose DB-less Setup

Minimal Kong setup with no database. Configuration is declarative via `kong.yml`.

```yaml
# docker-compose.yml
services:
  kong:
    image: kong:latest
    container_name: kong
    restart: unless-stopped
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/kong.yml
      KONG_PROXY_LISTEN: "0.0.0.0:8000, 0.0.0.0:8443 ssl"
      KONG_ADMIN_LISTEN: "127.0.0.1:8001"
      KONG_LOG_LEVEL: info
    ports:
      - "8000:8000"    # Proxy HTTP
      - "8443:8443"    # Proxy HTTPS
      - "127.0.0.1:8001:8001"  # Admin API (localhost only)
    volumes:
      - ./kong.yml:/kong/kong.yml:ro
```

Verify: `curl -s http://localhost:8001 | jq '.version'`

---

## 2. Basic Declarative Config (kong.yml)

Defines a service, route, and plugin. The `_format_version` must match Kong's major version.

```yaml
# kong.yml
_format_version: "3.0"

services:
  - name: httpbin-service
    url: http://httpbin.org
    routes:
      - name: httpbin-route
        paths:
          - /httpbin
        strip_path: true

  - name: backend-api
    url: http://backend:3000
    routes:
      - name: api-route
        paths:
          - /api
        strip_path: true
        # Only match specific methods
        methods:
          - GET
          - POST
```

Test: `curl http://localhost:8000/httpbin/get` should proxy to httpbin.org/get.

---

## 3. Authentication: API Key (key-auth)

Require an API key header or query parameter for a service.

```yaml
_format_version: "3.0"

services:
  - name: protected-api
    url: http://backend:3000
    routes:
      - name: protected-route
        paths:
          - /api
    plugins:
      - name: key-auth
        config:
          key_names:
            - apikey        # header or query param name
          hide_credentials: true  # strip the key before forwarding

consumers:
  - username: my-app
    keyauth_credentials:
      - key: my-secret-api-key-123
```

Test:
```bash
# Without key: 401 Unauthorized
curl -i http://localhost:8000/api

# With key: 200 OK
curl -i http://localhost:8000/api -H 'apikey: my-secret-api-key-123'
```

---

## 4. Authentication: JWT

Validate JWT tokens on incoming requests.

```yaml
_format_version: "3.0"

services:
  - name: jwt-api
    url: http://backend:3000
    routes:
      - name: jwt-route
        paths:
          - /api
    plugins:
      - name: jwt
        config:
          claims_to_verify:
            - exp   # verify token expiration

consumers:
  - username: jwt-user
    jwt_secrets:
      - key: my-iss           # maps to the "iss" claim in the JWT
        secret: my-jwt-secret  # shared secret for HS256
        algorithm: HS256
```

---

## 5. Rate Limiting

Limit requests per consumer, IP, or globally.

```yaml
_format_version: "3.0"

services:
  - name: rate-limited-api
    url: http://backend:3000
    routes:
      - name: rate-limited-route
        paths:
          - /api
    plugins:
      - name: rate-limiting
        config:
          minute: 60            # 60 requests per minute
          hour: 1000            # 1000 requests per hour
          policy: local         # local (in-memory), cluster (DB), or redis
          fault_tolerant: true  # continue proxying if rate-limit storage fails
          hide_client_headers: false  # include X-RateLimit-* headers in response
```

Rate limit headers returned to client:
- `X-RateLimit-Limit-Minute: 60`
- `X-RateLimit-Remaining-Minute: 59`

---

## 6. Multiple Plugins on a Service

Stack authentication + rate limiting + CORS on the same service.

```yaml
_format_version: "3.0"

services:
  - name: full-api
    url: http://backend:3000
    routes:
      - name: full-api-route
        paths:
          - /api
    plugins:
      - name: key-auth
        config:
          key_names: [apikey]
      - name: rate-limiting
        config:
          minute: 100
          policy: local
      - name: cors
        config:
          origins:
            - "https://myapp.example.com"
          methods:
            - GET
            - POST
            - PUT
            - DELETE
          headers:
            - Content-Type
            - apikey
          max_age: 3600
      - name: request-transformer
        config:
          add:
            headers:
              - "X-Forwarded-By:kong"

consumers:
  - username: frontend-app
    keyauth_credentials:
      - key: frontend-key-abc
```

---

## 7. Load Balancing with Upstreams

Distribute traffic across multiple backend instances.

```yaml
_format_version: "3.0"

upstreams:
  - name: backend-upstream
    algorithm: round-robin      # round-robin, consistent-hashing, least-connections, latency
    healthchecks:
      active:
        http_path: /health
        healthy:
          interval: 10
          successes: 3
        unhealthy:
          interval: 5
          http_failures: 3
    targets:
      - target: backend-1:3000
        weight: 100
      - target: backend-2:3000
        weight: 100
      - target: backend-3:3000
        weight: 50              # receives half the traffic of the others

services:
  - name: balanced-api
    host: backend-upstream       # points to the upstream name, not a real host
    port: 80
    routes:
      - name: balanced-route
        paths:
          - /api
```

---

## 8. IP Restriction

Allow or deny traffic based on source IP.

```yaml
_format_version: "3.0"

services:
  - name: internal-api
    url: http://backend:3000
    routes:
      - name: internal-route
        paths:
          - /internal
    plugins:
      - name: ip-restriction
        config:
          allow:
            - 10.0.0.0/8
            - 192.168.1.0/24
          # Or use deny to block specific IPs:
          # deny:
          #   - 1.2.3.4
```

---

## 9. Logging

Send request/response logs to a file or HTTP endpoint.

```yaml
_format_version: "3.0"

# Global plugin: applies to all services and routes
plugins:
  - name: file-log
    config:
      path: /tmp/kong-requests.log
      reopen: true

  # Or send to an HTTP endpoint (ELK, Loki, etc.)
  # - name: http-log
  #   config:
  #     http_endpoint: http://logstash:5044
  #     method: POST
  #     content_type: application/json
```

---

## 10. Reloading Config at Runtime (DB-less)

```bash
# Load a new config file without restarting
curl -s -X POST http://localhost:8001/config \
  -F 'config=@kong.yml'

# The response contains a JSON object with the parsed config hash.
# If validation fails, the old config remains active.

# Alternative: restart the container
docker restart kong
```
