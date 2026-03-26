# Common Package Manager Patterns

Practical recipes for routine and advanced package management tasks.

---

## 1. Unattended Security Upgrades (apt)

Install and enable automatic security updates on Debian/Ubuntu.

```bash
sudo apt install unattended-upgrades

# Enable the auto-upgrade timer
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Config files:**
- `/etc/apt/apt.conf.d/20auto-upgrades` -- controls the schedule:
  ```
  APT::Periodic::Update-Package-Lists "1";
  APT::Periodic::Unattended-Upgrade "1";
  ```
- `/etc/apt/apt.conf.d/50unattended-upgrades` -- controls which packages and behavior:
  ```
  Unattended-Upgrade::Allowed-Origins {
      "${distro_id}:${distro_codename}-security";
  };
  Unattended-Upgrade::Package-Blacklist {
      // "linux-";    // uncomment to exclude kernel upgrades
  };
  Unattended-Upgrade::Automatic-Reboot "false";
  ```

Custom overrides belong in a file that sorts after `50`, such as `52unattended-upgrades-local`,
to avoid conflicts when `unattended-upgrades` is upgraded.

**Dry run**: `sudo unattended-upgrade --dry-run --debug`

---

## 2. Automatic Updates (dnf-automatic)

Install and enable automatic updates on Fedora/RHEL.

```bash
sudo dnf install dnf-automatic
```

**Config file**: `/etc/dnf/automatic.conf`
```ini
[commands]
# Options: default (all), security
upgrade_type = default
# Options: yes, no
download_updates = yes
apply_updates = yes

[commands]
# Options: never, when-changed, when-needed
reboot = when-needed

[emitters]
# Options: stdio, email, motd
emit_via = stdio
```

**Enable the timer** (pick one):
```bash
# Download + install automatically
sudo systemctl enable --now dnf-automatic-install.timer

# Download only (review before installing)
sudo systemctl enable --now dnf-automatic-download.timer
```

**Check timer status**: `systemctl list-timers dnf-automatic*`

---

## 3. Creating a Local Mirror / Cache

### apt (apt-cacher-ng)
```bash
sudo apt install apt-cacher-ng
# Runs on port 3142 by default
# Config: /etc/apt-cacher-ng/acng.conf

# On client machines, create proxy config:
echo 'Acquire::http::Proxy "http://cache-server:3142";' \
  | sudo tee /etc/apt/apt.conf.d/00proxy
```

### dnf (local repo from downloaded RPMs)
```bash
sudo dnf install createrepo_c
# Copy RPMs to a directory, then:
sudo createrepo_c /var/local/myrepo

# Add as a repo:
cat <<EOF | sudo tee /etc/yum.repos.d/local.repo
[local]
name=Local Repo
baseurl=file:///var/local/myrepo
enabled=1
gpgcheck=0
EOF
```

### pacman (pacoloco cache proxy)
```bash
# On the cache server:
# Install pacoloco (available in community repo)
sudo pacman -S pacoloco
# Config: /etc/pacoloco/config.yaml
# Default port: 9129

# On client machines, add to top of /etc/pacman.d/mirrorlist:
# Server = http://cache-server:9129/repo/archlinux/$repo/os/$arch
```

### apk (local cache)
```bash
# Enable the built-in cache (stores packages in /var/cache/apk/):
sudo setup-apkcache /var/cache/apk

# Or use the --cache-dir flag:
apk --cache-dir /var/cache/apk add <pkg>
```

---

## 4. Downgrading a Package

### apt
```bash
# List available versions:
apt-cache madison <pkg>
# or: apt-cache showpkg <pkg>

# Install specific older version:
sudo apt install <pkg>=<version>

# Prevent it from upgrading again:
sudo apt-mark hold <pkg>
```

### dnf
```bash
# Downgrade to the highest available lower version:
sudo dnf downgrade <pkg>

# Or install a specific version:
sudo dnf install <pkg>-<version>

# Lock it:
sudo dnf versionlock add <pkg>
```

### pacman
```bash
# From the local cache (if the old version is still cached):
sudo pacman -U /var/cache/pacman/pkg/<pkg>-<old-version>.pkg.tar.zst

# From the Arch Linux Archive:
sudo pacman -U https://archive.archlinux.org/packages/<first-letter>/<pkg>/<pkg>-<version>-<arch>.pkg.tar.zst

