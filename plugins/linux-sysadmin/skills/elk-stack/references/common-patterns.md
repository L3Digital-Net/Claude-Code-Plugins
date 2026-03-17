# Elastic Stack Common Patterns

Each section is a complete, copy-paste-ready reference. All examples assume Elasticsearch 8.x
with security enabled by default (HTTPS + authentication). Adjust hostnames, credentials,
and versions to match your environment.

---

## 1. Docker Compose Stack (ES + Kibana + Logstash)

Single-node development stack. For production multi-node clusters, see the official
Docker Compose guide at elastic.co.

Create a `.env` file alongside the compose file:

```bash
ELASTIC_PASSWORD=changeme
KIBANA_PASSWORD=changeme
STACK_VERSION=8.17.0
```

`docker-compose.yml`:

```yaml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
    container_name: es01
    environment:
      - discovery.type=single-node
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false   # Disable HTTPS for local dev simplicity
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    ports:
      - "9200:9200"
    volumes:
      - esdata:/usr/share/elasticsearch/data
    ulimits:
      memlock:
        soft: -1
        hard: -1
    mem_limit: 2g
    healthcheck:
      test: ["CMD-SHELL", "curl -sf -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 10

  kibana:
    image: docker.elastic.co/kibana/kibana:${STACK_VERSION}
    container_name: kib01
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=${KIBANA_PASSWORD}
    ports:
      - "5601:5601"
    depends_on:
      elasticsearch:
        condition: service_healthy

  logstash:
    image: docker.elastic.co/logstash/logstash:${STACK_VERSION}
    container_name: ls01
    environment:
      - "LS_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - ./logstash/pipeline/:/usr/share/logstash/pipeline/:ro
    ports:
      - "5044:5044"     # Beats input
      - "9600:9600"     # Monitoring API
    depends_on:
      elasticsearch:
        condition: service_healthy

volumes:
  esdata:
    driver: local
```

After starting, set the `kibana_system` password so Kibana can authenticate:

```bash
docker compose up -d

# Wait for ES to be healthy, then set the kibana_system password
curl -u elastic:changeme -X POST "http://localhost:9200/_security/user/kibana_system/_password" \
  -H 'Content-Type: application/json' \
  -d '{"password":"changeme"}'

# Access Kibana at http://localhost:5601 — log in as elastic/changeme
```

---

## 2. Filebeat Direct to Elasticsearch

Ship log files directly from a host to ES without Logstash in the middle. Simplest
architecture for small deployments.

```bash
# Install Filebeat (same APT repo as ES)
sudo apt-get install filebeat
```

`/etc/filebeat/filebeat.yml`:

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/syslog
      - /var/log/auth.log
    fields:
      source_host: "${HOSTNAME}"
    fields_under_root: true

  - type: log
    enabled: true
    paths:
      - /var/log/nginx/access.log
    fields:
      service: nginx
      log_type: access
    fields_under_root: true

# Ship directly to Elasticsearch
output.elasticsearch:
  hosts: ["https://es-host:9200"]
  username: "filebeat_writer"
  password: "changeme"
  ssl.certificate_authorities: ["/etc/filebeat/ca.crt"]
  # Index name pattern — uses date for easy ILM/rollover
  index: "filebeat-%{+yyyy.MM.dd}"

# Disable ILM if managing index patterns manually
setup.ilm.enabled: false
setup.template.name: "filebeat"
setup.template.pattern: "filebeat-*"

# Optional: set up Kibana dashboards
setup.kibana:
  host: "https://kibana-host:5601"
  username: "elastic"
  password: "changeme"
```

```bash
# Test config
sudo filebeat test config
sudo filebeat test output

# Enable and start
sudo systemctl enable --now filebeat

