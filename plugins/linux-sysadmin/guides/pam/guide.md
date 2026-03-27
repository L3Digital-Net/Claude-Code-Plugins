# pam

> **Based on:** distro-packaged (no independent version) | **Updated:** 2026-03-27

## Identity
- **Library**: `libpam` (Pluggable Authentication Modules)
- **Config dir**: `/etc/pam.d/` (per-service config files)
- **Global config**: `/etc/pam.conf` (legacy single-file format; rarely used)
- **Module dir**: `/usr/lib/x86_64-linux-gnu/security/` (Debian) or `/usr/lib64/security/` (RHEL)
- **Security limits**: `/etc/security/limits.conf`, `/etc/security/limits.d/*.conf`
- **Access control**: `/etc/security/access.conf`
- **Time restrictions**: `/etc/security/time.conf`
- **Logs**: `/var/log/auth.log` (Debian) or `/var/log/secure` (RHEL)
- **Install**: Pre-installed on all Linux distributions; `apt install libpam-modules libpam-modules-extra`

## Quick Start

```bash
cat /etc/pam.d/sshd                    # show PAM config for SSH
cat /etc/pam.d/common-auth             # show shared auth rules (Debian)
pamtester sshd myuser authenticate     # test PAM auth for a service
```

## How PAM Works

Every service that authenticates users (login, sshd, sudo, su, passwd) calls libpam. PAM checks a stack of modules defined in `/etc/pam.d/<service>`:

```
Application (sshd, sudo, login)
       ↓
    libpam
       ↓
    /etc/pam.d/<service>
       ↓
    Module stack (pam_unix, pam_deny, pam_permit, etc.)
       ↓
    Result: success or failure
```

## PAM Config Syntax

Each line in a PAM config file:

```
type    control    module    [arguments]
```

**Types** (module groups):

| Type | Purpose |
|------|---------|
| `auth` | Verify identity (password, token, biometric) |
| `account` | Account validation (expired? locked? access allowed?) |
| `password` | Update credentials (password change) |
| `session` | Setup/teardown session (set limits, mount home, log) |

**Control flags**:

| Control | Behavior |
|---------|----------|
| `required` | Must succeed; continues checking other modules even on failure |
| `requisite` | Must succeed; fails immediately on failure |
| `sufficient` | If this succeeds and no prior `required` failed, stop and succeed |
| `optional` | Result only matters if it's the only module for this type |
| `include` | Include another PAM config file |
| `substack` | Like include but failure doesn't propagate up |

## Key Modules

| Module | Purpose |
|--------|---------|
| `pam_unix` | Standard Unix password authentication (/etc/shadow) |
| `pam_deny` | Always deny — use as fallback |
| `pam_permit` | Always allow — use carefully |
| `pam_nologin` | Block non-root login when `/etc/nologin` exists |
| `pam_securetty` | Restrict root login to listed terminals |
| `pam_limits` | Set resource limits from `/etc/security/limits.conf` |
| `pam_access` | IP/hostname-based access control from `/etc/security/access.conf` |
| `pam_time` | Time-based access restrictions |
| `pam_faillock` | Lock accounts after failed login attempts (replaces pam_tally2) |
| `pam_pwquality` | Password complexity requirements |
| `pam_google_authenticator` | TOTP 2FA |
| `pam_u2f` | FIDO2/U2F hardware key auth |
| `pam_selinux` | Set SELinux context for sessions |
| `pam_systemd` | Register sessions with systemd-logind |
| `pam_env` | Set environment variables on login |
| `pam_mkhomedir` | Auto-create home directory on first login |
| `pam_motd` | Display message of the day |

## Key Operations

