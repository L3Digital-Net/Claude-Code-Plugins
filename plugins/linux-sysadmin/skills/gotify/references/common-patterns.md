# Gotify Common Patterns

Each block is copy-paste-ready. Assumes Gotify is running on `localhost:8080`.

---

## 1. Docker Compose Setup

Standard deployment with persistent data and configurable credentials.

```yaml
# docker-compose.yml
services:
  gotify:
    image: gotify/server
    container_name: gotify
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      GOTIFY_DEFAULTUSER_NAME: admin
      GOTIFY_DEFAULTUSER_PASS: "${GOTIFY_ADMIN_PASS}"   # set in .env file
      TZ: "America/New_York"                              # adjust timezone
    volumes:
      - gotify-data:/app/data

volumes:
  gotify-data:
```

Start: `docker compose up -d`
WebUI: http://localhost:8080

---

## 2. Docker Compose with SSL

Direct HTTPS without a reverse proxy (useful for simple setups).

```yaml
services:
  gotify:
    image: gotify/server
    container_name: gotify
    restart: unless-stopped
    ports:
      - "443:443"
    environment:
      GOTIFY_DEFAULTUSER_NAME: admin
      GOTIFY_DEFAULTUSER_PASS: "${GOTIFY_ADMIN_PASS}"
      GOTIFY_SERVER_SSL_ENABLED: "true"
      GOTIFY_SERVER_SSL_REDIRECTTOHTTPS: "true"
      GOTIFY_SERVER_SSL_PORT: "443"
      GOTIFY_SERVER_SSL_CERTFILE: /certs/fullchain.pem
      GOTIFY_SERVER_SSL_CERTKEY: /certs/privkey.pem
      # Optional Let's Encrypt (self-managed):
      # GOTIFY_SERVER_SSL_LETSENCRYPT_ENABLED: "true"
      # GOTIFY_SERVER_SSL_LETSENCRYPT_ACCEPTTOS: "true"
      # GOTIFY_SERVER_SSL_LETSENCRYPT_CACHE: /certs
    volumes:
      - gotify-data:/app/data
      - /etc/letsencrypt/live/gotify.example.com:/certs:ro

volumes:
  gotify-data:
```

---

## 3. Behind Traefik Reverse Proxy

```yaml
services:
  gotify:
    image: gotify/server
    container_name: gotify
    restart: unless-stopped
    environment:
      GOTIFY_DEFAULTUSER_NAME: admin
      GOTIFY_DEFAULTUSER_PASS: "${GOTIFY_ADMIN_PASS}"
    volumes:
      - gotify-data:/app/data
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gotify.rule=Host(`gotify.example.com`)"
      - "traefik.http.routers.gotify.entrypoints=websecure"
      - "traefik.http.routers.gotify.tls.certresolver=letsencrypt"
      - "traefik.http.services.gotify.loadbalancer.server.port=80"

networks:
  proxy:
    external: true

volumes:
  gotify-data:
```

---

## 4. Sending Messages from Shell Scripts

### Simple notification

```bash
#!/bin/bash
GOTIFY_URL="http://localhost:8080"
GOTIFY_TOKEN="your-app-token-here"

# Form-encoded (simplest)
curl -s "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
  -F "title=Backup Complete" \
  -F "message=Daily backup finished successfully" \
  -F "priority=4"

# JSON (more flexible, supports extras)
curl -s -X POST "${GOTIFY_URL}/message" \
  -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Backup Complete",
    "message": "Daily backup finished successfully.\n\nSize: 2.4 GB\nDuration: 12 min",
    "priority": 4,
    "extras": {
      "client::display": {
        "contentType": "text/markdown"
      }
    }
  }'
```

### Markdown-formatted messages

Gotify supports markdown rendering when the `client::display` extra is set.

```bash
curl -s -X POST "${GOTIFY_URL}/message" \
  -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Server Report",
    "message": "## Disk Usage\n- `/`: 45% used\n- `/home`: 72% used\n\n## Services\n- nginx: **running**\n- postgres: **running**",
    "priority": 3,
    "extras": {
      "client::display": {
        "contentType": "text/markdown"
      }
    }
  }'
```

---

## 5. Notification on SSH Login

Add to `/etc/pam.d/sshd` or use a script in `/etc/profile.d/`.

