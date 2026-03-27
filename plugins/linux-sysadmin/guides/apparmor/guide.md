# apparmor

> **Based on:** apparmor 4.1.x | **Updated:** 2026-03-27

## Identity
- **Unit**: `apparmor.service`
- **Config dir**: `/etc/apparmor/` (parser config), `/etc/apparmor.d/` (profiles)
- **Local overrides**: `/etc/apparmor.d/local/` (per-profile additions without editing the main profile)
- **Abstractions**: `/etc/apparmor.d/abstractions/` (shared rule fragments like `base`, `nameservice`, `authentication`)
- **Tunables**: `/etc/apparmor.d/tunables/` (variables like `@{HOME}`, `@{PROC}`)
- **Cache**: `/var/cache/apparmor/` (compiled profiles for faster loading)
- **Logs**: `journalctl -k` or `/var/log/syslog` (kernel audit messages with `apparmor="DENIED"`)
- **Install**: Pre-installed on Debian/Ubuntu; `apt install apparmor apparmor-utils`

## Quick Start

```bash
sudo aa-status                         # show all profile states
sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx    # set to enforce mode
sudo aa-complain /etc/apparmor.d/usr.sbin.nginx   # set to complain (log-only) mode
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.nginx  # reload a profile
```

## Profile Modes

| Mode | Flag | Behavior |
|------|------|----------|
| **Enforce** | (default) | Violations are blocked and logged |
| **Complain** | `(complain)` | Violations are logged but allowed — use for testing |
| **Unconfined** | — | No profile loaded; process runs unrestricted |
| **Kill** | `(kill)` | Violations terminate the process immediately |

## Key Operations

| Task | Command |
|------|---------|
| Show all profiles and their mode | `sudo aa-status` |
| Set profile to enforce | `sudo aa-enforce /etc/apparmor.d/<profile>` |
| Set profile to complain | `sudo aa-complain /etc/apparmor.d/<profile>` |
| Disable a profile | `sudo aa-disable /etc/apparmor.d/<profile>` |
| Reload a profile | `sudo apparmor_parser -r /etc/apparmor.d/<profile>` |
| Reload all profiles | `sudo systemctl reload apparmor` |
| Generate profile interactively | `sudo aa-genprof /usr/sbin/myservice` |
| Update profile from logs | `sudo aa-logprof` |
| View denied actions | `sudo journalctl -k \| grep 'apparmor="DENIED"'` |
| List unconfined processes | `sudo aa-unconfined` |
| Check if AppArmor is enabled | `sudo aa-enabled` |
| Validate profile syntax | `sudo apparmor_parser -p /etc/apparmor.d/<profile>` |

## Profile Structure

```
# /etc/apparmor.d/usr.sbin.myapp

#include <tunables/global>

/usr/sbin/myapp {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  # Capabilities
  capability net_bind_service,
  capability setuid,

  # File access
  /etc/myapp/          r,
  /etc/myapp/**        r,
  /var/lib/myapp/      rw,
  /var/lib/myapp/**    rw,
  /var/log/myapp.log   w,
  /tmp/myapp.*         rw,

  # Network
  network inet tcp,
  network inet udp,

  # Deny explicitly
  deny /etc/shadow     r,

  # Include local overrides
  #include <local/usr.sbin.myapp>
}
```

File permission flags: `r` (read), `w` (write), `a` (append), `k` (lock), `l` (link), `m` (mmap exec), `x` (execute), `ix` (inherit), `px` (profile transition), `ux` (unconfined exec).

## Health Checks

1. `sudo aa-enabled` — returns "Yes"
2. `sudo aa-status | head -5` — shows module loaded, profile counts
3. `sudo aa-status | grep enforce` — profiles in enforce mode
4. `sudo journalctl -k --since "1 hour ago" | grep apparmor` — recent denials

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Service fails to start | Profile too restrictive for the service's needs | Switch to complain mode (`aa-complain`), run the service, then `aa-logprof` to update the profile |
| "Operation not permitted" in app | AppArmor blocking file/network access | Check `journalctl -k \| grep DENIED` for the specific denial; add rule to profile |
| Profile not loading | Syntax error in profile | `apparmor_parser -p <profile>` to validate; check for missing commas |
| `aa-status` shows 0 profiles | AppArmor service not started | `sudo systemctl enable --now apparmor` |
| Changes to profile not taking effect | Profile not reloaded | `sudo apparmor_parser -r /etc/apparmor.d/<profile>` |
| Docker containers unconfined | Docker/Podman AppArmor integration not configured | Docker applies `docker-default` profile automatically; custom profiles via `--security-opt apparmor=<profile>` |

## Pain Points

- **Use `local/` overrides instead of editing profiles directly.** Files in `/etc/apparmor.d/local/` are included at the end of the matching profile. Package updates overwrite profile files but never touch `local/`. This is the correct way to customize shipped profiles.

- **`aa-genprof` and `aa-logprof` are essential.** Writing profiles by hand is error-prone. Use `aa-genprof` to generate a profile while exercising the application, then `aa-logprof` to refine it from collected denials. This iterative workflow is how profiles are developed.

- **Complain mode is for testing, not production.** Leaving a profile in complain mode gives a false sense of security — violations are logged but not blocked. Use complain mode to develop profiles, then switch to enforce for production.

- **Abstractions are shared rule bundles.** Most profiles `#include <abstractions/base>` and `<abstractions/nameservice>`. These provide access to common system files (`/etc/passwd`, `/etc/hosts`, libc, etc.). Without them, almost every application fails.

- **AppArmor vs SELinux**: They're mutually exclusive on the same system. Debian/Ubuntu default to AppArmor. RHEL/Fedora default to SELinux. AppArmor uses path-based rules (simpler); SELinux uses label-based rules (more granular).

- **Docker uses AppArmor by default on Debian/Ubuntu.** The `docker-default` profile is auto-generated. Custom profiles can be applied per-container with `--security-opt apparmor=myprofile`.

## See Also

- **selinux** — alternative MAC system used on RHEL/Fedora; label-based rather than path-based
- **auditd** — kernel audit system; AppArmor denials appear in audit logs
- **sshd** — commonly confined by AppArmor; check profile if SSH behaves unexpectedly
- **docker** — applies AppArmor profiles to containers by default on supported systems

## References
See `references/` for:
- `docs.md` — official documentation links
