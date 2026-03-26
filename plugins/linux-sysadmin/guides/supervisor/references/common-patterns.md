# Supervisor Common Patterns

Each block is copy-paste-ready. Config files use INI format. On Debian/Ubuntu,
drop program configs in `/etc/supervisor/conf.d/` and run `supervisorctl reread && supervisorctl update`.

---

## 1. Basic Program Configuration

Single long-running process managed by Supervisor.

```ini
; /etc/supervisor/conf.d/myapp.conf
[program:myapp]
command=/usr/bin/python3 /opt/myapp/app.py --port 8000
directory=/opt/myapp
user=www-data
autostart=true
autorestart=true
startsecs=5
startretries=3
stopwaitsecs=10
stopsignal=TERM

; Logging
stdout_logfile=/var/log/supervisor/myapp-stdout.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=5
stderr_logfile=/var/log/supervisor/myapp-stderr.log
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=5

; Merge stderr into stdout (alternative to separate files)
; redirect_stderr=true

; Environment variables
environment=NODE_ENV="production",DATABASE_URL="postgres://localhost/mydb"
```

Apply: `sudo supervisorctl reread && sudo supervisorctl update`

---

## 2. Multiple Process Instances (numprocs)

Run N copies of the same program with unique names and ports.

```ini
; /etc/supervisor/conf.d/workers.conf
[program:worker]
command=/opt/myapp/worker.py --id %(process_num)s
process_name=%(program_name)s_%(process_num)02d
numprocs=4
numprocs_start=0
directory=/opt/myapp
user=www-data
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/worker_%(process_num)02d.log
stderr_logfile=/var/log/supervisor/worker_%(process_num)02d-error.log
```

This creates: `worker_00`, `worker_01`, `worker_02`, `worker_03`.

Control individually or as a group:
```bash
supervisorctl start worker:worker_00
supervisorctl restart worker:*          # all instances
supervisorctl status worker:*
```

---

## 3. Process Groups

Group related programs for unified control. Groups override the program's own name
in supervisorctl.

```ini
; /etc/supervisor/conf.d/webstack.conf
[program:gunicorn]
command=/opt/myapp/.venv/bin/gunicorn app:app -b 0.0.0.0:8000 -w 4
directory=/opt/myapp
user=www-data
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/gunicorn.log

[program:celery]
command=/opt/myapp/.venv/bin/celery -A tasks worker --loglevel=info
directory=/opt/myapp
user=www-data
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/celery.log

[program:celery-beat]
command=/opt/myapp/.venv/bin/celery -A tasks beat --loglevel=info
directory=/opt/myapp
user=www-data
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/celery-beat.log

[group:myapp]
programs=gunicorn,celery,celery-beat
priority=999
```

Control the group:
```bash
supervisorctl start myapp:*
supervisorctl stop myapp:*
supervisorctl restart myapp:*
supervisorctl status myapp:*
```

---

## 4. Web UI (inet_http_server)

Enable the built-in web dashboard. Bind to localhost only in production.

```ini
; Add to /etc/supervisor/supervisord.conf (or a separate include)

[inet_http_server]
port=127.0.0.1:9001
username=admin
password=changeme
; password can also be a SHA-1 hash: {SHA}5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8
```

Access at: http://localhost:9001

To expose via reverse proxy (nginx):
```nginx
location /supervisor/ {
    proxy_pass http://127.0.0.1:9001/;
    proxy_set_header Host $host;
    auth_basic "Supervisor";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

---

## 5. Event Listeners

React to process state changes (crashes, starts, stops). The `superlance` package
provides ready-made listeners.

### Email on crash (superlance crashmail)

```bash
pip install superlance
```

```ini
; /etc/supervisor/conf.d/crashmail.conf
[eventlistener:crashmail]
command=crashmail -a -m admin@example.com -s /usr/sbin/sendmail
events=PROCESS_STATE_EXITED
redirect_stderr=false
stdout_logfile=/var/log/supervisor/crashmail.log
```

### Custom event listener script

```ini
[eventlistener:my_listener]
command=/opt/scripts/supervisor_listener.py
events=PROCESS_STATE_EXITED,PROCESS_STATE_FATAL
buffer_size=10
stdout_logfile=/var/log/supervisor/listener.log
```

```python
#!/usr/bin/env python3
# /opt/scripts/supervisor_listener.py
"""Minimal Supervisor event listener that logs process crashes."""
import sys
import subprocess

