# Envoy Proxy Common Patterns

Each section is a complete, copy-paste-ready reference. Validate all config changes with
`envoy --mode validate -c envoy.yaml` before deploying.

---

## 1. Basic HTTP Reverse Proxy

Forward traffic from port 10000 to a backend service on port 8080.

```yaml
static_resources:
  listeners:
    - name: http_listener
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 10000
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: backend
                      domains: ["*"]
                      routes:
                        - match:
                            prefix: "/"
                          route:
                            cluster: backend_service

  clusters:
    - name: backend_service
      connect_timeout: 5s
      type: STRICT_DNS
      lb_policy: ROUND_ROBIN
      load_assignment:
        cluster_name: backend_service
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: backend.local
                      port_value: 8080

admin:
  address:
    socket_address:
      address: 127.0.0.1
      port_value: 9901
```

---

## 2. Multiple Virtual Hosts (Domain-Based Routing)

Route traffic to different backends based on the Host header.

```yaml
route_config:
  name: local_route
  virtual_hosts:
    - name: api
      domains: ["api.example.com"]
      routes:
        - match:
            prefix: "/"
          route:
            cluster: api_backend

    - name: web
      domains: ["www.example.com", "example.com"]
      routes:
        - match:
            prefix: "/static/"
          route:
            cluster: static_backend
        - match:
            prefix: "/"
          route:
            cluster: web_backend

    - name: fallback
      domains: ["*"]
      routes:
        - match:
            prefix: "/"
          direct_response:
            status: 404
            body:
              inline_string: "Not Found"
```

---

## 3. Circuit Breaking

Protect upstream services from overload. These thresholds are per-cluster.

```yaml
clusters:
  - name: backend_service
    connect_timeout: 5s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    circuit_breakers:
      thresholds:
        - priority: DEFAULT
          max_connections: 512
          max_pending_requests: 256
          max_requests: 1024
          max_retries: 3
          retry_budget:
            budget_percent:
              value: 20.0
            min_retry_concurrency: 3
    load_assignment:
      cluster_name: backend_service
      endpoints:
        - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: backend.local
                    port_value: 8080
```

Monitor circuit breaker state via the admin interface:
```bash
# Check circuit breaker stats
curl -s http://localhost:9901/stats | grep circuit_breakers

# Key metrics:
# cluster.<name>.circuit_breakers.default.cx_open         — connections tripped
# cluster.<name>.circuit_breakers.default.rq_pending_open  — pending requests tripped
# cluster.<name>.circuit_breakers.default.rq_open          — requests tripped
```

---

## 4. Access Logging

Log all requests to stdout or a file.

```yaml
# Inside the http_connection_manager typed_config:
access_log:
  - name: envoy.access_loggers.stdout
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
      log_format:
        json_format:
          timestamp: "%START_TIME%"
          method: "%REQ(:METHOD)%"
          path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
          protocol: "%PROTOCOL%"
          response_code: "%RESPONSE_CODE%"
          response_flags: "%RESPONSE_FLAGS%"
          duration_ms: "%DURATION%"
          upstream_host: "%UPSTREAM_HOST%"
          upstream_cluster: "%UPSTREAM_CLUSTER%"
          bytes_received: "%BYTES_RECEIVED%"
          bytes_sent: "%BYTES_SENT%"

# File-based logging alternative:
# - name: envoy.access_loggers.file
#   typed_config:
#     "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
#     path: /var/log/envoy/access.log
```

---

## 5. TLS Termination

Terminate TLS at Envoy and proxy plaintext to the backend.

```yaml
listeners:
  - name: https_listener
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 443
    filter_chains:
      - transport_socket:
          name: envoy.transport_sockets.tls
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
            common_tls_context:
              tls_certificates:
                - certificate_chain:
                    filename: /etc/envoy/certs/fullchain.pem
                  private_key:
                    filename: /etc/envoy/certs/privkey.pem
              alpn_protocols:
                - h2
                - http/1.1
        filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: ingress_https
              http_filters:
                - name: envoy.filters.http.router
                  typed_config:
                    "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
              route_config:
                name: local_route
                virtual_hosts:
                  - name: backend
                    domains: ["*"]
                    routes:
                      - match:
                          prefix: "/"
                        route:
                          cluster: backend_service
```

---

## 6. Health Checks on Upstream Clusters

Configure active health checking to detect unhealthy backend instances.

