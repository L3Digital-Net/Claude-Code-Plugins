# Elastic Stack (ELK) Documentation

## Elasticsearch

- Install (overview): https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html
- Install (Debian/APT): https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-with-debian-package
- Install (Docker): https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-basic
- Docker Compose multi-node: https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-compose
- Configuration reference (`elasticsearch.yml`): https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html
- Networking settings (ports, bind address): https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-network.html
- JVM settings (heap sizing): https://www.elastic.co/guide/en/elasticsearch/reference/current/advanced-configuration.html
- Important settings: https://www.elastic.co/docs/deploy-manage/deploy/self-managed/important-settings-configuration
- Discovery and cluster formation: https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery.html

## Elasticsearch Security

- Security overview: https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-cluster.html
- Minimal security setup: https://www.elastic.co/docs/deploy-manage/security/set-up-minimal-security
- TLS/SSL transport setup: https://www.elastic.co/guide/en/elasticsearch/reference/current/security-basic-setup.html
- Security settings reference: https://www.elastic.co/guide/en/elasticsearch/reference/current/security-settings.html
- Enrollment tokens: https://www.elastic.co/docs/reference/elasticsearch/command-line-tools/create-enrollment-token
- Authentication methods: https://www.elastic.co/guide/en/elasticsearch/reference/current/setting-up-authentication.html

## Elasticsearch APIs

- Cluster health: https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-cluster-health
- Cat APIs (`_cat/indices`, `_cat/shards`, etc.): https://www.elastic.co/guide/en/elasticsearch/reference/current/cat.html
- Index lifecycle management (ILM): https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html
- ILM policy creation: https://www.elastic.co/docs/manage-data/lifecycle/index-lifecycle-management/configure-lifecycle-policy
- ILM phases and actions: https://www.elastic.co/guide/en/elasticsearch/reference/current/ilm-index-lifecycle.html
- Index templates: https://www.elastic.co/guide/en/elasticsearch/reference/current/index-templates.html
- Data streams: https://www.elastic.co/guide/en/elasticsearch/reference/current/data-streams.html

## Elasticsearch Troubleshooting

- Red/yellow cluster status: https://www.elastic.co/docs/troubleshoot/elasticsearch/red-yellow-cluster-status
- Disk watermark errors: https://www.elastic.co/docs/troubleshoot/elasticsearch/fix-watermark-errors
- High JVM memory pressure: https://www.elastic.co/docs/troubleshoot/elasticsearch/high-jvm-memory-pressure
- Mapping explosion: https://www.elastic.co/docs/troubleshoot/elasticsearch/mapping-explosion
- Shard sizing guide: https://www.elastic.co/docs/deploy-manage/production-guidance/optimize-performance/size-shards

## Kibana

- Install overview: https://www.elastic.co/guide/en/kibana/current/install.html
- Install (Docker): https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-kibana-with-docker
- KQL (Kibana Query Language): https://www.elastic.co/docs/explore-analyze/query-filter/languages/kql
- ES|QL in Kibana: https://www.elastic.co/docs/explore-analyze/query-filter/languages/esql-kibana
- Kibana authentication: https://www.elastic.co/docs/deploy-manage/users-roles/cluster-or-deployment-auth/kibana-authentication

## Logstash

- Install overview: https://www.elastic.co/guide/en/logstash/current/installing-logstash.html
- Configuration files: https://www.elastic.co/guide/en/logstash/current/config-setting-files.html
- Pipeline structure: https://www.elastic.co/guide/en/logstash/current/configuration-file-structure.html
- Configuration examples: https://www.elastic.co/guide/en/logstash/current/config-examples.html
- Multiple pipelines: https://www.elastic.co/guide/en/logstash/current/multiple-pipelines.html
- Grok filter patterns: https://www.elastic.co/guide/en/logstash/current/plugins-filters-grok.html
- Performance tuning: https://www.elastic.co/guide/en/logstash/current/performance-tuning.html

## Beats (Filebeat, Metricbeat)

- Filebeat quick start: https://www.elastic.co/docs/reference/beats/filebeat/filebeat-installation-configuration
- Filebeat modules: https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules.html
- Filebeat Elasticsearch output: https://www.elastic.co/guide/en/beats/filebeat/current/elasticsearch-output.html
- Filebeat Logstash output: https://www.elastic.co/guide/en/beats/filebeat/current/logstash-output.html
- APT/YUM repository setup (Beats): https://www.elastic.co/docs/reference/beats/filebeat/setup-repositories
- Metricbeat quick start: https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-installation-configuration.html
- Metricbeat system module: https://www.elastic.co/docs/reference/beats/metricbeat/metricbeat-module-system
- Metricbeat Elasticsearch module: https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-module-elasticsearch.html

## Licensing

- License FAQ: https://www.elastic.co/pricing/faq/licensing
- AGPL announcement (2024): https://www.elastic.co/blog/elasticsearch-is-open-source-again
- Subscription tiers (Basic/Gold/Platinum/Enterprise): https://www.elastic.co/subscriptions

## Community Resources

- Elastic discuss forums: https://discuss.elastic.co/
- Elastic blog: https://www.elastic.co/blog
- Elasticsearch Labs: https://www.elastic.co/search-labs
- GitHub (Elasticsearch): https://github.com/elastic/elasticsearch
- GitHub (Kibana): https://github.com/elastic/kibana
- GitHub (Logstash): https://github.com/elastic/logstash
- GitHub (Beats): https://github.com/elastic/beats
