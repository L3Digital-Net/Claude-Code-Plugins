# rsyslog

> **Based on:** rsyslog 8.2602.0 | **Updated:** 2026-03-27

## Identity
- **Unit**: `rsyslog.service`
- **Config**: `/etc/rsyslog.conf` (main), `/etc/rsyslog.d/*.conf` (drop-in files)
- **Binary**: `/usr/sbin/rsyslogd`
- **Logs**: `journalctl -u rsyslog`, and rsyslog's own output files (typically `/var/log/syslog`, `/var/log/messages`)
- **Default log destinations**: `/var/log/syslog`, `/var/log/auth.log`, `/var/log/kern.log`, `/var/log/mail.log` (Debian layout)
- **Spool dir**: `/var/spool/rsyslog/` (for disk-assisted queues)
- **Install**: `apt install rsyslog` / `dnf install rsyslog`

## Quick Start

```bash
sudo apt install rsyslog
sudo systemctl enable --now rsyslog
logger "test message from CLI"         # send a test message
sudo tail /var/log/syslog              # verify it arrived
```

## Architecture

rsyslog processes messages through a pipeline:

```
Input modules (imuxsock, imjournal, imtcp, imudp, imfile)
       ↓
Parser chains (extract facility, severity, hostname, etc.)
       ↓
Filter rules (facility/severity, property-based, or RainerScript expressions)
       ↓
Action queues (in-memory or disk-assisted)
       ↓
Output modules (omfile, omfwd, omrelp, omprog, omelasticsearch)
```

## Key Modules

| Module | Direction | Purpose |
|--------|-----------|---------|
| `imuxsock` | Input | Receives local syslog via `/dev/log` socket |
| `imjournal` | Input | Reads from systemd journal |
| `imtcp` | Input | Receives syslog over TCP |
| `imudp` | Input | Receives syslog over UDP |
| `imfile` | Input | Tails plain text log files |
| `imrelp` | Input | Receives via RELP (reliable delivery) |
| `omfile` | Output | Writes to local files |
| `omfwd` | Output | Forwards via UDP or TCP |
| `omrelp` | Output | Forwards via RELP |
| `omprog` | Output | Pipes to external program |
| `mmjsonparse` | Parser | Parses structured JSON (RFC 5424) |

## Key Operations

| Task | Command |
|------|---------|
| Check status | `systemctl status rsyslog` |
| Test config syntax | `rsyslogd -N1` |
| Send test message | `logger -p local0.info "test message"` |
| Send tagged message | `logger -t myapp "something happened"` |
| Reload config (no restart) | `sudo systemctl reload rsyslog` |
| Debug mode | `sudo rsyslogd -dn` (foreground, very verbose) |
| Show loaded modules | `rsyslogd -v` |
| Check queue status | Look for `rsyslog_queue_*` files in spool dir |

## Expected Ports

- **514/udp** — traditional syslog (if `imudp` enabled)
- **514/tcp** — TCP syslog (if `imtcp` enabled)
- **2514/tcp** — common alternate for TLS syslog
- **20514/tcp** — RELP (if `imrelp` enabled)
- None by default — rsyslog only listens locally via `/dev/log` socket unless network input modules are loaded

## Configuration Syntax

rsyslog supports three config formats. Modern configs use RainerScript:

```
# Traditional (still works)
auth,authpriv.*    /var/log/auth.log

# Property-based filter
:programname, isequal, "sshd"    /var/log/sshd.log

# RainerScript (modern — preferred)
if $programname == "myapp" then {
    action(type="omfile" file="/var/log/myapp.log")
}
```

Remote forwarding:

```
# Forward to remote syslog over TCP
action(type="omfwd" target="loghost.example.com" port="514" protocol="tcp")

# Forward with TLS (requires gnutls module)
action(type="omfwd" target="loghost.example.com" port="2514" protocol="tcp"
       StreamDriver="gtls" StreamDriverMode="1"
       StreamDriverAuthMode="x509/name"
       StreamDriverPermittedPeers="loghost.example.com")
```

## Health Checks

1. `systemctl is-active rsyslog` — daemon running
2. `logger "healthcheck" && sleep 1 && grep healthcheck /var/log/syslog` — end-to-end test
3. `rsyslogd -N1` — config validates without errors
4. Check spool directory isn't growing (indicates output failures)

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| No logs appearing | rsyslog not running or imuxsock/imjournal not loaded | `systemctl status rsyslog`; check module loads in config |
| Duplicate messages | Both `imuxsock` and `imjournal` active on systemd host | Use one or the other; `imjournal` is preferred on systemd systems |
| Remote host not receiving | Firewall blocking, or input module not loaded on receiver | Open port; add `module(load="imtcp")` and `input(type="imtcp" port="514")` |
| Config syntax error | Mixing old-style and RainerScript incorrectly | Run `rsyslogd -N1` to find the error; don't mix formats in same rule |
| Disk filling up | Log destination has no rotation or rate-limiting | Configure logrotate; add `$SystemLogRateLimitInterval` and `$SystemLogRateLimitBurst` |
| Queue files growing in spool | Output target unreachable; disk-assisted queue buffering | Check target connectivity; queue will drain when target recovers |
| TLS forwarding fails | Certificate mismatch or missing `gtls` module | Install `rsyslog-gnutls`; verify cert paths and permissions |

## Pain Points

- **`imjournal` vs `imuxsock` on systemd systems.** On modern systemd hosts, use `imjournal` to read from the journal. Loading both `imuxsock` and `imjournal` causes duplicate messages. Debian's default config handles this, but custom configs often get it wrong.

- **Three config syntaxes coexist.** Traditional BSD-style (`facility.severity /path`), property-based (`:property, comparison, "value"`), and RainerScript (`if ... then { ... }`). They can be mixed in one file but this gets confusing fast. Prefer RainerScript for new rules.

- **Rate limiting is on by default.** `$SystemLogRateLimitInterval 5` and `$SystemLogRateLimitBurst 500` are the defaults. Bursty applications may lose messages silently. Tune these or disable per-source with `$IMJournalRatelimitInterval 0`.

- **RELP for reliable delivery.** Plain TCP syslog can lose messages on connection drops (no application-layer ack). RELP (`omrelp`/`imrelp`) provides reliable delivery. Use it for anything where log loss is unacceptable.

- **Disk-assisted queues need spool directory.** If you configure `queue.type="LinkedList"` with `queue.filename=...`, rsyslog writes to `/var/spool/rsyslog/`. Ensure the directory exists and has correct permissions.

- **Template syntax is powerful but verbose.** Custom log formats use templates. The `list` format is most readable for new templates:
  ```
  template(name="myformat" type="list") {
      property(name="timestamp" dateFormat="rfc3339")
      constant(value=" ")
      property(name="hostname")
      constant(value=" ")
      property(name="msg" spifno1teleading="on" droplastlf="on")
      constant(value="\n")
  }
  ```

## See Also

- **journald** — systemd's native journal; rsyslog can read from it via `imjournal` or replace it for traditional file-based logging
- **logrotate** — essential companion for rsyslog file outputs; prevents disk exhaustion
- **loki** — modern log aggregation; can replace remote rsyslog forwarding with a pull/push model
- **elk-stack** — rsyslog can forward directly to Elasticsearch via `omelasticsearch`

## References
See `references/` for:
- `docs.md` — official documentation links
