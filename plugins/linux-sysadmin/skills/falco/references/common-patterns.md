# Falco Common Patterns

Each block below is a complete, copy-paste-ready rule or configuration snippet. Place custom
rules in `/etc/falco/falco_rules.local.yaml` or in a file under `/etc/falco/rules.d/`.
Rules load in `rules_files` order; macros and lists must be defined before rules that use them.

---

## 1. Detect Shell Spawned in Container

Fires when any shell binary executes inside a container. One of the most common detection
scenarios for container security.

```yaml
- list: shell_binaries
  items: [bash, csh, ksh, sh, tcsh, zsh, dash]

- macro: spawned_process
  condition: (evt.type in (execve, execveat))

- macro: container
  condition: (container.id != host)

- rule: Shell spawned in container
  desc: >
    A shell was started inside a running container. This could indicate an
    attacker has gained interactive access.
  condition: >
    spawned_process and container and
    proc.name in (shell_binaries)
  output: >
    Shell spawned in container
    (user=%user.name container=%container.name
    shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline image=%container.image.repository)
  priority: WARNING
  tags: [container, shell, mitre_execution]
```

---

## 2. Detect Sensitive File Access

Fires when a non-trusted process reads a sensitive file such as `/etc/shadow` or
`/etc/sudoers`. Useful for detecting credential harvesting.

```yaml
- list: sensitive_files
  items:
    - /etc/shadow
    - /etc/sudoers
    - /etc/pam.conf

- macro: sensitive_file_read
  condition: >
    (open_read and fd.name in (sensitive_files))

- rule: Sensitive file read by untrusted process
  desc: >
    A process not in the trusted list opened a sensitive authentication
    file for reading.
  condition: >
    sensitive_file_read and
    not proc.name in (sudo, su, sshd, passwd, login, systemd)
  output: >
    Sensitive file opened for reading
    (user=%user.name file=%fd.name process=%proc.name
    parent=%proc.pname cmdline=%proc.cmdline)
  priority: WARNING
  tags: [host, filesystem, mitre_credential_access]
```

---

## 3. Detect Privilege Escalation via setuid

Fires when a process changes its UID to root (0). Catches exploits that escalate from
an unprivileged user to root.

```yaml
- rule: Non-root user becomes root
  desc: >
    A process changed its effective UID to 0 (root) while running as a
    non-root user, which could indicate privilege escalation.
  condition: >
    evt.type = setuid and evt.arg.uid = 0 and
    user.uid != 0
  output: >
    Privilege escalation detected
    (user=%user.name proc=%proc.name cmdline=%proc.cmdline
    container=%container.name)
  priority: CRITICAL
  tags: [host, container, mitre_privilege_escalation]
```

---

## 4. Detect Outbound Connection from Container

Fires when a container initiates an outbound network connection. Useful for detecting
reverse shells or data exfiltration from compromised containers.

```yaml
- rule: Unexpected outbound connection from container
  desc: >
    A container initiated an outbound network connection to an external IP.
    Containers that only serve inbound requests should not make outbound calls.
  condition: >
    (evt.type in (connect, sendto, sendmsg)) and
    container and
    fd.typechar = 4 and
    fd.ip != "0.0.0.0" and
    not fd.snet in (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8)
  output: >
    Outbound connection from container
    (container=%container.name image=%container.image.repository
    proc=%proc.name connection=%fd.name user=%user.name)
  priority: NOTICE
  tags: [container, network, mitre_exfiltration]
```

---

## 5. Detect Container Running as Root

Fires when a new process spawns inside a container running as UID 0. Many container
security policies require non-root execution.

```yaml
- rule: Container process running as root
  desc: >
    A process is running as root (UID 0) inside a container. Production
    containers should run as a non-root user.
  condition: >
    spawned_process and container and
    user.uid = 0
  output: >
    Root process in container
    (user=%user.name proc=%proc.name container=%container.name
    image=%container.image.repository cmdline=%proc.cmdline)
  priority: NOTICE
  tags: [container, users, mitre_initial_access]
```

