# auditd Documentation

## Official / Upstream
- Linux Audit userspace repo (source, sample rules): https://github.com/linux-audit/audit-userspace
- Sample rules directory in repo: https://github.com/linux-audit/audit-userspace/tree/master/rules

## Man Pages
- `auditd(8)` -- audit daemon: https://man7.org/linux/man-pages/man8/auditd.8.html
- `auditd.conf(5)` -- daemon config: https://man7.org/linux/man-pages/man5/auditd.conf.5.html
- `auditctl(8)` -- rule management: https://man7.org/linux/man-pages/man8/auditctl.8.html
- `ausearch(8)` -- log search: https://man7.org/linux/man-pages/man8/ausearch.8.html
- `aureport(8)` -- log reports: https://man7.org/linux/man-pages/man8/aureport.8.html
- `audit.rules(7)` -- rule file format: https://man7.org/linux/man-pages/man7/audit.rules.7.html

## Red Hat / RHEL
- RHEL 9 Security Hardening -- Auditing the system: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/security_hardening/auditing-the-system_security-hardening
- RHEL 10 Risk Reduction -- Auditing the system: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/risk_reduction_and_recovery_operations/auditing-the-system
- RHEL 8 Security Hardening -- Auditing the system: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/security_hardening/auditing-the-system_security-hardening
- RHEL 7 Security Guide -- Defining Audit Rules: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/security_guide/sec-defining_audit_rules_and_controls
- Red Hat Blog -- Configure Linux system auditing with auditd: https://www.redhat.com/en/blog/configure-linux-auditing-auditd

## STIG / Compliance
- PCI-DSS v3.1 sample rules: https://github.com/linux-audit/audit-userspace/blob/master/rules/30-pci-dss-v31.rules
- STIG sample rules: https://github.com/linux-audit/audit-userspace/blob/master/rules/30-stig.rules
- OSPP v4.2 sample rules: https://github.com/linux-audit/audit-userspace/blob/master/rules/30-ospp-v42.rules
- DISA STIG Viewer (search for "auditd"): https://www.stigviewer.com/

## Community
- Neo23x0 auditd best practices: https://github.com/Neo23x0/auditd
- Neo23x0 best practice config gist: https://gist.github.com/Neo23x0/9fe88c0c5979e017a389b90fd19ddfee
- SUSE documentation -- Understanding Linux Audit: https://documentation.suse.com/sles/15-SP7/html/SLES-all/cha-audit-comp.html
- Arch Wiki (no dedicated page, but references in security articles)

## Local Man Pages
- `man auditd`, `man auditd.conf`, `man auditctl`, `man ausearch`, `man aureport`, `man audit.rules`, `man augenrules`