```yaml
clusters:
  - name: backend_service
    connect_timeout: 5s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    health_checks:
      - timeout: 2s
        interval: 10s
        unhealthy_threshold: 3
        healthy_threshold: 2
        http_health_check:
          path: /healthz
          expected_statuses:
            - start: 200
              end: 200
    # Outlier detection (passive health checking)
    outlier_detection:
      consecutive_5xx: 5
      interval: 10s
      base_ejection_time: 30s
      max_ejection_percent: 50
    load_assignment:
      cluster_name: backend_service
      endpoints:
        - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: backend-1.local
                    port_value: 8080
            - endpoint:
                address:
                  socket_address:
                    address: backend-2.local
                    port_value: 8080
```

---

## 7. xDS Dynamic Configuration Bootstrap

Minimal bootstrap config that delegates all routing to a management server via xDS.
Only the management server cluster is static.

```yaml
# Bootstrap config — Envoy fetches listeners, routes, clusters, and endpoints
# from the xDS management server at runtime.
node:
  cluster: my-service
  id: envoy-node-1

dynamic_resources:
  lds_config:
    resource_api_version: V3
    api_config_source:
      api_type: GRPC
      transport_api_version: V3
      grpc_services:
        - envoy_grpc:
            cluster_name: xds_cluster
  cds_config:
    resource_api_version: V3
    api_config_source:
      api_type: GRPC
      transport_api_version: V3
      grpc_services:
        - envoy_grpc:
            cluster_name: xds_cluster

static_resources:
  clusters:
    - name: xds_cluster
      connect_timeout: 5s
      type: STRICT_DNS
      lb_policy: ROUND_ROBIN
      typed_extension_protocol_options:
        envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
          "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
          explicit_http_config:
            http2_protocol_options: {}
      load_assignment:
        cluster_name: xds_cluster
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: xds-server.local
                      port_value: 5678

admin:
  address:
    socket_address:
      address: 127.0.0.1
      port_value: 9901
```

---

## 8. Retries and Timeouts

Configure per-route retry policies and timeouts.

```yaml
# Inside virtual_hosts routes:
routes:
  - match:
      prefix: "/api/"
    route:
      cluster: api_backend
      timeout: 30s
      retry_policy:
        retry_on: "5xx,reset,connect-failure,retriable-4xx"
        num_retries: 3
        per_try_timeout: 10s
        retry_back_off:
          base_interval: 0.25s
          max_interval: 1s
        retriable_status_codes:
          - 503
          - 429
```

---

## 9. Rate Limiting (Local)

Apply local (non-distributed) rate limiting per connection.

```yaml
# Add to http_filters (before the router filter):
http_filters:
  - name: envoy.filters.http.local_ratelimit
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
      stat_prefix: http_local_rate_limiter
      token_bucket:
        max_tokens: 100
        tokens_per_fill: 100
        fill_interval: 60s
      filter_enabled:
        runtime_key: local_rate_limit_enabled
        default_value:
          numerator: 100
          denominator: HUNDRED
      filter_enforced:
        runtime_key: local_rate_limit_enforced
        default_value:
          numerator: 100
          denominator: HUNDRED
      response_headers_to_add:
        - append_action: OVERWRITE_IF_EXISTS_OR_ADD
          header:
            key: x-ratelimit-limit
            value: "100"
  - name: envoy.filters.http.router
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
```

---

## 10. Admin Interface Debugging Workflow

Step-by-step debugging via the admin interface.

```bash
# 1. Check Envoy is running and healthy
curl http://localhost:9901/ready
curl http://localhost:9901/server_info | jq '.state, .version'

# 2. List all listeners and their addresses
curl -s http://localhost:9901/listeners

# 3. Check cluster health (look for 'health_flags::healthy')
curl -s http://localhost:9901/clusters | grep -E 'health_flags|cx_active'

# 4. Dump the full running config
curl -s http://localhost:9901/config_dump | jq .

# 5. Filter config dump to just listeners
curl -s 'http://localhost:9901/config_dump?resource=dynamic_listeners' | jq .

# 6. Check specific stats
curl -s http://localhost:9901/stats | grep -E 'upstream_rq_|upstream_cx_'

# 7. Get Prometheus-format metrics
curl -s http://localhost:9901/stats/prometheus | head -50

# 8. Change log level temporarily
curl -X POST 'http://localhost:9901/logging?level=debug'
# ... reproduce the issue ...
curl -X POST 'http://localhost:9901/logging?level=info'

# 9. Graceful drain before shutdown
curl -X POST 'http://localhost:9901/drain_listeners?graceful'
```
