# Envoy Proxy Documentation

## Official Docs

- Envoy home: https://www.envoyproxy.io/
- Documentation index: https://www.envoyproxy.io/docs/envoy/latest/
- Architecture overview: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/arch_overview
- Terminology: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/intro/terminology
- Life of a request: https://www.envoyproxy.io/docs/envoy/latest/intro/life_of_a_request
- Quick start (static config): https://www.envoyproxy.io/docs/envoy/latest/start/quick-start/configuration-static
- Configuration examples: https://www.envoyproxy.io/docs/envoy/latest/configuration/overview/examples

## Configuration Reference

- Listeners: https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/listeners
- HTTP connection manager: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/http_conn_man
- Route configuration: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/route_matching
- Clusters: https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_manager
- Health checking: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/health_checking
- Circuit breaking: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/circuit_breaking
- Circuit breaker proto: https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/cluster/v3/circuit_breaker.proto
- Load balancing: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/load_balancing/overview
- Access logging: https://www.envoyproxy.io/docs/envoy/latest/configuration/observability/access_log/usage
- TLS/SSL: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/security/ssl

## xDS / Dynamic Configuration

- xDS overview: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/dynamic_configuration
- xDS protocol: https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol
- LDS (Listener Discovery): https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/lds
- RDS (Route Discovery): https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/rds
- CDS (Cluster Discovery): https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cds
- EDS (Endpoint Discovery): https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/service_discovery

## Operations

- Administration interface: https://www.envoyproxy.io/docs/envoy/latest/operations/admin
- Admin quick start: https://www.envoyproxy.io/docs/envoy/latest/start/quick-start/admin
- Statistics overview: https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats
- Command line options: https://www.envoyproxy.io/docs/envoy/latest/operations/cli
- Hot restart: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/hot_restart
- Draining: https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/operations/draining

## Filters

- Network filters: https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/network_filters/network_filters
- HTTP filters: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/http_filters
- Rate limit filter: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/rate_limit_filter
- Router filter: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/router_filter

## Service Mesh / Control Planes

- Istio (uses Envoy as data plane): https://istio.io/latest/docs/
- Envoy Gateway: https://gateway.envoyproxy.io/
- Gloo Edge: https://docs.solo.io/gloo-edge/latest/

## Community

- Envoy GitHub: https://github.com/envoyproxy/envoy
- Envoy releases: https://github.com/envoyproxy/envoy/releases
- Envoy Slack: https://envoyproxy.slack.com/
- CNCF Envoy: https://www.cncf.io/projects/envoy/
- Envoy blog: https://blog.envoyproxy.io/

## Man Pages

- `envoy --help` -- command line options
- `envoy --mode validate -c envoy.yaml` -- config validation