# Prevent upgrade:
# Add to IgnorePkg in /etc/pacman.conf
```

### apk
```bash
# Install a specific older version (must be available in repos):
apk add '<pkg>=<version>'

# Use version constraints:
apk add '<pkg><1.5'    # less than 1.5
apk add '<pkg>=~1.4'   # fuzzy match 1.4.x
```

---

## 5. Listing Manually Installed Packages

### apt
```bash
apt-mark showmanual
# State tracked in: /var/lib/apt/extended_states
```

### dnf
```bash
dnf history userinstalled
# Or with more formatting control:
dnf repoquery --userinstalled
```

### pacman
```bash
# Explicitly installed (not as dependency):
pacman -Qet
# -Q = query, -e = explicit, -t = not required by anything
```

### apk
```bash
# The world file IS the list of manually requested packages:
cat /etc/apk/world
```

---

## 6. Finding and Removing Orphaned Packages

Orphans are packages installed as dependencies that are no longer needed.

### apt
```bash
# List orphans:
apt autoremove --dry-run

# Remove orphans:
sudo apt autoremove

# To protect a package from autoremove (mark as manually installed):
sudo apt-mark manual <pkg>
```

### dnf
```bash
# List orphans:
dnf autoremove --dry-run

# Remove orphans:
sudo dnf autoremove
```

### pacman
```bash
# List orphans:
pacman -Qtdq

# Remove all orphans recursively:
sudo pacman -Rns $(pacman -Qtdq)

# If no orphans found, the command will error (expected behavior).
```

### apk
```bash
# apk handles this automatically on `apk del`.
# To audit system state:
apk audit
```

---

## 7. Proxy Configuration

### apt
Create `/etc/apt/apt.conf.d/99proxy`:
```
Acquire::http::Proxy "http://proxy.example.com:3128";
Acquire::https::Proxy "http://proxy.example.com:3128";
```
With authentication:
```
Acquire::http::Proxy "http://user:pass@proxy.example.com:3128";
```

### dnf
Add to `[main]` section in `/etc/dnf/dnf.conf`:
```ini
proxy=http://proxy.example.com:3128
proxy_username=user
proxy_password=pass
proxy_auth_method=basic
```

### pacman
Pacman has no native proxy config. Options:

1. **Environment variables** (requires `sudo -E` to preserve them):
   ```bash
   export http_proxy="http://proxy.example.com:3128"
   export https_proxy="http://proxy.example.com:3128"
   sudo -E pacman -Syu
   ```

2. **XferCommand with wget** in `/etc/pacman.conf`:
   ```
   XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
   ```
   Then configure proxy in `/etc/wgetrc`:
   ```
   use_proxy=on
   http_proxy=http://proxy.example.com:3128
   https_proxy=http://proxy.example.com:3128
   ```

### apk
apk respects standard environment variables:
```bash
export http_proxy="http://proxy.example.com:3128"
export https_proxy="http://proxy.example.com:3128"
apk update && apk upgrade
```

---

## 8. Lock File Troubleshooting

When a package manager crashes or is interrupted, stale lock files can block future operations.

### apt

Lock files: `/var/lib/dpkg/lock`, `/var/lib/dpkg/lock-frontend`, `/var/lib/apt/lists/lock`, `/var/cache/apt/archives/lock`

```bash
# 1. Check if any apt/dpkg process is actually running:
ps aux | grep -E 'apt|dpkg'

# 2. If no process is running, remove locks and reconfigure:
sudo rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend \
           /var/lib/apt/lists/lock /var/cache/apt/archives/lock
sudo dpkg --configure -a
```

### dnf

Lock file: `/var/cache/dnf/metadata_lock.pid`

```bash
# 1. Check for running dnf/yum processes:
ps aux | grep -E 'dnf|yum'

# 2. If no process is running:
sudo rm -f /var/cache/dnf/metadata_lock.pid
```

### pacman

Lock file: `/var/lib/pacman/db.lck`

```bash
# 1. CRITICAL: verify no pacman process is running:
ps aux | grep pacman

# 2. Only if no process is running:
sudo rm /var/lib/pacman/db.lck

# 3. Also clean any partial downloads:
find /var/cache/pacman/pkg/ -iname "*.part" -delete
```

### apk

apk uses atomic operations and doesn't create persistent lock files. If an operation is
interrupted, run `apk fix` to repair any inconsistencies:

```bash
sudo apk fix
```
