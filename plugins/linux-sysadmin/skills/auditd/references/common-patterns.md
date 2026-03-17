# Common auditd Patterns

Practical recipes for monitoring, compliance, and log analysis. Each pattern includes the rule, how to trigger it, and how to search for matching events.

---

## 1. Watch /etc/passwd for Changes

Detect user account creation, deletion, or modification.

**Rule:**
```bash
sudo auditctl -w /etc/passwd -p wa -k identity
```

**Trigger:**
```bash
sudo useradd testuser
sudo userdel testuser
```

**Search:**
```bash
sudo ausearch -k identity -i
sudo ausearch -k identity -i -ts today
```

**Report:**
```bash
sudo aureport -k --summary    # see which keys have the most hits
```

---

## 2. Monitor Sudo Usage

Track every invocation of sudo: who ran what, and when.

**Rule:**
```bash
sudo auditctl -w /usr/bin/sudo -p x -k sudo_usage
sudo auditctl -w /etc/sudoers -p wa -k sudoers_change
sudo auditctl -w /etc/sudoers.d/ -p wa -k sudoers_change
```

**Search:**
```bash
# All sudo executions
sudo ausearch -k sudo_usage -i

# Sudo executions by a specific user
sudo ausearch -k sudo_usage -ul jdoe -i

# Sudoers file modifications
sudo ausearch -k sudoers_change -i
```

---

## 3. Track File Deletions

Forensic trail for deleted files: who deleted what and when.

**Rule (syscall-based, both architectures):**
```bash
sudo auditctl -a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=-1 -k file_delete
sudo auditctl -a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=-1 -k file_delete
```

**Search:**
```bash
sudo ausearch -k file_delete -i
sudo ausearch -k file_delete -f /path/to/deleted/file -i
```

---

## 4. PCI-DSS Compliance Rules

PCI-DSS v3.1/v4.0 Requirement 10: Track and monitor all access to network resources and cardholder data. The upstream `audit-userspace` project provides `30-pci-dss-v31.rules` as a starting point.

**Key controls and corresponding rules:**

```bash
# PCI 10.1 -- Audit trail for all access to system components
# Link individual user actions to their login UID:
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=-1 -k pci_exec

# PCI 10.2.1 -- All individual user access to cardholder data
# Monitor the directory or database where cardholder data is stored:
-w /srv/cardholder-data/ -p rwxa -k pci_chd_access

# PCI 10.2.2 -- Actions taken by any individual with root or admin privileges
-a always,exit -F arch=b64 -F euid=0 -S execve -k pci_root_cmd
-a always,exit -F arch=b32 -F euid=0 -S execve -k pci_root_cmd

# PCI 10.2.3 -- Access to all audit trails
-w /var/log/audit/ -p wa -k pci_audit_trail
-w /etc/audit/ -p wa -k pci_audit_config

# PCI 10.2.4 -- Invalid logical access attempts
-a always,exit -F arch=b64 -S open -S openat -F exit=-EACCES -F auid>=1000 -F auid!=-1 -k pci_access_fail
-a always,exit -F arch=b64 -S open -S openat -F exit=-EPERM -F auid>=1000 -F auid!=-1 -k pci_access_fail

# PCI 10.2.5 -- Use of and changes to identification and authentication mechanisms
-w /etc/passwd -p wa -k pci_identity
-w /etc/shadow -p wa -k pci_identity
-w /etc/group -p wa -k pci_identity
-w /etc/pam.d/ -p wa -k pci_identity

# PCI 10.2.6 -- Initialization, stopping, or pausing of audit logs
-w /etc/audit/auditd.conf -p wa -k pci_audit_config
-w /etc/audit/rules.d/ -p wa -k pci_audit_config

# PCI 10.2.7 -- Creation and deletion of system-level objects
-a always,exit -F arch=b64 -S mknod -S mknodat -F auid>=1000 -F auid!=-1 -k pci_sys_objects

# PCI 10.4 -- Time synchronization
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k pci_time_change
-w /etc/localtime -p wa -k pci_time_change
```

**Verification:**
```bash
# Confirm PCI rules are loaded
sudo auditctl -l | grep pci

# Generate PCI-relevant reports
sudo aureport -k --summary | grep pci
sudo aureport --auth --failed --summary
sudo aureport -f --summary
```

---

## 5. CIS Benchmark Rules

CIS benchmarks (Level 1 and Level 2) define specific audit rules. These map to CIS controls for RHEL, Ubuntu, and Debian. Place them in `/etc/audit/rules.d/30-cis.rules`.

