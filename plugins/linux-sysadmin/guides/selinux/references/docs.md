# SELinux Documentation

## Official

- SELinux project: https://selinuxproject.org/
- SELinux Notebook (comprehensive reference): https://github.com/SELinuxProject/selinux-notebook
- Fedora SELinux guide: https://docs.fedoraproject.org/en-US/quick-docs/selinux-getting-started/

## RHEL/CentOS

- RHEL 9 SELinux guide: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/
- RHEL SELinux troubleshooting: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/troubleshooting-problems-related-to-selinux_using-selinux

## Other Distributions

- ArchWiki: https://wiki.archlinux.org/title/SELinux
- Debian wiki: https://wiki.debian.org/SELinux
- Gentoo wiki: https://wiki.gentoo.org/wiki/SELinux

## Tools

- audit2allow: https://man7.org/linux/man-pages/man1/audit2allow.1.html
- semanage: https://man7.org/linux/man-pages/man8/semanage.8.html
- setroubleshoot: https://github.com/fedora-selinux/setroubleshoot

## Man Pages

- `man selinux` — overview
- `man sestatus` — status display
- `man getenforce` / `man setenforce` — mode control
- `man semanage` — policy management (fcontext, port, boolean)
- `man restorecon` — restore default file contexts
- `man audit2allow` — generate policy from denials
- `man sealert` — human-readable denial analysis
- `man getsebool` / `man setsebool` — boolean management