# Load built-in dashboards (one-time)
sudo filebeat setup --dashboards
```

---

## 3. Filebeat through Logstash to Elasticsearch

Use Logstash as a processing layer when you need grok parsing, enrichment, or routing.

### Filebeat config (`/etc/filebeat/filebeat.yml`):

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/nginx/access.log
    fields:
      service: nginx
    fields_under_root: true

  - type: log
    enabled: true
    paths:
      - /var/log/myapp/*.log
    fields:
      service: myapp
    fields_under_root: true
    # Multi-line for stack traces: join lines that don't start with a timestamp
    multiline.pattern: '^\d{4}-\d{2}-\d{2}'
    multiline.negate: true
    multiline.match: after

output.logstash:
  hosts: ["logstash-host:5044"]
  # Logstash Beats input does not use TLS by default; add ssl config if needed
```

### Logstash pipeline (`/etc/logstash/conf.d/beats-to-es.conf`):

```ruby
input {
  beats {
    port => 5044
  }
}

filter {
  # Route by the "service" field set in Filebeat
  if [service] == "nginx" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
    mutate {
      convert => { "response" => "integer" "bytes" => "integer" }
    }
  }

  if [service] == "myapp" {
    # Parse JSON-formatted application logs
    json {
      source => "message"
      target => "app"
    }
  }

  # Drop debug-level logs to reduce volume
  if [app][level] == "DEBUG" {
    drop {}
  }
}

output {
  elasticsearch {
    hosts => ["https://es-host:9200"]
    user => "logstash_writer"
    password => "changeme"
    ssl_certificate_authorities => ["/etc/logstash/ca.crt"]
    # Route to different indices by service
    index => "%{[service]}-%{+YYYY.MM.dd}"
  }
}
```

```bash
# Test the pipeline
sudo /usr/share/logstash/bin/logstash --config.test_and_exit -f /etc/logstash/conf.d/beats-to-es.conf

# Start Logstash
sudo systemctl enable --now logstash
```

---

## 4. Index Templates

Index templates apply settings and mappings to new indices matching a pattern. In ES 8.x,
composable index templates are the standard (legacy templates still work but are deprecated).

```bash
# Create a component template for common settings
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_component_template/logs-settings" \
  -H 'Content-Type: application/json' -d '
{
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 1,
      "index.lifecycle.name": "logs-policy",
      "index.lifecycle.rollover_alias": "logs"
    }
  }
}'

# Create a component template for common mappings
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_component_template/logs-mappings" \
  -H 'Content-Type: application/json' -d '
{
  "template": {
    "mappings": {
      "dynamic": "strict",
      "properties": {
        "@timestamp": { "type": "date" },
        "message":    { "type": "text" },
        "service":    { "type": "keyword" },
        "host":       { "type": "keyword" },
        "level":      { "type": "keyword" },
        "source_host": { "type": "keyword" }
      }
    }
  }
}'

# Create the composable index template referencing both components
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_index_template/logs-template" \
  -H 'Content-Type: application/json' -d '
{
  "index_patterns": ["logs-*"],
  "composed_of": ["logs-settings", "logs-mappings"],
  "priority": 200
}'

# Verify
curl -k -u elastic:$PASS "https://localhost:9200/_index_template/logs-template?pretty"
```

---

## 5. Index Lifecycle Management (ILM) Policies

ILM automates index rollover, tiering, and deletion. Phases: hot -> warm -> cold -> frozen -> delete.

```bash
# Create an ILM policy
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_ilm/policy/logs-policy" \
  -H 'Content-Type: application/json' -d '
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_primary_shard_size": "50gb",
            "max_age": "7d"
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          },
          "set_priority": {
            "priority": 50
          }
        }
      },
      "cold": {
        "min_age": "90d",
        "actions": {
          "set_priority": {
            "priority": 0
          }
        }
      },
      "delete": {
        "min_age": "365d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'

# Verify the policy
curl -k -u elastic:$PASS "https://localhost:9200/_ilm/policy/logs-policy?pretty"

# Check ILM status for an index
curl -k -u elastic:$PASS "https://localhost:9200/logs-2024.01.01/_ilm/explain?pretty"
```

To use with data streams (recommended for time-series/log data), the index template's
`index_patterns` should match the data stream name and include `"data_stream": {}`:

