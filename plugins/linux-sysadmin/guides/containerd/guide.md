# containerd

> **Based on:** containerd 2.2.2 | **Updated:** 2026-03-27

## Identity
- **Unit**: `containerd.service`
- **Binary**: `/usr/bin/containerd`
- **CLI**: `ctr` (low-level), `nerdctl` (Docker-compatible CLI, separate install)
- **Config**: `/etc/containerd/config.toml`
- **Data dir**: `/var/lib/containerd/`
- **Socket**: `/run/containerd/containerd.sock`
- **Logs**: `journalctl -u containerd`
- **Install**: `apt install containerd` / `dnf install containerd.io` (Docker repo) / bundled with Docker and K3s

## Quick Start

```bash
sudo apt install containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl enable --now containerd
sudo ctr images pull docker.io/library/nginx:latest
sudo ctr run --rm docker.io/library/nginx:latest test-nginx
```

## What It Does

containerd is the industry-standard container runtime. It manages the complete container lifecycle: image pull/push, container execution, storage, and networking. Docker uses containerd under the hood. Kubernetes uses it directly via CRI.

```
User-facing tools
├── Docker CLI → dockerd → containerd
├── Podman (uses its own runtime)
├── nerdctl → containerd (Docker-compatible CLI)
├── Kubernetes (CRI) → containerd
└── ctr → containerd (low-level debug tool)
         ↓
    containerd
    ├── Image management (pull, push, store)
    ├── Container lifecycle (create, start, stop, delete)
    ├── Snapshotter (filesystem layers)
    └── runc (OCI runtime — actually runs the container)
```

## Key Operations

| Task | Command |
|------|---------|
| Pull image | `sudo ctr images pull docker.io/library/nginx:latest` |
| List images | `sudo ctr images list` |
| Remove image | `sudo ctr images remove docker.io/library/nginx:latest` |
| Run container | `sudo ctr run --rm docker.io/library/nginx:latest mycontainer` |
| Run detached | `sudo ctr run -d docker.io/library/nginx:latest mycontainer` |
| List running containers | `sudo ctr containers list` |
| List tasks (processes) | `sudo ctr tasks list` |
| Kill container | `sudo ctr tasks kill mycontainer` |
| Delete container | `sudo ctr containers delete mycontainer` |
| Show containerd info | `sudo ctr version` |
| List namespaces | `sudo ctr namespaces list` |
| Use Kubernetes namespace | `sudo ctr -n k8s.io containers list` |
| Generate default config | `containerd config default` |
| Check runtime plugins | `sudo ctr plugins list` |

## Namespaces

containerd uses namespaces to isolate workloads:

| Namespace | Used By |
|-----------|---------|
| `default` | `ctr` commands (default) |
| `k8s.io` | Kubernetes/CRI |
| `moby` | Docker |

To see Docker or Kubernetes containers via `ctr`, specify the namespace: `ctr -n moby containers list`.

## Expected Ports
- No listening ports by default. containerd communicates via Unix socket (`/run/containerd/containerd.sock`).

## Health Checks

1. `systemctl is-active containerd` — service running
2. `sudo ctr version` — client and server version displayed
3. `sudo ctr plugins list | grep -c "ok"` — plugins loaded
4. `ls /run/containerd/containerd.sock` — socket exists

## Configuration

Generate and customize the default config:

```bash
containerd config default | sudo tee /etc/containerd/config.toml
```

Key settings in `config.toml`:

```toml
[plugins."io.containerd.grpc.v1.cri"]
  # Enable CRI for Kubernetes
  sandbox_image = "registry.k8s.io/pause:3.9"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true    # Required for Kubernetes with systemd cgroup driver

[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = ["https://registry-1.docker.io"]
```

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "failed to create containerd task" | runc not installed or wrong version | Install `runc`; verify with `runc --version` |
| Kubernetes pods stuck in `ContainerCreating` | CRI config issue or `SystemdCgroup` mismatch | Set `SystemdCgroup = true` in config.toml; restart containerd |
| "failed to pull image" | Registry unreachable or auth required | Check DNS, firewall; configure registry auth in config.toml |
| High disk usage | Old images and snapshots not cleaned up | `sudo ctr images list` and remove unused; `sudo ctr content prune` |
| containerd vs Docker conflict | Both installed with different configs | Use one or the other; Docker embeds its own containerd |
| Permission denied on socket | User not root and no socket proxy | `ctr` requires root; use `nerdctl` with rootless containerd for unprivileged access |

## Pain Points

- **`ctr` is not user-friendly.** It's a low-level debug tool, not a Docker replacement. For a Docker-like experience with containerd, install `nerdctl` (contaiNERD ctl) which provides `docker`-compatible commands.

- **Docker embeds containerd.** If Docker is installed, it runs its own containerd instance. You don't need to install containerd separately for Docker. Only install standalone containerd for Kubernetes (CRI) or nerdctl usage.

- **`SystemdCgroup = true` is critical for Kubernetes.** Kubernetes with systemd expects containerd to use systemd cgroups. Mismatching cgroup drivers (cgroupfs vs systemd) causes kubelet errors and pod failures.

- **Namespaces isolate everything.** Docker containers (`moby` namespace), Kubernetes pods (`k8s.io`), and `ctr` commands (`default`) are invisible to each other. Always specify `-n <namespace>` when debugging.

- **Image garbage collection.** containerd doesn't auto-clean unused images. In Kubernetes, kubelet handles GC. For standalone use, periodically run `ctr images list` and remove what you don't need.

## See Also

- **docker** — Docker uses containerd as its runtime; Docker adds image building, compose, and CLI UX
- **podman** — alternative container runtime; doesn't use containerd
- **kubernetes** — uses containerd via CRI for pod execution
- **k3s** — embeds containerd; no separate installation needed
- **buildah** — builds OCI images; can push to containerd storage

## References
See `references/` for:
- `docs.md` — official documentation links
