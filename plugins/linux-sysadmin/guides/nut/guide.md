# nut

> **Based on:** nut 2.8.x | **Updated:** 2026-03-27

## Identity
- **Daemons**: `upsd` (data server), `upsmon` (monitor/shutdown), per-UPS driver (e.g., `usbhid-ups`)
- **Driver manager**: `upsdrvctl` (starts/stops all configured drivers)
- **Units**: `nut-server.service` (upsd), `nut-monitor.service` (upsmon), `nut-driver.service` (drivers)
- **Config dir**: `/etc/nut/` (Debian/Ubuntu) or `/etc/ups/` (RHEL)
- **Key files**:
  - `nut.conf` — mode selection (`MODE=standalone|netserver|netclient|none`)
  - `ups.conf` — driver config, one `[section]` per UPS
  - `upsd.conf` — data server settings (listen address, port)
  - `upsd.users` — authentication credentials for upsmon/clients
  - `upsmon.conf` — monitoring config (which UPS to watch, shutdown behavior)
- **Logs**: `journalctl -u nut-server`, `journalctl -u nut-monitor`
- **Install**: `apt install nut` / `dnf install nut`

## Quick Start

```bash
sudo apt install nut
sudo nut-scanner -U                    # auto-detect USB UPS devices
# Edit /etc/nut/nut.conf: MODE=standalone
# Edit /etc/nut/ups.conf with detected UPS
# Edit /etc/nut/upsd.users and upsmon.conf
sudo systemctl enable --now nut-server nut-monitor
upsc myups@localhost                   # query UPS status
```

## Architecture

```
USB/Serial/SNMP
       |
   UPS Driver (e.g., usbhid-ups)
       |
   upsd (data server, port 3493)
       |
   upsmon (monitoring client)
       → primary: commands shutdown when battery critical
       → secondary: shuts down early, lets primary handle UPS power-off
```

Three system types:

| Type | Description | Components |
|------|-------------|------------|
| Standalone | Single host, directly connected | driver + upsd + upsmon (primary) |
| Net server | UPS-connected host sharing with network | driver + upsd + upsmon (primary) |
| Net client | Remote host powered by shared UPS | upsmon (secondary) only |

## Key Operations

| Task | Command |
|------|---------|
| Query all UPS variables | `upsc myups@localhost` |
| Query specific variable | `upsc myups@localhost ups.status` |
| List detected USB UPS devices | `sudo nut-scanner -U` |
| Start all drivers | `sudo upsdrvctl start` |
| Stop all drivers | `sudo upsdrvctl stop` |
| Reload upsmon config | `sudo upsmon -c reload` |
| Force shutdown (FSD) | `sudo upsmon -c fsd` |
| Check if powerdown flag set | `sudo upsmon -K` |
| List clients connected to upsd | `upsc -l localhost` |
| Interactive UPS command | `upscmd -u admin -p pass myups@localhost test.battery.start` |
| Set UPS variable | `upsrw -u admin -p pass -s outlet.1.delay.shutdown=60 myups@localhost` |

## Expected Ports
- **3493/tcp** — upsd data server (default, localhost only)
- For network sharing: add `LISTEN 0.0.0.0 3493` to `upsd.conf`
- Verify: `ss -tlnp | grep upsd`

## Health Checks

1. `systemctl is-active nut-server` — upsd running
2. `upsc myups@localhost ups.status` — returns `OL` (online), `OB` (on battery), `LB` (low battery)
3. `upsc myups@localhost battery.charge` — returns percentage
4. `systemctl is-active nut-monitor` — upsmon running

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Driver won't start | Wrong driver name in `ups.conf` or permissions | Run `nut-scanner -U`; check `/dev/bus/usb` permissions; add `nut` user to `plugdev` group |
| `upsc` says "connection refused" | upsd not running or wrong listen address | `systemctl status nut-server`; check `LISTEN` in `upsd.conf` |
| "Access denied" from upsmon | Credentials mismatch | Verify username/password match between `upsd.users` and `upsmon.conf` |
| UPS detected but no data | Driver running but can't communicate | Check `dmesg` for USB disconnect; try `upsdrvctl -D start` for debug |
| Shutdown not happening on low battery | `MINSUPPLIES` or `MONITOR` line misconfigured in `upsmon.conf` | Verify power value in `MONITOR` line; check `SHUTDOWNCMD` path |
| Multiple USB UPS devices confused | No serial/product discrimination | Add `serial`, `product`, or `bus` to `ups.conf` section to disambiguate |
| Permission denied on `/dev/bus/usb` | udev rules missing | Install `nut` package (includes udev rules) or add manual rule for the device |

## Pain Points

- **MODE in `nut.conf` gates everything.** The init scripts check this variable first. If it's `none` (default), no services start. Set it to `standalone` for a single-host setup or `netserver` to share with remote clients.

- **Driver names are specific.** Each UPS model uses a particular driver (`usbhid-ups` for most USB units, `blazer_ser` for serial, `snmp-ups` for SNMP). Use `nut-scanner` or the Hardware Compatibility List to find yours. Wrong driver = silent failure.

- **`upsd.users` credentials flow to `upsmon.conf`.** The username and password you define in `upsd.users` must appear exactly in the `MONITOR` line of `upsmon.conf`. Any mismatch silently prevents monitoring.

- **Primary vs secondary matters.** The primary upsmon instance manages the UPS power-off after all secondaries have disconnected. If the primary goes down first, secondaries may not shut down cleanly. Design accordingly.

- **FSD (Forced Shutdown) is sticky.** Once the FSD flag is set, it cannot be cleared without restarting upsd. This is a safety feature but can surprise you during testing.

- **USB device permissions**: On Debian, the `nut` package installs udev rules. On other distros you may need to manually create `/etc/udev/rules.d/` rules granting the `nut` user access to the USB device.

## See Also

- **smartctl** — disk health monitoring via SMART; complementary hardware health check alongside UPS monitoring
- **systemd** — NUT integrates with systemd for graceful shutdown orchestration
- **netdata** — can monitor NUT metrics via its `nut` collector plugin

## References
See `references/` for:
- `docs.md` — official documentation links
