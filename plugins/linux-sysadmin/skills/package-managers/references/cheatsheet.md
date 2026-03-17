# Package Manager Cheatsheet

Side-by-side comparison of equivalent commands across apt, dnf, pacman, and apk.

## Core Operations

| Task | apt | dnf | pacman | apk |
|------|-----|-----|--------|-----|
| Install package | `apt install <pkg>` | `dnf install <pkg>` | `pacman -S <pkg>` | `apk add <pkg>` |
| Remove package | `apt remove <pkg>` | `dnf remove <pkg>` | `pacman -R <pkg>` | `apk del <pkg>` |
| Remove + purge config | `apt purge <pkg>` | `dnf remove <pkg>` (no separate purge) | `pacman -Rns <pkg>` | `apk del --purge <pkg>` |
| Remove + unused deps | `apt autoremove` | (automatic by default) | `pacman -Rs <pkg>` | (automatic by default) |
| Search repos | `apt search <term>` | `dnf search <term>` | `pacman -Ss <term>` | `apk search <term>` |
| Search installed | `dpkg -l \| grep <term>` | `dnf list installed \| grep <term>` | `pacman -Qs <term>` | `apk info \| grep <term>` |
| Update package index | `apt update` | (automatic) | `pacman -Sy` (never alone!) | `apk update` |
| Upgrade all packages | `apt upgrade` | `dnf upgrade` | `pacman -Syu` | `apk upgrade` |
| Full dist upgrade | `apt full-upgrade` | `dnf distro-sync` | `pacman -Syu` (same) | `apk upgrade --available` |
| List installed | `apt list --installed` | `dnf list installed` | `pacman -Q` | `apk info` |
| Show package info | `apt show <pkg>` | `dnf info <pkg>` | `pacman -Si <pkg>` (repo) / `-Qi` (local) | `apk info <pkg>` |
| Clean cache (partial) | `apt autoclean` | `dnf clean packages` | `paccache -r` | `apk cache clean` |
| Clean cache (full) | `apt clean` | `dnf clean all` | `pacman -Scc` | `rm -rf /var/cache/apk/*` |
| List files in package | `dpkg -L <pkg>` | `rpm -ql <pkg>` | `pacman -Ql <pkg>` | `apk info -L <pkg>` |
| Which pkg owns file | `dpkg -S /path` | `dnf provides /path` | `pacman -Qo /path` | `apk info --who-owns /path` |
| Hold/pin version | `apt-mark hold <pkg>` | `dnf versionlock add <pkg>` | `IgnorePkg` in pacman.conf | `apk add <pkg>=<ver>` |
| Unhold/unpin | `apt-mark unhold <pkg>` | `dnf versionlock delete <pkg>` | Remove from `IgnorePkg` | `apk add <pkg>` |
| List held/pinned | `apt-mark showhold` | `dnf versionlock list` | Check pacman.conf | Check `/etc/apk/world` |
| Add repository | See note 1 | `dnf config-manager --add-repo <url>` | Edit pacman.conf | Edit `/etc/apk/repositories` |
| Install specific version | `apt install <pkg>=<ver>` | `dnf install <pkg>-<ver>` | `pacman -U <url-or-file>` | `apk add '<pkg>=<ver>'` |
| Downgrade | `apt install <pkg>=<old-ver>` | `dnf downgrade <pkg>` | `pacman -U /var/cache/pacman/pkg/<pkg>-<old>.pkg.tar.zst` | `apk add '<pkg><old-ver>'` |
| List available versions | `apt-cache madison <pkg>` | `dnf --showduplicates list <pkg>` | (check Arch Linux Archive) | `apk policy <pkg>` |
| Reinstall | `apt reinstall <pkg>` | `dnf reinstall <pkg>` | `pacman -S <pkg>` (overwrites) | `apk fix <pkg>` |
| Manually installed list | `apt-mark showmanual` | `dnf history userinstalled` | `pacman -Qet` | Check `/etc/apk/world` |
| Find orphan packages | `apt autoremove --dry-run` | `dnf autoremove --dry-run` | `pacman -Qtdq` | `apk info -r` (reverse deps) |

## Notes

1. **apt repo addition** (modern): Download GPG key to `/etc/apt/keyrings/`, create `.list` or `.sources` file in `/etc/apt/sources.list.d/` with `signed-by=` pointing to the key. For Ubuntu PPAs: `add-apt-repository ppa:user/name`.

2. **dnf COPR repos**: `dnf copr enable user/project` (requires `dnf-plugins-core`).

3. **pacman AUR**: Use an AUR helper like `yay` or `paru` for AUR packages. Pacman itself only handles official repos.

4. **apk tagged repos**: Prefix repo lines with `@tag` in `/etc/apk/repositories`, then `apk add pkg@tag`.
