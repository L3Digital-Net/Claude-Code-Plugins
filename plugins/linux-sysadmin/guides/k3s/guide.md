# k3s

> **Based on:** k3s 1.35.1+k3s1 | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/local/bin/k3s` (single binary containing server, agent, kubectl, crictl)
- **Unit**: `k3s.service` (server) or `k3s-agent.service` (worker node)
- **Config**: `/etc/rancher/k3s/config.yaml` (server/agent config)
- **Kubeconfig**: `/etc/rancher/k3s/k3s.yaml` (auto-generated; copy to `~/.kube/config`)
- **Data dir**: `/var/lib/rancher/k3s/` (containers, images, state)
- **Manifests**: `/var/lib/rancher/k3s/server/manifests/` (auto-deploy YAML files dropped here)
- **Logs**: `journalctl -u k3s`
- **Default registry**: containerd (built-in; Docker not required)
- **Install**: `curl -sfL https://get.k3s.io | sh -`

## Quick Start

```bash
# Single-node server (includes kubectl)
curl -sfL https://get.k3s.io | sh -

# Verify
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A

# Use kubectl directly (copy kubeconfig)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
kubectl get nodes
```

## Architecture

```
k3s server (single binary)
├── API server
├── Controller manager
├── Scheduler
├── Embedded etcd (or SQLite for single-node)
├── containerd (container runtime)
├── Flannel (CNI networking)
├── CoreDNS
├── Traefik (ingress controller)
├── ServiceLB (load balancer)
└── Local Path Provisioner (storage)

k3s agent (worker nodes)
├── kubelet
├── containerd
└── kube-proxy (as iptables rules)
```

K3s bundles everything a full Kubernetes cluster needs into a single ~70MB binary.

## Key Operations

| Task | Command |
|------|---------|
| Check node status | `kubectl get nodes` |
| List all pods | `kubectl get pods -A` |
| Deploy from YAML | `kubectl apply -f deployment.yaml` |
| Auto-deploy (drop-in) | Copy YAML to `/var/lib/rancher/k3s/server/manifests/` |
| Get kubeconfig | `sudo cat /etc/rancher/k3s/k3s.yaml` |
| Add worker node | On worker: `curl -sfL https://get.k3s.io \| K3S_URL=https://<server>:6443 K3S_TOKEN=<token> sh -` |
| Get join token | `sudo cat /var/lib/rancher/k3s/server/node-token` |
| Use embedded kubectl | `sudo k3s kubectl <command>` |
| Use embedded crictl | `sudo k3s crictl ps` |
| Check service status | `systemctl status k3s` |
| View logs | `journalctl -u k3s -f` |
| Uninstall server | `/usr/local/bin/k3s-uninstall.sh` |
| Uninstall agent | `/usr/local/bin/k3s-agent-uninstall.sh` |
| Disable component | Add `--disable traefik` to config or install command |

## Expected Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 6443 | TCP | Kubernetes API server |
| 8472 | UDP | Flannel VXLAN (CNI) |
| 10250 | TCP | kubelet metrics |
| 2379-2380 | TCP | Embedded etcd (HA mode) |
| 80, 443 | TCP | Traefik ingress (if enabled) |

## Health Checks

1. `systemctl is-active k3s` — service running
2. `kubectl get nodes` — nodes show `Ready`
3. `kubectl get pods -n kube-system` — system pods running
4. `kubectl get cs` — component status healthy

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Node shows `NotReady` | Networking or containerd issue | `journalctl -u k3s -f`; check DNS, firewall between nodes |
| Can't reach API server | Firewall blocking 6443 or service down | Open 6443; `systemctl status k3s` |
| Agent can't join | Wrong token or server URL | Verify token from `/var/lib/rancher/k3s/server/node-token`; check URL scheme (`https://`) |
| Pods stuck in `Pending` | No schedulable nodes or resource limits | `kubectl describe pod <pod>` for events; check node capacity |
| Traefik conflicts with existing reverse proxy | Both trying to bind port 80/443 | `--disable traefik` in k3s config; use your own ingress |
| Storage issues | Local Path Provisioner using wrong path | Configure `/var/lib/rancher/k3s/storage` or use different StorageClass |

## Pain Points

- **K3s vs full K8s.** K3s removes alpha features, legacy APIs, and cloud-provider-specific code. It uses SQLite instead of etcd for single-node (etcd for HA). Everything else is standard Kubernetes — same API, same kubectl, same manifests.

- **Disable what you don't need.** K3s bundles Traefik, ServiceLB, and Local Path Provisioner. If you have your own ingress or load balancer, disable the built-in ones: `--disable traefik --disable servicelb`.

- **Auto-deploy manifests.** Drop any Kubernetes YAML into `/var/lib/rancher/k3s/server/manifests/` and k3s applies it automatically. This is a simple GitOps alternative for small deployments.

- **Private registries.** Configure in `/etc/rancher/k3s/registries.yaml` with mirror and auth settings. This file is containerd-specific, not Docker config format.

- **Kubeconfig permissions.** `/etc/rancher/k3s/k3s.yaml` is owned by root. Copy it to `~/.kube/config` and chown it for non-root kubectl usage. The server address defaults to `127.0.0.1` — change it to the server's actual IP for remote access.

## See Also

- **kubernetes** — full Kubernetes; k3s is a certified lightweight distribution
- **helm** — Kubernetes package manager; works identically with k3s
- **containerd** — container runtime; k3s embeds containerd
- **traefik** — k3s bundles Traefik as default ingress controller

## References
See `references/` for:
- `docs.md` — official documentation links
