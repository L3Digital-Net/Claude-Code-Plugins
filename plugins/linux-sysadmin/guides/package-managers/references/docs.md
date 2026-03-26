# Package Manager Documentation

## apt / dpkg (Debian/Ubuntu)

### Official
- Debian Wiki -- APT: https://wiki.debian.org/Apt
- Debian Reference -- Package Management: https://www.debian.org/doc/manuals/debian-reference/ch02.en.html
- Debian FAQ -- Package Management Tools: https://www.debian.org/doc/manuals/debian-faq/pkgtools.en.html
- Debian Wiki -- SecureApt (GPG key management): https://wiki.debian.org/SecureApt
- Debian Wiki -- Unattended Upgrades: https://wiki.debian.org/UnattendedUpgrades
- Ubuntu Server -- Package Management: https://documentation.ubuntu.com/server/how-to/software/package-management/
- Ubuntu Server -- Automatic Updates: https://documentation.ubuntu.com/server/how-to/software/automatic-updates/

### Man pages
- `man apt(8)`, `man apt-get(8)`, `man apt-cache(8)`, `man apt-mark(8)`
- `man dpkg(1)`, `man dpkg-query(1)`
- `man sources.list(5)`, `man apt.conf(5)`, `man apt_preferences(5)`
- Online: https://man7.org/linux/man-pages/man1/dpkg.1.html

## dnf / yum (Fedora/RHEL)

### Official
- DNF Command Reference: https://dnf.readthedocs.io/en/latest/command_ref.html
- DNF Configuration Reference: https://dnf.readthedocs.io/en/latest/conf_ref.html
- DNF Automatic: https://dnf.readthedocs.io/en/latest/automatic.html
- DNF Plugins Core (versionlock, copr, etc.): https://dnf-plugins-core.readthedocs.io/en/latest/
- DNF Versionlock Plugin: https://dnf-plugins-core.readthedocs.io/en/latest/versionlock.html
- DNF COPR Plugin: https://dnf-plugins-core.readthedocs.io/en/latest/copr.html
- Fedora Docs -- Using DNF: https://docs.fedoraproject.org/en-US/quick-docs/dnf/
- DNF5 Documentation: https://dnf5.readthedocs.io/en/latest/
- GitHub -- rpm-software-management/dnf: https://github.com/rpm-software-management/dnf

### Man pages
- `man dnf(8)`, `man dnf.conf(5)`, `man dnf-automatic(8)`
- `man yum(8)` (symlink to dnf on modern systems)

## pacman (Arch Linux)

### Official
- Arch Wiki -- Pacman: https://wiki.archlinux.org/title/Pacman
- Arch Wiki -- Pacman Tips and Tricks: https://wiki.archlinux.org/title/Pacman/Tips_and_tricks
- Arch Wiki -- Downgrading Packages: https://wiki.archlinux.org/title/Downgrading_packages
- Arch Wiki -- AUR: https://wiki.archlinux.org/title/Arch_User_Repository
- Arch Wiki -- AUR Helpers: https://wiki.archlinux.org/title/AUR_helpers
- Arch Wiki -- Package Proxy Cache: https://wiki.archlinux.org/title/Package_proxy_cache
- Pacman Home Page: https://archlinux.org/pacman/

### Man pages
- `man pacman(8)`, `man pacman.conf(5)`, `man pacman-key(8)`
- `man paccache(8)` (from pacman-contrib)
- Online: https://man.archlinux.org/man/pacman.8.en
- Online: https://man.archlinux.org/man/pacman.conf.5.en

## apk (Alpine Linux)

### Official
- Alpine Linux -- Package Keeper: https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper
- Alpine Linux -- Repositories: https://wiki.alpinelinux.org/wiki/Repositories
- Alpine Linux User Handbook -- Working with apk: https://docs.alpinelinux.org/user-handbook/0.1a/Working/apk.html
- Alpine Package Index: https://pkgs.alpinelinux.org/packages
- GitHub -- alpinelinux/apk-tools: https://github.com/alpinelinux/apk-tools

### Man pages
- `man apk(8)`, `man apk-add(8)`, `man apk-del(8)`, `man apk-search(8)`
- `man apk-upgrade(8)`, `man apk-cache(8)`, `man apk-info(8)`
