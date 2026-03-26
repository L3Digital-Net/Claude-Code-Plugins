# osquery Common Patterns

Each block is copy-paste-ready. osquery configuration is JSON (no comments allowed
in the actual config file; comments here are for explanation only).

---

## 1. Basic Configuration

Minimal config with a few scheduled queries.

```json
{
  "options": {
    "config_plugin": "filesystem",
    "logger_plugin": "filesystem",
    "logger_path": "/var/log/osquery",
    "disable_logging": "false",
    "schedule_splay_percent": "10",
    "host_identifier": "hostname",
    "enable_monitor": "true",
    "database_path": "/var/osquery/osquery.db"
  },

  "schedule": {
    "system_info": {
      "query": "SELECT hostname, cpu_brand, physical_memory FROM system_info;",
      "interval": 3600
    },
    "listening_ports": {
      "query": "SELECT l.port, l.protocol, l.address, p.name, p.pid FROM listening_ports l JOIN processes p ON l.pid = p.pid WHERE l.port != 0;",
      "interval": 300
    },
    "logged_in_users": {
      "query": "SELECT user, host, time, tty FROM logged_in_users;",
      "interval": 600
    }
  }
}
```

Save as `/etc/osquery/osquery.conf`, then: `sudo systemctl restart osqueryd`

---

## 2. File Integrity Monitoring (FIM)

Monitor critical system files and directories for changes.

```json
{
  "options": {
    "config_plugin": "filesystem",
    "logger_plugin": "filesystem",
    "logger_path": "/var/log/osquery",
    "disable_events": "false",
    "enable_file_events": "true"
  },

  "file_paths": {
    "etc": [
      "/etc/%%"
    ],
    "ssh_keys": [
      "/root/.ssh/%%",
      "/home/%/.ssh/%%"
    ],
    "binaries": [
      "/usr/bin/%%",
      "/usr/sbin/%%",
      "/usr/local/bin/%%"
    ],
    "crontabs": [
      "/var/spool/cron/%%",
      "/etc/cron.d/%%"
    ]
  },

  "file_accesses": ["etc", "ssh_keys"],

  "schedule": {
    "file_events": {
      "query": "SELECT target_path, action, md5, sha256, time FROM file_events;",
      "interval": 300,
      "removed": false
    }
  }
}
```

The `%%` wildcard is osquery's recursive glob (like `**` in bash). Single `%` matches
one directory level. `file_accesses` additionally logs read access for the named categories.

---

## 3. Query Packs

Organize related queries into packs. Packs can be inline or loaded from separate files.

```json
{
  "options": {
    "config_plugin": "filesystem",
    "logger_plugin": "filesystem"
  },

  "packs": {
    "security": "/etc/osquery/packs/security.conf",
    "compliance": "/etc/osquery/packs/compliance.conf",
    "incident_response": {
      "discovery": [
        "SELECT 1 FROM osquery_info WHERE version >= '5.0.0';"
      ],
      "queries": {
        "open_sockets": {
          "query": "SELECT pid, remote_address, remote_port, local_port FROM process_open_sockets WHERE remote_port != 0;",
          "interval": 300,
          "description": "All outbound network connections"
        },
        "shell_history": {
          "query": "SELECT uid, command, history_file FROM shell_history;",
          "interval": 3600,
          "description": "Shell command history for all users"
        }
      }
    }
  }
}
```

Pack file format (`/etc/osquery/packs/security.conf`):

```json
{
  "queries": {
    "authorized_keys": {
      "query": "SELECT * FROM authorized_keys;",
      "interval": 3600,
      "description": "SSH authorized keys for all users"
    },
    "sudoers": {
      "query": "SELECT * FROM sudoers WHERE header NOT IN ('Defaults', 'Cmnd_Alias');",
      "interval": 3600,
      "description": "Sudoers entries"
    },
    "kernel_modules": {
      "query": "SELECT name, status, size FROM kernel_modules;",
      "interval": 1800,
      "description": "Loaded kernel modules"
    }
  }
}
```

---

## 4. Useful Ad-Hoc Queries

Run these in `osqueryi` for interactive investigation.