```bash
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_index_template/logs-ds-template" \
  -H 'Content-Type: application/json' -d '
{
  "index_patterns": ["logs-ds-*"],
  "data_stream": {},
  "composed_of": ["logs-settings", "logs-mappings"],
  "priority": 200
}'
```

---

## 6. Basic Security Setup

Elasticsearch 8.x auto-configures TLS and generates credentials on first start. These
steps cover post-install security tasks.

### Create dedicated service accounts (avoid using `elastic` superuser for applications)

```bash
# Create a role for Filebeat (write to filebeat-* indices)
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_security/role/filebeat_writer" \
  -H 'Content-Type: application/json' -d '
{
  "cluster": ["monitor", "manage_index_templates", "manage_ilm"],
  "indices": [
    {
      "names": ["filebeat-*"],
      "privileges": ["create_index", "create_doc", "manage"]
    }
  ]
}'

# Create a user for Filebeat
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_security/user/filebeat_writer" \
  -H 'Content-Type: application/json' -d '
{
  "password": "fb_secure_pass_here",
  "roles": ["filebeat_writer"],
  "full_name": "Filebeat Service Account"
}'

# Create a role for Logstash (write to multiple index patterns)
curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_security/role/logstash_writer" \
  -H 'Content-Type: application/json' -d '
{
  "cluster": ["monitor", "manage_index_templates", "manage_ilm"],
  "indices": [
    {
      "names": ["logstash-*", "nginx-*", "myapp-*"],
      "privileges": ["create_index", "create_doc", "manage"]
    }
  ]
}'

curl -k -u elastic:$PASS -X PUT "https://localhost:9200/_security/user/logstash_writer" \
  -H 'Content-Type: application/json' -d '
{
  "password": "ls_secure_pass_here",
  "roles": ["logstash_writer"],
  "full_name": "Logstash Service Account"
}'
```

### API key authentication (preferred over username/password for services)

```bash
# Create an API key for Filebeat
curl -k -u elastic:$PASS -X POST "https://localhost:9200/_security/api_key" \
  -H 'Content-Type: application/json' -d '
{
  "name": "filebeat-key",
  "role_descriptors": {
    "filebeat_writer": {
      "cluster": ["monitor"],
      "indices": [
        {
          "names": ["filebeat-*"],
          "privileges": ["create_index", "create_doc"]
        }
      ]
    }
  }
}'
# Response includes "encoded" field — use that in Filebeat config:
# output.elasticsearch:
#   api_key: "<encoded value>"
```

### Copy the CA certificate to Beats/Logstash hosts

```bash
# The auto-generated CA cert is at:
#   /etc/elasticsearch/certs/http_ca.crt
# Copy it to client machines:
scp /etc/elasticsearch/certs/http_ca.crt user@beat-host:/etc/filebeat/ca.crt
```

---

## 7. Metricbeat System Monitoring

Ship host metrics (CPU, memory, disk, network) to Elasticsearch.

```bash
sudo apt-get install metricbeat
```

`/etc/metricbeat/metricbeat.yml`:

```yaml
metricbeat.modules:
  - module: system
    metricsets:
      - cpu
      - load
      - memory
      - network
      - process
      - process_summary
      - filesystem
      - diskio
    period: 10s
    processes: ['.*']

  - module: system
    metricsets:
      - uptime
    period: 15m

output.elasticsearch:
  hosts: ["https://es-host:9200"]
  username: "metricbeat_writer"
  password: "changeme"
  ssl.certificate_authorities: ["/etc/metricbeat/ca.crt"]

setup.kibana:
  host: "https://kibana-host:5601"
```

```bash
# Enable the system module (enabled by default)
sudo metricbeat modules enable system

# Test and start
sudo metricbeat test config
sudo metricbeat test output
sudo systemctl enable --now metricbeat

# Load dashboards (one-time)
sudo metricbeat setup --dashboards
```

---

## 8. Common KQL Queries (Kibana Query Language)

Use these in Kibana's Discover, Dashboard, or Lens search bars. KQL filters data only;
it does not aggregate or transform.

