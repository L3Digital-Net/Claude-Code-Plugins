# selinux

> **Based on:** distro-packaged (no independent version) | **Updated:** 2026-03-27

## Identity
- **Config**: `/etc/selinux/config` (mode and policy type)
- **Policy store**: `/etc/selinux/targeted/` (the default targeted policy)
- **Booleans**: runtime toggles for policy features
- **Logs**: `/var/log/audit/audit.log` (if auditd running), `journalctl -t setroubleshoot`
- **Status tool**: `sestatus`, `getenforce`
- **Install**: Pre-installed on RHEL, Fedora, CentOS, Rocky, Alma; `apt install selinux-basics selinux-policy-default` on Debian

## Quick Start

```bash
getenforce                             # show current mode
sestatus                               # detailed status
sudo setenforce 1                      # switch to Enforcing (runtime only)
sudo setenforce 0                      # switch to Permissive (runtime only)
ls -Z /var/www/                        # show file contexts
ps -eZ | grep httpd                    # show process contexts
```

## Modes

| Mode | Effect |
|------|--------|
| **Enforcing** | Policy is enforced; violations are blocked and logged |
| **Permissive** | Policy violations are logged but not blocked — use for debugging |
| **Disabled** | SELinux is completely off (requires reboot to change; relabeling needed to re-enable) |

Set persistently in `/etc/selinux/config`: `SELINUX=enforcing`

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Context** | Label on every file, process, port: `user:role:type:level` (e.g., `system_u:object_r:httpd_sys_content_t:s0`) |
| **Type** | The most important part of a context. Policy rules are written in terms of types (type enforcement). |
| **Domain** | The type assigned to a process (e.g., `httpd_t`) |
| **Boolean** | On/off switch for optional policy features (e.g., `httpd_can_network_connect`) |
| **Policy** | The set of all allow rules. "Targeted" policy confines specific services; everything else runs unconfined. |
| **Transition** | When a process executes a binary, SELinux may assign a new domain based on the binary's type. |

## Key Operations

| Task | Command |
|------|---------|
| Check current mode | `getenforce` |
| Detailed status | `sestatus` |
| Set mode (runtime) | `sudo setenforce 1` (Enforcing) / `sudo setenforce 0` (Permissive) |
| Show file context | `ls -Z /path/to/file` |
| Show process context | `ps -eZ \| grep <process>` |
| Show port contexts | `sudo semanage port -l` |
| Restore default file context | `sudo restorecon -Rv /var/www/` |
| Set custom file context | `sudo semanage fcontext -a -t httpd_sys_content_t "/srv/web(/.*)?"` then `sudo restorecon -Rv /srv/web/` |
| List all booleans | `getsebool -a` |
| Show specific boolean | `getsebool httpd_can_network_connect` |
| Set boolean (persistent) | `sudo setsebool -P httpd_can_network_connect on` |
| Allow custom port for service | `sudo semanage port -a -t http_port_t -p tcp 8080` |
| View AVC denials | `sudo ausearch -m AVC -ts recent` |
| Generate allow rule from denial | `sudo ausearch -m AVC -ts recent \| audit2allow -M mypolicy` |
| Apply generated module | `sudo semodule -i mypolicy.pp` |
| Full filesystem relabel | `sudo touch /.autorelabel && sudo reboot` |
| Check why something was denied | `sudo sealert -a /var/log/audit/audit.log` |

## Common Workflow: Fixing a Denial

```bash
# 1. Identify the denial
sudo ausearch -m AVC -ts recent

# 2. Read the human-friendly explanation
sudo sealert -a /var/log/audit/audit.log   # requires setroubleshoot

# 3. Common fixes (in order of preference):
# a) Fix the file context (most common)
sudo restorecon -Rv /path/to/files

# b) Enable a boolean
sudo setsebool -P httpd_can_network_connect on

# c) Add a custom port
sudo semanage port -a -t http_port_t -p tcp 8080

# d) Last resort: generate a custom policy module
sudo ausearch -m AVC -ts recent | audit2allow -M mypolicy
sudo semodule -i mypolicy.pp
```

## Health Checks

1. `getenforce` — should return `Enforcing`
2. `sestatus` — shows policy version, mode, and policy name
3. `sudo ausearch -m AVC -ts today | head` — check for recent denials
4. `ls -Z /etc/selinux/config` — config file has correct context

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Service can't read its files | Wrong file context | `restorecon -Rv /path`; verify with `ls -Z` |
| Service can't connect to network | Boolean not set | `setsebool -P <service>_can_network_connect on` |
| Service can't bind to non-standard port | Port not labeled for that service | `semanage port -a -t <service>_port_t -p tcp <port>` |
| Files moved (not copied) have wrong context | `mv` preserves context; `cp` inherits from destination | `restorecon -Rv /new/path` |
| Permissive globally but shouldn't be | `/etc/selinux/config` set to `permissive` | Edit config, set `SELINUX=enforcing`, reboot |
| Re-enabling after disable requires full relabel | Filesystem has no contexts | `touch /.autorelabel && reboot` (takes a while on large filesystems) |
| `audit2allow` generates overly broad rules | Using it on too many denials at once | Filter `ausearch` to the specific service; review generated rules before applying |

## Pain Points

- **Don't disable SELinux.** The most common "fix" is the worst one. Setting `SELINUX=disabled` in config removes all MAC protection and requires a full filesystem relabel to re-enable. Use Permissive mode for debugging instead.

- **File context is the #1 issue.** Most SELinux denials are caused by files with wrong contexts. `mv` preserves the source context (wrong); `cp` inherits the destination context (right). After moving files, always run `restorecon`.

- **Booleans before custom policy.** Before generating a custom module with `audit2allow`, check if a boolean already covers your use case: `getsebool -a | grep <service>`. Booleans are maintained by the policy team; custom modules are on you.

- **`audit2allow` is a last resort, not a first step.** It generates allow rules that may be overly broad. Always review the output. The `-M` flag creates a module you can inspect before installing.

- **Targeted policy means most things are unconfined.** The default "targeted" policy only confines specific services (httpd, sshd, named, etc.). Non-targeted processes run as `unconfined_t`. This is by design — it focuses enforcement where it matters most.

- **`setroubleshoot` gives human-readable explanations.** Install `setroubleshoot-server` to get `sealert`, which translates raw AVC denials into English with suggested fixes. Essential for debugging.

## See Also

- **apparmor** — alternative MAC system used on Debian/Ubuntu; path-based rather than label-based
- **auditd** — SELinux denials are logged as AVC messages in the audit log
- **pam** — PAM modules set the SELinux context for user sessions (pam_selinux)
- **sshd** — commonly confined by SELinux; context issues cause SSH failures

## References
See `references/` for:
- `docs.md` — official documentation links