```bash
#!/bin/bash
# /etc/profile.d/gotify-login.sh
# Sends a Gotify notification on every interactive SSH login

if [ -n "$SSH_CONNECTION" ]; then
  GOTIFY_URL="http://localhost:8080"
  GOTIFY_TOKEN="your-app-token-here"
  USER_INFO="$(whoami)@$(hostname)"
  SRC_IP="$(echo "$SSH_CONNECTION" | awk '{print $1}')"

  curl -s "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
    -F "title=SSH Login: ${USER_INFO}" \
    -F "message=Source: ${SRC_IP} at $(date '+%Y-%m-%d %H:%M:%S')" \
    -F "priority=7" > /dev/null 2>&1
fi
```

---

## 6. Monitoring Integration: Disk Space Alert

Cron job that sends a Gotify alert when disk usage exceeds a threshold.

```bash
#!/bin/bash
# /usr/local/bin/disk-alert.sh
THRESHOLD=85
GOTIFY_URL="http://localhost:8080"
GOTIFY_TOKEN="your-app-token-here"

df -h --output=pcent,target | tail -n +2 | while read pct mount; do
  usage="${pct%%%}"
  if [ "$usage" -ge "$THRESHOLD" ]; then
    curl -s "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
      -F "title=Disk Alert: ${mount}" \
      -F "message=${mount} is ${pct} full on $(hostname)" \
      -F "priority=8" > /dev/null 2>&1
  fi
done
```

Crontab entry: `*/15 * * * * /usr/local/bin/disk-alert.sh`

---

## 7. Gotify from Python

```python
import requests

GOTIFY_URL = "http://localhost:8080"
GOTIFY_TOKEN = "your-app-token-here"

def send_notification(title: str, message: str, priority: int = 4) -> None:
    resp = requests.post(
        f"{GOTIFY_URL}/message",
        headers={"X-Gotify-Key": GOTIFY_TOKEN},
        json={
            "title": title,
            "message": message,
            "priority": priority,
        },
    )
    resp.raise_for_status()

# Usage
send_notification("Deploy Complete", "v2.1.0 deployed to production", priority=5)
```

---

## 8. WebSocket Message Stream

Subscribe to real-time messages using a client token.

```bash
# Install wscat: npm install -g wscat
wscat -c "ws://localhost:8080/stream?token=<clienttoken>"

# Or with curl (HTTP upgrade)
curl -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  "http://localhost:8080/stream?token=<clienttoken>"
```

Messages arrive as JSON objects:
```json
{
  "id": 42,
  "appid": 1,
  "message": "Hello world",
  "title": "Test",
  "priority": 5,
  "date": "2026-03-14T10:30:00Z"
}
```

---

## 9. Environment Variables Reference

| Variable | Default | Purpose |
|----------|---------|---------|
| `GOTIFY_DEFAULTUSER_NAME` | `admin` | Initial admin username (first start only) |
| `GOTIFY_DEFAULTUSER_PASS` | `admin` | Initial admin password (first start only) |
| `GOTIFY_SERVER_PORT` | `80` | HTTP listen port |
| `GOTIFY_SERVER_SSL_ENABLED` | `false` | Enable HTTPS |
| `GOTIFY_SERVER_SSL_PORT` | `443` | HTTPS listen port |
| `GOTIFY_SERVER_SSL_CERTFILE` | — | Path to TLS certificate |
| `GOTIFY_SERVER_SSL_CERTKEY` | — | Path to TLS private key |
| `GOTIFY_SERVER_SSL_LETSENCRYPT_ENABLED` | `false` | Auto-provision Let's Encrypt cert |
| `GOTIFY_SERVER_SSL_LETSENCRYPT_ACCEPTTOS` | `false` | Accept LE terms of service |
| `GOTIFY_SERVER_RESPONSEHEADERS` | — | Custom response headers (JSON) |
| `GOTIFY_DATABASE_DIALECT` | `sqlite3` | Database type: `sqlite3`, `mysql`, `postgres` |
| `GOTIFY_DATABASE_CONNECTION` | `data/gotify.db` | Database connection string |
| `GOTIFY_PASSSTRENGTH` | `10` | Bcrypt password hashing cost |
| `GOTIFY_UPLOADEDIMAGESDIR` | `data/images` | Directory for uploaded images |
| `GOTIFY_PLUGINSDIR` | `data/plugins` | Directory for server plugins |