```
# Exact field match
service: "nginx"

# Wildcard match — status codes starting with 5
http.response.status_code: 5*

# Boolean AND
service: "nginx" AND http.response.status_code: 500

# Boolean OR
http.response.status_code: 500 OR http.response.status_code: 503

# NOT
NOT service: "healthcheck"

# Range query
http.response.bytes > 10000

# Combined range
http.response.bytes > 10000 AND http.response.bytes <= 50000

# Field exists (has any value)
error.message: *

# Nested field query (for nested object types)
user:{ first: "Alice" AND last: "White" }

# Free text search across all fields
"connection refused"

# Combine conditions
service: "myapp" AND level: "error" AND NOT message: "expected"
```

KQL is case-insensitive for field values by default. For Lucene-style queries (regex support,
proximity search), switch the query language toggle in Kibana's search bar from KQL to Lucene.

---

## 9. Useful Elasticsearch Queries via API

```bash
PASS="your_elastic_password"
ES="https://localhost:9200"

# Cluster health with shard-level detail
curl -k -u elastic:$PASS "$ES/_cluster/health?level=shards&pretty"

# Disk usage per node
curl -k -u elastic:$PASS "$ES/_cat/allocation?v"

# Largest indices by size
curl -k -u elastic:$PASS "$ES/_cat/indices?v&s=store.size:desc&h=index,docs.count,store.size"

# Unassigned shards with reasons
curl -k -u elastic:$PASS "$ES/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason&s=state"

# Mapping for an index (shows all fields and their types)
curl -k -u elastic:$PASS "$ES/my-index/_mapping?pretty"

# Field count per index (to detect mapping explosion)
curl -k -u elastic:$PASS "$ES/my-index/_mapping?pretty" | python3 -c "
import json,sys
m=json.load(sys.stdin)
for idx,v in m.items():
    props=v.get('mappings',{}).get('properties',{})
    print(f'{idx}: {len(props)} top-level fields')
"

# Pending tasks (cluster queue)
curl -k -u elastic:$PASS "$ES/_cluster/pending_tasks?pretty"

# Hot threads (debug slow nodes)
curl -k -u elastic:$PASS "$ES/_nodes/hot_threads"

# Force refresh an index (make recent docs searchable immediately)
curl -k -u elastic:$PASS -X POST "$ES/my-index/_refresh"

# Reindex from one index to another
curl -k -u elastic:$PASS -X POST "$ES/_reindex" -H 'Content-Type: application/json' -d '
{
  "source": { "index": "old-index" },
  "dest":   { "index": "new-index" }
}'
```

---

## 10. Snapshot and Restore

Back up indices to a shared filesystem or S3-compatible object store.

```bash
# 1. Register a filesystem snapshot repository
#    Requires path.repo set in elasticsearch.yml: path.repo: ["/mnt/es-backups"]
curl -k -u elastic:$PASS -X PUT "$ES/_snapshot/my_backup" \
  -H 'Content-Type: application/json' -d '
{
  "type": "fs",
  "settings": {
    "location": "/mnt/es-backups/snapshots"
  }
}'

# 2. Take a snapshot of specific indices
curl -k -u elastic:$PASS -X PUT "$ES/_snapshot/my_backup/snapshot_$(date +%Y%m%d)?wait_for_completion=true" \
  -H 'Content-Type: application/json' -d '
{
  "indices": "logs-*,filebeat-*",
  "ignore_unavailable": true,
  "include_global_state": false
}'

# 3. List snapshots
curl -k -u elastic:$PASS "$ES/_snapshot/my_backup/_all?pretty"

# 4. Restore a snapshot
curl -k -u elastic:$PASS -X POST "$ES/_snapshot/my_backup/snapshot_20240115/_restore" \
  -H 'Content-Type: application/json' -d '
{
  "indices": "logs-2024.01.*",
  "ignore_unavailable": true,
  "rename_pattern": "(.+)",
  "rename_replacement": "restored_$1"
}'
```

For S3-compatible storage, install the `repository-s3` plugin and use `"type": "s3"` with
bucket, region, and credentials in the repository settings.