---

## 6. Detect Unauthorized Kubernetes Namespace Access

Fires when a process executes in a production namespace that is not in the allowed
process list. Requires working CRI socket for `k8s.ns.name` resolution.

```yaml
- list: production_namespaces
  items: [production, prod, kube-system]

- list: allowed_production_procs
  items: [nginx, envoy, node, python3, java]

- rule: Unauthorized process in production namespace
  desc: >
    A process that is not in the allowed list started in a production
    Kubernetes namespace.
  condition: >
    spawned_process and container and
    k8s.ns.name in (production_namespaces) and
    not proc.name in (allowed_production_procs)
  output: >
    Unauthorized process in production namespace
    (proc=%proc.name ns=%k8s.ns.name pod=%k8s.pod.name
    image=%container.image.repository cmdline=%proc.cmdline)
  priority: ERROR
  tags: [kubernetes, mitre_execution]
```

---

## 7. Detect Package Manager in Container

Fires when a package manager runs inside a container at runtime, which could indicate
an attacker installing tools.

```yaml
- list: package_managers
  items: [apt, apt-get, dpkg, yum, dnf, rpm, apk, pip, pip3, npm, gem]

- rule: Package manager in container
  desc: >
    A package manager was invoked inside a running container. Packages should
    be installed at build time, not runtime.
  condition: >
    spawned_process and container and
    proc.name in (package_managers)
  output: >
    Package manager invoked in container
    (user=%user.name proc=%proc.name container=%container.name
    image=%container.image.repository cmdline=%proc.cmdline)
  priority: ERROR
  tags: [container, software_mgmt, mitre_execution]
```

---

## 8. Disable a Noisy Default Rule

The default ruleset fires on many routine admin operations. Override specific rules in
`falco_rules.local.yaml` rather than editing the upstream file.

```yaml
# Disable a rule entirely
- rule: Read sensitive file untrusted
  enabled: false

# Or raise the priority threshold so it only fires on higher-severity matches
- rule: Read sensitive file untrusted
  priority: ERROR
  append: true
```

---

## 9. Falcosidekick with Multiple Outputs

Route alerts to Slack for warnings and PagerDuty for critical alerts simultaneously.
This is a Falcosidekick `config.yaml`, not a Falco rules file.

```yaml
# /etc/falcosidekick/config.yaml (or Helm values)
slack:
  webhookurl: https://hooks.slack.com/services/T00/B00/XXXX
  minimumpriority: warning
  messageformat: |
    *{{.Rule}}* ({{.Priority}})
    {{.Output}}
    Container: {{index .OutputFields "container.name"}}

pagerduty:
  routingkey: your-pagerduty-integration-key
  minimumpriority: critical

elasticsearch:
  hostport: https://elasticsearch.internal:9200
  index: falco-alerts
  type: _doc
  minimumpriority: notice
```

---

## 10. Custom Macro for Trusted Admin Processes

Create a reusable macro for processes that should be excluded from multiple rules,
reducing duplication.

```yaml
- list: trusted_admin_binaries
  items: [ansible, puppet, chef-client, salt-minion, cloud-init]

- macro: trusted_admin_process
  condition: (proc.name in (trusted_admin_binaries))

# Usage in rules:
# condition: >
#   sensitive_file_read and
#   not trusted_admin_process
```

---

## 11. Output Channels Configuration

Complete `falco.yaml` output section for a host that sends JSON to both syslog and
Falcosidekick.

```yaml
json_output: true
json_include_output_property: true
json_include_tags_property: true

stdout_output:
  enabled: false

syslog_output:
  enabled: true

file_output:
  enabled: true
  keep_alive: true
  filename: /var/log/falco/events.json

http_output:
  enabled: true
  url: http://localhost:2801

program_output:
  enabled: false

buffered_outputs: false
```