| Task | How |
|------|-----|
| View PAM config for a service | `cat /etc/pam.d/sshd` |
| Test authentication | `pamtester <service> <user> authenticate` (install `pamtester`) |
| Set password complexity | Edit `/etc/security/pwquality.conf` or add `pam_pwquality.so` to password stack |
| Set resource limits | Edit `/etc/security/limits.conf` |
| Lock account after N failures | Configure `pam_faillock` in auth stack |
| View failed login attempts | `faillock --user <username>` |
| Reset failed login counter | `faillock --user <username> --reset` |
| Enable 2FA for SSH | Install `libpam-google-authenticator`; add `pam_google_authenticator.so` to auth stack |
| Restrict login by IP | Edit `/etc/security/access.conf`; ensure `pam_access.so` is in account stack |

## Resource Limits (`limits.conf`)

```
# /etc/security/limits.conf
# <domain>    <type>    <item>    <value>

*             soft      nofile    65536
*             hard      nofile    131072
@developers   soft      nproc     4096
root          soft      nofile    131072
```

Common items: `nofile` (open files), `nproc` (processes), `memlock` (locked memory), `as` (address space), `core` (core dump size).

Systemd services use `LimitNOFILE=` in unit files instead of `limits.conf`.

## Health Checks

1. `cat /etc/pam.d/sshd` — config exists and looks sane
2. `pamtester sshd <user> authenticate` — test auth works
3. `grep -r pam_deny /etc/pam.d/` — verify fallback deny rules exist
4. `faillock --user <user>` — check for locked accounts

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Can't login despite correct password | Account locked by `pam_faillock` | `faillock --user <user> --reset` |
| `su` works but `sudo` doesn't | Different PAM stacks for `su` vs `sudo` | Check `/etc/pam.d/sudo` separately |
| All users locked out | Broken PAM config (typo, missing module) | Boot to recovery/single-user mode; fix `/etc/pam.d/` |
| Resource limits not applying | Using `limits.conf` for a systemd service | Set `LimitNOFILE=` in the systemd unit file instead |
| 2FA prompt not appearing | Module not in PAM stack or wrong position | Must be in `auth` section; check `required` vs `sufficient` ordering |
| "Module is unknown" | Module `.so` file not installed | Install the package (e.g., `libpam-google-authenticator`) |
| Password change rejected | `pam_pwquality` enforcing complexity | Check `/etc/security/pwquality.conf` for requirements |

## Pain Points

- **A broken PAM config can lock everyone out.** Always keep a root shell open in another terminal while editing PAM files. Test with `pamtester` before closing your session. If you lock yourself out, you'll need single-user mode or a live USB.

- **Order matters critically.** Modules are evaluated top-to-bottom. A `sufficient` module that succeeds stops evaluation — anything below it (including `required` checks) is skipped. Getting the order wrong is the most common PAM misconfiguration.

- **`required` vs `requisite`**: `required` continues checking remaining modules even after failure (collects all errors before denying). `requisite` stops immediately on failure. Use `required` for most cases to avoid leaking information about which specific check failed.

- **Debian and RHEL organize PAM differently.** Debian uses `common-auth`, `common-account`, `common-password`, `common-session` files that are included by service configs. RHEL uses `system-auth` and `password-auth` (managed by `authselect`). Don't copy PAM configs between distros without adapting.

- **`limits.conf` only applies to PAM-authenticated sessions.** Systemd services don't go through PAM (unless configured). Use `LimitNOFILE=`, `LimitNPROC=` etc. in systemd unit files for service limits.

- **`pam_faillock` replaced `pam_tally2`.** On modern systems, use `pam_faillock` for account lockout. `pam_tally2` is deprecated. The `faillock` command manages the lock state.

## See Also

- **sshd** — SSH authentication goes through PAM; `/etc/pam.d/sshd` controls SSH auth behavior
- **sysctl** — kernel parameters complementing PAM's resource limits
- **selinux** — `pam_selinux` module sets SELinux contexts for user sessions
- **apparmor** — separate MAC layer; PAM handles authentication, AppArmor handles access control

## References
See `references/` for:
- `docs.md` — official documentation links
