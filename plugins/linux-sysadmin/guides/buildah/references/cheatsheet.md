# Buildah Cheatsheet

## Build from Dockerfile / Containerfile

```bash
buildah build -t myapp:latest .                       # build from Containerfile or Dockerfile
buildah build -f Dockerfile.prod -t myapp:prod .      # specify file
buildah build --format docker -t myapp:latest .       # produce Docker format image
buildah build --format oci -t myapp:latest .          # produce OCI format (default)
buildah build --no-cache -t myapp:latest .            # ignore layer cache
buildah build --layers -t myapp:latest .              # cache individual layers (default)
buildah build --squash -t myapp:latest .              # squash all layers into one
buildah build --target builder -t myapp:builder .     # build up to named stage
buildah build --build-arg VERSION=1.2.3 -t myapp .   # pass build argument
buildah build --platform linux/amd64 -t myapp .       # target specific platform
buildah build -v /host/path:/container/path:Z .       # bind mount during build
```

## Step-by-Step Image Building

```bash
# Create a working container from a base image
ctr=$(buildah from alpine:3.20)
ctr=$(buildah from scratch)                # start from empty image
ctr=$(buildah from docker.io/library/ubuntu:24.04)

# Run commands inside the container
buildah run $ctr -- apk add --no-cache curl jq
buildah run $ctr -- pip install flask
buildah run $ctr -- sh -c 'echo "hello" > /tmp/test'

# Copy files from host into container
buildah copy $ctr ./app /opt/app
buildah copy $ctr requirements.txt /app/requirements.txt

# Add files (supports URLs and tar auto-extraction)
buildah add $ctr https://example.com/file.tar.gz /opt/

# Configure image metadata
buildah config --entrypoint '["python3", "/app/main.py"]' $ctr
buildah config --cmd '["--port", "8080"]' $ctr
buildah config --env APP_ENV=production $ctr
buildah config --workingdir /app $ctr
buildah config --port 8080 $ctr
buildah config --user appuser $ctr
buildah config --label version=1.0.0 $ctr
buildah config --label maintainer="team@example.com" $ctr
buildah config --stop-signal SIGTERM $ctr
buildah config --healthcheck-cmd 'CMD curl -f http://localhost:8080/health' $ctr

# Commit the container to an image
buildah commit $ctr myapp:latest
buildah commit --format docker $ctr myapp:latest      # Docker format
buildah commit --squash $ctr myapp:latest              # squash layers
buildah commit --rm $ctr myapp:latest                  # remove container after commit
```

## Mount / Unmount (Direct Filesystem Access)

```bash
# Mount container filesystem to host (returns mount path)
mnt=$(buildah mount $ctr)
echo $mnt                                    # e.g., /var/lib/containers/storage/overlay/.../merged

# Manipulate files directly on host filesystem
cp myconfig.conf $mnt/etc/myapp/config.conf
echo "nameserver 8.8.8.8" > $mnt/etc/resolv.conf

# Unmount
buildah unmount $ctr
buildah unmount --all                        # unmount all containers
```

## Registry Operations

```bash
# Login to a registry
buildah login docker.io
buildah login -u myuser registry.example.com
buildah login --get-login docker.io          # show current user

# Push image to registry
buildah push myapp:latest docker://docker.io/myuser/myapp:latest
buildah push myapp:latest docker://registry.example.com/myapp:latest
buildah push myapp:latest docker://ghcr.io/myorg/myapp:latest

# Push to local OCI layout directory
buildah push myapp:latest oci:/tmp/myapp-oci:latest

# Push to local Docker archive
buildah push myapp:latest docker-archive:/tmp/myapp.tar:myapp:latest

# Pull image
buildah pull alpine:3.20
buildah pull docker.io/library/nginx:latest

# Logout
buildah logout docker.io
buildah logout --all
```

## Image and Container Management

```bash
# List images
buildah images
buildah images --json                        # JSON output
buildah images --filter dangling=true        # untagged images

# List working containers
buildah containers
buildah containers --json

# Inspect image or container
buildah inspect myapp:latest                 # image metadata
buildah inspect $ctr                         # container metadata
buildah inspect --type image myapp:latest
buildah inspect --format '{{.OCIv1.Config.Cmd}}' myapp:latest

# Tag image
buildah tag myapp:latest myapp:v1.0.0
buildah tag myapp:latest registry.example.com/myapp:v1.0.0

# Remove container
buildah rm $ctr
buildah rm --all                             # remove all containers

# Remove image
buildah rmi myapp:latest
buildah rmi --all                            # remove all images
buildah rmi --all --force                    # force remove (even if in use)
buildah rmi --prune                          # remove dangling images

# Prune build cache
buildah prune

# System info
buildah info                                 # storage driver, registries, etc.
buildah version
```

## Rootless Operation

```bash
# Prerequisites: user must have subuid/subgid entries
grep $USER /etc/subuid                       # should show range
grep $USER /etc/subgid                       # should show range

# Add subuid/subgid if missing
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER

# Verify storage driver (should be overlay or fuse-overlayfs, not vfs)
buildah info | grep -i driver

# Install fuse-overlayfs if needed (faster than vfs)
sudo apt install fuse-overlayfs

# Rootless storage config (optional, to override defaults)
# ~/.config/containers/storage.conf
# [storage]
# driver = "overlay"
# [storage.options.overlay]
# mount_program = "/usr/bin/fuse-overlayfs"

# All buildah commands work identically as non-root
buildah build -t myapp:latest .              # no sudo needed
```

## Multi-Stage Build Example

```dockerfile
# Containerfile
FROM golang:1.23 AS builder
WORKDIR /src
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app

FROM scratch
COPY --from=builder /app /app
ENTRYPOINT ["/app"]
```

```bash
# Build multi-stage
buildah build -t myapp:latest .

# Build only the builder stage
buildah build --target builder -t myapp:builder .
```