```sql
-- System overview
SELECT hostname, cpu_brand, cpu_physical_cores, physical_memory / (1024*1024*1024) AS ram_gb FROM system_info;

-- OS version
SELECT name, version, codename, platform FROM os_version;

-- Running processes sorted by memory
SELECT pid, name, uid, resident_size / (1024*1024) AS mem_mb, cmdline
FROM processes ORDER BY resident_size DESC LIMIT 20;

-- Listening ports with process names
SELECT l.port, l.protocol, l.address, p.name, p.pid
FROM listening_ports l JOIN processes p ON l.pid = p.pid
WHERE l.port != 0 ORDER BY l.port;

-- Established network connections
SELECT p.name, p.pid, s.remote_address, s.remote_port, s.local_port
FROM process_open_sockets s JOIN processes p ON s.pid = p.pid
WHERE s.remote_port != 0 AND s.state = 'ESTABLISHED';

-- Users and their groups
SELECT u.username, u.uid, u.gid, u.directory, u.shell
FROM users u WHERE u.shell NOT IN ('/usr/sbin/nologin', '/bin/false');

-- Installed packages (Debian/Ubuntu)
SELECT name, version, source FROM deb_packages ORDER BY name;

-- Installed packages (RHEL/Fedora)
SELECT name, version, release, arch FROM rpm_packages ORDER BY name;

-- Crontab entries
SELECT command, path, minute, hour, day_of_month FROM crontab;

-- Docker containers
SELECT id, name, image, status, state FROM docker_containers;

-- Mounted filesystems
SELECT device, path, type, blocks_size * blocks_available / (1024*1024*1024) AS free_gb
FROM mounts WHERE type NOT IN ('proc', 'sysfs', 'devtmpfs', 'tmpfs');

-- SSH authorized keys
SELECT uid, algorithm, key, key_file FROM authorized_keys;

-- Failed login attempts (auth log parsing)
SELECT time, message FROM syslog WHERE facility = 'auth' AND message LIKE '%Failed%' ORDER BY time DESC LIMIT 20;

-- Find SUID binaries
SELECT path, mode, uid FROM suid_bin;

-- Check for unsigned or modified packages (Debian)
SELECT name, version FROM deb_packages WHERE admindir != '/var/lib/dpkg';
```

---

## 5. Decorators

Add contextual metadata to every query result.

```json
{
  "decorators": {
    "load": [
      "SELECT hostname AS host FROM system_info;",
      "SELECT version AS osquery_version FROM osquery_info;"
    ],
    "always": [
      "SELECT user AS current_user FROM logged_in_users ORDER BY time DESC LIMIT 1;"
    ],
    "interval": {
      "3600": [
        "SELECT total_seconds AS uptime FROM uptime;"
      ]
    }
  }
}
```

- `load`: run once when config is loaded
- `always`: run before every scheduled query
- `interval`: run at the specified interval (seconds)

---

## 6. Flags File

Override runtime options via `/etc/osquery/osquery.flags` (one flag per line).

```
--config_path=/etc/osquery/osquery.conf
--database_path=/var/osquery/osquery.db
--logger_path=/var/log/osquery
--pidfile=/var/run/osquery/osqueryd.pid
--disable_events=false
--enable_file_events=true
--events_expiry=86400
--events_max=100000
--verbose=false
--worker_threads=2
```

---

## 7. Shipping Logs to a SIEM

osquery writes JSON logs to files by default. Ship them to ELK, Splunk, or Loki
using a log forwarder.

### With Filebeat (ELK)

```yaml
# /etc/filebeat/filebeat.yml
filebeat.inputs:
  - type: log
    paths:
      - /var/log/osquery/osqueryd.results.log
    json.keys_under_root: true
    json.add_error_key: true

output.elasticsearch:
  hosts: ["http://elasticsearch:9200"]
  index: "osquery-%{+yyyy.MM.dd}"
```

### With Promtail (Loki)

```yaml
# /etc/promtail/config.yml
scrape_configs:
  - job_name: osquery
    static_configs:
      - targets: [localhost]
        labels:
          job: osquery
          __path__: /var/log/osquery/osqueryd.results.log
    pipeline_stages:
      - json:
          expressions:
            name: name
            action: action
```

---

## 8. Snapshot vs Differential Queries

```json
{
  "schedule": {
    "all_users_snapshot": {
      "query": "SELECT uid, username, shell FROM users;",
      "interval": 3600,
      "snapshot": true,
      "description": "Full user list every hour (point-in-time dump)"
    },
    "new_users_differential": {
      "query": "SELECT uid, username, shell FROM users;",
      "interval": 3600,
      "removed": false,
      "description": "Only newly added users since last run"
    }
  }
}
```

- `snapshot: true` logs all rows every interval (full dump)
- `removed: false` + no snapshot logs only added rows (ignores removals)
- Default (no flags) logs both added and removed rows (differential)
