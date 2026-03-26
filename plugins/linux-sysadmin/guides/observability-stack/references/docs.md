# Observability Stack Documentation

Per-component documentation links. For deep dives into any single component,
load the corresponding individual skill (prometheus, grafana, loki, node-exporter).

## Prometheus

- Getting started: https://prometheus.io/docs/prometheus/latest/getting_started/
- Configuration reference: https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- Alerting rules: https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/
- Recording rules: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/
- PromQL basics: https://prometheus.io/docs/prometheus/latest/querying/basics/
- PromQL functions: https://prometheus.io/docs/prometheus/latest/querying/functions/
- Storage and retention: https://prometheus.io/docs/prometheus/latest/storage/
- Docker deployment: https://prometheus.io/docs/introduction/install/#using-docker

## Alertmanager

- Configuration reference: https://prometheus.io/docs/alerting/latest/configuration/
- Notification templates: https://prometheus.io/docs/alerting/latest/notification_examples/
- Routing tree: https://prometheus.io/docs/alerting/latest/alertmanager/#grouping
- Silences and inhibitions: https://prometheus.io/docs/alerting/latest/alertmanager/#silences
- amtool CLI: https://github.com/prometheus/alertmanager#amtool
- High availability: https://prometheus.io/docs/alerting/latest/alertmanager/#high-availability

## Grafana

- Install (Debian/Ubuntu): https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/
- Install (Docker): https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/
- Configuration reference: https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/
- Provisioning datasources: https://grafana.com/docs/grafana/latest/administration/provisioning/#datasources
- Provisioning dashboards: https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards
- Prometheus datasource: https://grafana.com/docs/grafana/latest/datasources/prometheus/
- Loki datasource: https://grafana.com/docs/grafana/latest/datasources/loki/
- Grafana Alerting: https://grafana.com/docs/grafana/latest/alerting/
- Dashboard JSON model: https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/
- Community dashboards: https://grafana.com/grafana/dashboards/
- Node Exporter Full dashboard: https://grafana.com/grafana/dashboards/1860-node-exporter-full/

## Loki

- Getting started: https://grafana.com/docs/loki/latest/get-started/
- Install: https://grafana.com/docs/loki/latest/setup/install/
- Configuration reference: https://grafana.com/docs/loki/latest/configure/
- LogQL: https://grafana.com/docs/loki/latest/query/
- Storage backends: https://grafana.com/docs/loki/latest/storage/
- Retention and compaction: https://grafana.com/docs/loki/latest/operations/storage/retention/
- Docker deployment: https://grafana.com/docs/loki/latest/setup/install/docker/

## Promtail

- Configuration reference: https://grafana.com/docs/loki/latest/send-data/promtail/configuration/
- Pipeline stages: https://grafana.com/docs/loki/latest/send-data/promtail/stages/
- Scraping systemd journal: https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#journal
- Docker log discovery: https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#docker_sd_configs

## Node Exporter

- GitHub / README: https://github.com/prometheus/node_exporter
- Collector list: https://github.com/prometheus/node_exporter#enabled-by-default
- Textfile collector: https://github.com/prometheus/node_exporter#textfile-collector
- TLS and basic auth: https://github.com/prometheus/node_exporter#tls-and-basic-authentication

## Integration Guides

- Prometheus + Alertmanager setup: https://prometheus.io/docs/alerting/latest/overview/
- Grafana + Prometheus quickstart: https://grafana.com/docs/grafana/latest/getting-started/get-started-grafana-prometheus/
- Grafana + Loki quickstart: https://grafana.com/docs/loki/latest/visualize/grafana/
- Correlating metrics and logs: https://grafana.com/docs/grafana/latest/explore/correlations/

## Community Resources

- Prometheus community: https://prometheus.io/community/
- Grafana community forums: https://community.grafana.com/
- Awesome Prometheus alerts (curated rules): https://samber.github.io/awesome-prometheus-alerts/
- Grafana Play (live demo): https://play.grafana.org/