def main():
    while True:
        # Supervisor sends "READY\n" and waits for events
        sys.stdout.write("READY\n")
        sys.stdout.flush()

        # Read header line
        header = sys.stdin.readline()
        headers = dict(x.split(":") for x in header.strip().split())

        # Read payload
        data_len = int(headers["len"])
        payload = sys.stdin.read(data_len)

        # Parse payload
        pairs = dict(x.split(":") for x in payload.split())
        process = pairs.get("processname", "unknown")
        event = headers.get("eventname", "unknown")

        # Do something (log, send notification, etc.)
        with open("/var/log/supervisor/events.log", "a") as f:
            f.write(f"{event}: {process}\n")

        # Acknowledge
        sys.stdout.write("RESULT 2\nOK")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
```

---

## 6. Priority and Startup Order

Programs start in ascending `priority` order. Lower numbers start first.

```ini
[program:database]
command=/usr/bin/redis-server
priority=100
autostart=true

[program:backend]
command=/opt/myapp/backend.py
priority=200
autostart=true

[program:frontend]
command=/opt/myapp/frontend.py
priority=300
autostart=true
```

Note: Supervisor does NOT wait for a program to be "ready" before starting the next.
For true dependency ordering, use a wrapper script:

```bash
#!/bin/bash
# /opt/myapp/wait-and-start.sh
# Wait for Redis to be ready, then start the backend
until redis-cli ping > /dev/null 2>&1; do
  sleep 1
done
exec /opt/myapp/backend.py
```

---

## 7. Docker Entrypoint with Supervisor

Use Supervisor as PID 1 inside a Docker container to manage multiple processes.

```ini
; /etc/supervisor/supervisord.conf (inside container)
[supervisord]
nodaemon=true
user=root
logfile=/dev/stdout
logfile_maxbytes=0

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:app]
command=gunicorn app:app -b 127.0.0.1:8000
directory=/app
user=www-data
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
```

```dockerfile
FROM python:3.12-slim

RUN apt-get update && apt-get install -y supervisor nginx && rm -rf /var/lib/apt/lists/*

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY . /app

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
```

Key settings for Docker:
- `nodaemon=true` keeps supervisord in the foreground (required for Docker)
- `logfile=/dev/stdout` and `logfile_maxbytes=0` send logs to Docker's log driver
- Same pattern for program stdout/stderr

---

## 8. Wrapper Script for Environment Setup

When a program needs complex environment setup that the `environment` directive cannot handle.

```bash
#!/bin/bash
# /opt/myapp/run.sh
set -euo pipefail

# Source environment from file
set -a
source /opt/myapp/.env
set +a

# Activate virtualenv
source /opt/myapp/.venv/bin/activate

# Run the application
exec python -m myapp.server
```

```ini
[program:myapp]
command=/opt/myapp/run.sh
directory=/opt/myapp
user=www-data
autostart=true
autorestart=true
```

The `exec` in the wrapper script is important: it replaces the shell process with the
application, so Supervisor's signal handling (TERM, HUP) reaches the application directly.

---

## 9. Log Management

### Separate log files per program (default)
```ini
stdout_logfile=/var/log/supervisor/myapp.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
stderr_logfile=/var/log/supervisor/myapp-error.log
```

### Merge stderr into stdout
```ini
redirect_stderr=true
stdout_logfile=/var/log/supervisor/myapp.log
```

### Syslog output
```ini
stdout_logfile=syslog
stderr_logfile=syslog
```

### Disable log rotation (for external log shippers)
```ini
stdout_logfile=/var/log/supervisor/myapp.log
stdout_logfile_maxbytes=0
stdout_logfile_backups=0
```
