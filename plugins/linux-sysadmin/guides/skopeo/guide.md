# skopeo

> **Based on:** skopeo 1.22.0 | **Updated:** 2026-03-27

## Identity
- **Binary**: `/usr/bin/skopeo`
- **Config**: `~/.config/containers/policy.json` (image trust policy), `~/.config/containers/registries.conf` (registry config)
- **System config**: `/etc/containers/policy.json`, `/etc/containers/registries.conf`
- **Auth**: `~/.config/containers/auth.json` (registry credentials; shared with Podman/Buildah)
- **Install**: `apt install skopeo` / `dnf install skopeo`

## Quick Start

```bash
skopeo inspect docker://docker.io/library/nginx:latest    # inspect remote image
skopeo copy docker://nginx:latest dir:/tmp/nginx-image     # download image to directory
skopeo list-tags docker://docker.io/library/nginx          # list all tags
skopeo login docker.io                                      # authenticate to registry
```

## What It Does

Skopeo inspects and copies container images between registries, local directories, and archives — without a running daemon. It completes the Podman (run) / Buildah (build) / Skopeo (transport) triad.

## Key Operations

| Task | Command |
|------|---------|
| Inspect remote image | `skopeo inspect docker://registry.example.com/myapp:v1` |
| Inspect with raw manifest | `skopeo inspect --raw docker://nginx:latest` |
| Copy between registries | `skopeo copy docker://source/image:tag docker://dest/image:tag` |
| Copy to local directory | `skopeo copy docker://nginx:latest dir:/tmp/nginx` |
| Copy to OCI layout | `skopeo copy docker://nginx:latest oci:/tmp/nginx-oci:latest` |
| Copy to Docker archive | `skopeo copy docker://nginx:latest docker-archive:/tmp/nginx.tar` |
| Import from archive | `skopeo copy docker-archive:/tmp/nginx.tar docker://myregistry/nginx:latest` |
| Sync entire repository | `skopeo sync --src docker --dest dir docker.io/library/nginx /tmp/nginx-mirror` |
| List tags | `skopeo list-tags docker://docker.io/library/nginx` |
| Delete image from registry | `skopeo delete docker://myregistry/myapp:old-tag` |
| Login to registry | `skopeo login docker.io` |
| Logout from registry | `skopeo logout docker.io` |
| Copy all architectures | `skopeo copy --all docker://nginx:latest docker://myregistry/nginx:latest` |

## Transport Types

| Transport | Format | Example |
|-----------|--------|---------|
| `docker://` | Remote registry (Docker Hub, GHCR, etc.) | `docker://ghcr.io/org/image:tag` |
| `dir:` | Local directory (one file per layer) | `dir:/tmp/myimage` |
| `oci:` | OCI image layout | `oci:/tmp/myimage:tag` |
| `docker-archive:` | Docker `save` format tarball | `docker-archive:/tmp/image.tar` |
| `oci-archive:` | OCI tarball | `oci-archive:/tmp/image.tar` |
| `containers-storage:` | Local Podman/CRI-O storage | `containers-storage:localhost/myimage:tag` |
| `docker-daemon:` | Local Docker daemon storage | `docker-daemon:myimage:tag` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "unauthorized: authentication required" | Not logged in to registry | `skopeo login <registry>` |
| "manifest unknown" | Tag doesn't exist | `skopeo list-tags docker://<image>` to see available tags |
| "certificate signed by unknown authority" | Self-signed registry cert | Use `--tls-verify=false` (testing) or add CA to system trust store |
| Copy fails with multi-arch image | Trying to copy manifest list without `--all` | Add `--all` to copy all architectures |
| Delete not supported | Registry doesn't allow deletion | Enable deletion in registry config; some hosted registries don't support it |

## Pain Points

- **No daemon required.** Unlike `docker pull`, skopeo doesn't need a running Docker or Podman daemon. It talks directly to registries via HTTPS. This makes it ideal for CI pipelines, air-gapped transfers, and scripts.

- **Shared auth with Podman/Buildah.** Credentials from `skopeo login` are stored in `~/.config/containers/auth.json` and shared with Podman and Buildah. Login once, use everywhere.

- **Mirror registries with `sync`.** `skopeo sync` can mirror entire repositories or specific tags between registries or to local directories. Essential for air-gapped environments.

- **Image inspection without pulling.** `skopeo inspect` reads metadata from the registry without downloading layers. Fast way to check labels, creation date, architecture, and layer count.

## See Also

- **podman** — runs containers; skopeo complements it for image transport
- **buildah** — builds images; skopeo complements it for image distribution
- **container-registry** — private registry; skopeo copies images to/from registries
- **trivy** — vulnerability scanning; scan images skopeo has downloaded

## References
See `references/` for:
- `docs.md` — official documentation links