```bash
# CIS 4.1.4 -- Ensure events that modify date and time information are collected
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# CIS 4.1.5 -- Ensure events that modify user/group information are collected
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# CIS 4.1.6 -- Ensure events that modify the system's network environment are collected
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/hostname -p wa -k system-locale
-w /etc/NetworkManager/ -p wa -k system-locale

# CIS 4.1.7 -- Ensure events that modify the system's Mandatory Access Controls are collected
-w /etc/selinux/ -p wa -k MAC-policy
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy

# CIS 4.1.8 -- Ensure login and logout events are collected
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# CIS 4.1.9 -- Ensure session initiation information is collected
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# CIS 4.1.10 -- Ensure discretionary access control permission modification events are collected
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=-1 -k perm_mod

# CIS 4.1.11 -- Ensure unsuccessful unauthorized file access attempts are collected
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=-1 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=-1 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=-1 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=-1 -k access

# CIS 4.1.13 -- Ensure successful file system mounts are collected
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=-1 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=-1 -k mounts

# CIS 4.1.14 -- Ensure file deletion events by users are collected
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=-1 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=-1 -k delete

# CIS 4.1.15 -- Ensure changes to system administration scope are collected
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# CIS 4.1.16 -- Ensure system administrator actions are collected
-w /var/log/sudo.log -p wa -k actions

# CIS 4.1.17 -- Ensure kernel module loading and unloading is collected
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules
```

---

## 6. Custom Key-Based Filtering with ausearch

Keys (`-k`) are the primary mechanism for organizing audit events. Use descriptive, consistent keys, then query them directly.

**Searching by key:**
```bash
# All events for a specific key
sudo ausearch -k identity -i

# Events for a key within a time range
sudo ausearch -k identity -ts 2026-03-14 08:00:00 -te 2026-03-14 17:00:00 -i

# Events for a key by a specific user
sudo ausearch -k identity -ul 1000 -i

# Failed events only for a key
sudo ausearch -k access -sv no -i

# Combine key + file
sudo ausearch -k identity -f /etc/shadow -i

# Output as CSV for external processing
sudo ausearch -k rootcmd --format csv > /tmp/root-commands.csv
```

**Reporting by key:**
```bash
# Summary of all keys and their event counts
sudo aureport -k --summary

# Detailed key report for a time range
sudo aureport -k -ts today -te now

# Most common keys (descending by count)
sudo aureport -k --summary | sort -rn -k1
```

**Key naming conventions used in this skill:**

| Key | Purpose |
|-----|---------|
| `identity` | User/group database changes (/etc/passwd, /etc/shadow, etc.) |
| `sudoers` | Sudoers file and directory changes |
| `sshd_config` | SSH daemon configuration changes |
| `pam_config` | PAM module configuration changes |
| `cron` | Cron job and schedule changes |
| `network_config` | Network configuration changes |
| `systemd_config` | Systemd unit file changes |
| `mac_policy` | SELinux/AppArmor policy changes |
| `audit_config` | Audit system configuration changes |
| `login_events` | Login/logout and session records |
| `time_change` | System clock modifications |
| `modules` | Kernel module load/unload |
| `mounts` | Filesystem mount operations |
| `file_delete` | File deletions by users |
| `access_denied` | Failed file access attempts (EACCES/EPERM) |
| `rootcmd` | Commands executed as root |
| `perm_mod` | Permission changes (chmod/chown) |
| `owner_mod` | Ownership changes (chown/lchown) |
| `xattr_mod` | Extended attribute changes |
| `priv_esc` | Privilege escalation tool execution |

---

## 7. ausearch Quick Reference

```bash
# Events from boot
sudo ausearch -ts boot -i

# Events from today
sudo ausearch -ts today -i

# Events in the last hour
sudo ausearch -ts recent -i

# Events by specific PID
sudo ausearch -p 12345 -i

# Events by executable
sudo ausearch -x /usr/bin/passwd -i

# Events by syscall name
sudo ausearch -sc openat -i

# Events for a specific file
sudo ausearch -f /etc/passwd -i

# Raw output (for piping to other tools)
sudo ausearch -k identity -r

# Only successful events
sudo ausearch -k access_denied -sv yes -i

# Only failed events
sudo ausearch -k access_denied -sv no -i

# Events by message type
sudo ausearch -m USER_LOGIN -i
sudo ausearch -m SYSCALL,PATH -i
```

---

## 8. aureport Quick Reference

```bash
# Overall summary
sudo aureport --summary

# Authentication report (all / failed / successful)
sudo aureport --auth
sudo aureport --auth --failed
sudo aureport --auth --success

# Login report
sudo aureport -l
sudo aureport -l --failed

# File access report
sudo aureport -f --summary

# Syscall report
sudo aureport -s --summary

# Account modification report
sudo aureport -m

# Anomaly report
sudo aureport -n

# Executable report
sudo aureport -x --summary

# Configuration change report
sudo aureport -c

# Report for a specific time window
sudo aureport --auth --failed -ts yesterday -te today

# TTY keystroke report (if TTY auditing is enabled)
sudo aureport --tty
```
