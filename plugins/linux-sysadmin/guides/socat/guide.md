# socat

> **Based on:** socat 1.8.1.1 | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/bin/socat`
- **Config**: None (all configuration via command-line arguments)
- **Related**: `netcat` (`nc`/`ncat`) — simpler alternative for basic tasks
- **Install**: `apt install socat` / `dnf install socat`

## Quick Start

```bash
# TCP port forwarder
socat TCP-LISTEN:8080,fork TCP:10.0.0.5:80

# Simple TCP listener (like nc -l)
socat TCP-LISTEN:1234 STDOUT

# Connect to a TCP service
socat - TCP:example.com:80

# Unix socket to TCP bridge
socat TCP-LISTEN:3306,fork UNIX-CONNECT:/var/run/mysqld/mysqld.sock
```

## What It Does

socat establishes a bidirectional data channel between two addresses. Each address can be a network socket (TCP/UDP), Unix socket, file, pipe, stdin/stdout, SSL/TLS endpoint, serial device, or exec'd process. It's the Swiss army knife for connecting anything to anything.

## Address Types

| Address | Example | Purpose |
|---------|---------|---------|
| `TCP-LISTEN` | `TCP-LISTEN:8080,fork,reuseaddr` | Listen on TCP port |
| `TCP` | `TCP:host:port` | Connect to TCP |
| `TCP4` / `TCP6` | `TCP4-LISTEN:80` | Force IPv4 or IPv6 |
| `UDP-LISTEN` | `UDP-LISTEN:5000` | Listen on UDP port |
| `UDP` | `UDP:host:port` | Send UDP |
| `UNIX-LISTEN` | `UNIX-LISTEN:/tmp/my.sock` | Listen on Unix socket |
| `UNIX-CONNECT` | `UNIX-CONNECT:/var/run/docker.sock` | Connect to Unix socket |
| `OPENSSL` | `OPENSSL:host:443` | TLS client |
| `OPENSSL-LISTEN` | `OPENSSL-LISTEN:443,cert=server.pem` | TLS server |
| `EXEC` | `EXEC:/bin/bash` | Connect to process stdin/stdout |
| `STDIN` / `STDOUT` | `-` (shorthand) | Terminal I/O |
| `FILE` | `FILE:/var/log/output.log,create` | Read/write file |
| `PTY` | `PTY,link=/tmp/mypty` | Create pseudo-terminal |
| `PIPE` | `PIPE:/tmp/mypipe` | Named pipe |

## Key Operations

| Task | Command |
|------|---------|
| TCP port forward | `socat TCP-LISTEN:8080,fork TCP:10.0.0.5:80` |
| TCP port forward (background) | `socat -d TCP-LISTEN:8080,fork TCP:10.0.0.5:80 &` |
| Unix socket to TCP | `socat TCP-LISTEN:5432,fork UNIX-CONNECT:/var/run/postgresql/.s.PGSQL.5432` |
| TLS tunnel (client) | `socat TCP-LISTEN:3306,fork OPENSSL:dbhost:3307,verify=0` |
| TLS tunnel (server) | `socat OPENSSL-LISTEN:443,cert=cert.pem,key=key.pem,fork TCP:localhost:80` |
| Simple chat (two terminals) | Terminal 1: `socat TCP-LISTEN:1234 -` / Terminal 2: `socat - TCP:localhost:1234` |
| Expose Docker socket over TCP | `socat TCP-LISTEN:2375,fork UNIX-CONNECT:/var/run/docker.sock` |
| Serial port to TCP | `socat TCP-LISTEN:2000,fork /dev/ttyUSB0,b9600,raw` |
| UDP relay | `socat UDP-LISTEN:5000,fork UDP:10.0.0.5:5000` |
| Bidirectional pipe | `socat EXEC:"ssh remote cat /etc/hosts" STDOUT` |
| File transfer | Receiver: `socat TCP-LISTEN:9999 FILE:received.tar.gz,create` / Sender: `socat FILE:data.tar.gz TCP:host:9999` |
| Debug with verbose output | `socat -d -d -d TCP-LISTEN:8080,fork TCP:10.0.0.5:80` |

## Common Options

| Option | Purpose |
|--------|---------|
| `fork` | Handle multiple connections (fork per connection) |
| `reuseaddr` | Allow port reuse (avoid "Address already in use") |
| `bind=IP` | Bind to specific interface |
| `-d` | Debug output (repeat for more: `-d -d -d`) |
| `-v` | Verbose data dump (shows transferred bytes) |
| `-T timeout` | Total timeout in seconds |
| `-t timeout` | Idle timeout for data transfer |
| `verify=0` | Skip TLS certificate verification (testing only) |

## Health Checks

1. `which socat` — installed
2. `socat -V` — shows version and compiled-in features (OpenSSL, readline, etc.)
3. `socat -h | grep OPENSSL` — TLS support compiled in

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Address already in use" | Port still bound from previous socat | Add `reuseaddr` option; or wait / kill previous instance |
| Only one connection works | Missing `fork` option | Add `fork` to the LISTEN address for multi-connection |
| TLS connection fails | Certificate mismatch or missing | Use `verify=0` for testing; provide correct `cert=` and `key=` for production |
| "Permission denied" on port <1024 | Not running as root | Use `sudo` or bind to port ≥1024 |
| Data appears garbled | Binary data through terminal | Use `FILE:` or pipe instead of STDOUT for binary data |
| Connection resets immediately | Target not accepting connections | Verify target host:port is reachable; check firewall |

## Pain Points

- **socat vs netcat.** Use `nc`/`ncat` for simple TCP tests ("is this port open?"). Use socat when you need TLS wrapping, Unix socket bridging, serial port access, or complex bidirectional relays. socat is netcat on steroids.

- **`fork` is almost always needed for listeners.** Without `fork`, socat handles one connection and exits. For a persistent relay, always include `fork` on the LISTEN side.

- **Security implications of socket bridging.** Exposing a Unix socket over TCP (e.g., Docker socket) creates a network-accessible attack surface. Only do this on trusted networks or behind authentication. Never expose Docker socket to the internet.

- **Debug with `-d -d`.** socat's debug output is excellent. Two `-d` flags show connection lifecycle; three show detailed I/O. Invaluable for troubleshooting.

- **socat as a testing tool.** It's ideal for ad-hoc testing: creating temporary port forwards, testing TLS connections, simulating services, or bridging protocols during debugging.

## See Also

- **curl-wget** — HTTP-specific clients; socat handles arbitrary TCP/UDP/Unix/TLS
- **openssl-cli** — `openssl s_client` for TLS debugging; socat for TLS relaying
- **ss** — show active sockets; use to verify socat listeners
- **nmap** — port scanning; socat for opening/relaying ports

## References
See `references/` for:
- `docs.md` — official documentation links
