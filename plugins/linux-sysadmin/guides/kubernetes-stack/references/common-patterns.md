# Kubernetes Stack Common Patterns

Each section is a standalone, copy-paste-ready reference. Adjust hostnames, IPs,
and credentials to match your environment.

---

## 1. k3s Cluster Setup

### Single server + workers

```bash
# --- Server node (control plane) ---
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --tls-san k8s.example.com \
    --node-name server-01

# Save the node token
cat /var/lib/rancher/k3s/server/node-token

# Copy kubeconfig for remote kubectl access
cat /etc/rancher/k3s/k3s.yaml
# Replace "127.0.0.1" with the server's external IP or DNS name

# --- Worker nodes ---
curl -sfL https://get.k3s.io | K3S_URL=https://server-ip:6443 \
    K3S_TOKEN=<node-token> sh -s - \
    --node-name worker-01

curl -sfL https://get.k3s.io | K3S_URL=https://server-ip:6443 \
    K3S_TOKEN=<node-token> sh -s - \
    --node-name worker-02

# Verify
kubectl get nodes -o wide
```

### HA k3s with embedded etcd (3 server nodes)

```bash
# First server (initializes the embedded etcd cluster)
curl -sfL https://get.k3s.io | sh -s - server \
    --cluster-init \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --tls-san k8s.example.com \
    --node-name server-01

# Second and third servers join the cluster
curl -sfL https://get.k3s.io | K3S_URL=https://server-01:6443 \
    K3S_TOKEN=<node-token> sh -s - server \
    --disable traefik \
    --node-name server-02

curl -sfL https://get.k3s.io | K3S_URL=https://server-01:6443 \
    K3S_TOKEN=<node-token> sh -s - server \
    --disable traefik \
    --node-name server-03

# Workers join any server
curl -sfL https://get.k3s.io | K3S_URL=https://server-01:6443 \
    K3S_TOKEN=<node-token> sh -s - \
    --node-name worker-01
```

### Uninstall k3s

```bash
# Server
/usr/local/bin/k3s-uninstall.sh

# Agent (worker)
/usr/local/bin/k3s-agent-uninstall.sh
```

---

## 2. Helm Chart Deployment

### Install a chart from a public repository

```bash
# Add a repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search for charts
helm search repo bitnami/postgresql

# Install with default values
helm install my-postgres bitnami/postgresql \
    --namespace databases --create-namespace

# Install with custom values
helm install my-postgres bitnami/postgresql \
    --namespace databases --create-namespace \
    -f values-postgres.yaml

# View rendered manifests before installing (dry run)
helm install my-postgres bitnami/postgresql \
    --namespace databases --create-namespace \
    --dry-run --debug
```

### values-postgres.yaml example

```yaml
auth:
  postgresPassword: "CHANGE_ME"
  database: myapp
  username: myapp_user
  password: "CHANGE_ME"

primary:
  persistence:
    size: 20Gi
    storageClass: local-path
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

### Manage releases

```bash
# List installed releases
helm list -A

# Upgrade a release
helm upgrade my-postgres bitnami/postgresql \
    --namespace databases -f values-postgres.yaml

# Rollback to a previous revision
helm rollback my-postgres 1 --namespace databases

# View release history
helm history my-postgres --namespace databases

# Uninstall
helm uninstall my-postgres --namespace databases
```

### Create a custom chart

```bash
helm create my-app
# Creates:
#   my-app/
#   ├── Chart.yaml
#   ├── values.yaml
#   ├── charts/           (dependencies)
#   └── templates/
#       ├── deployment.yaml
#       ├── service.yaml
#       ├── ingress.yaml
#       ├── hpa.yaml
#       ├── serviceaccount.yaml
#       ├── _helpers.tpl
#       ├── NOTES.txt
#       └── tests/

# Lint the chart
helm lint my-app/

# Package for distribution
helm package my-app/

# Push to an OCI registry
helm push my-app-0.1.0.tgz oci://registry.example.com/charts
```

---

## 3. ArgoCD App-of-Apps Pattern

The app-of-apps pattern uses a single "root" ArgoCD Application that manages other
Application resources. This bootstraps an entire platform from one Git path.

### Repository structure

```
gitops-repo/
├── apps/                        # Root app-of-apps
│   ├── Chart.yaml               # Minimal Helm chart
│   ├── values.yaml              # Enable/disable child apps
│   └── templates/
│       ├── cert-manager.yaml    # ArgoCD Application for cert-manager
│       ├── ingress-nginx.yaml   # ArgoCD Application for ingress-nginx
│       ├── monitoring.yaml      # ArgoCD Application for prometheus stack
│       └── my-app.yaml          # ArgoCD Application for your app
├── charts/
│   └── my-app/                  # Your custom Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── environments/
    ├── staging/
    │   └── values.yaml          # Staging overrides
    └── production/
        └── values.yaml          # Production overrides
```

### Root app-of-apps Chart.yaml

```yaml
apiVersion: v2
name: platform-apps
description: Root application that manages all platform components
version: 1.0.0
```

### Child application template example

```yaml
# apps/templates/my-app.yaml
{{- if .Values.myApp.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ .Values.gitRepo }}
    targetRevision: {{ .Values.targetRevision }}
    path: charts/my-app
    helm:
      valueFiles:
        - ../../environments/{{ .Values.environment }}/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
{{- end }}
```

### Root app values.yaml

```yaml
gitRepo: https://github.com/your-org/gitops-repo.git
targetRevision: main
environment: production

myApp:
  enabled: true
certManager:
  enabled: true
ingressNginx:
  enabled: true
monitoring:
  enabled: true
```

### Deploy the root app

```bash
# Create the root application via CLI
argocd app create platform \
    --repo https://github.com/your-org/gitops-repo.git \
    --path apps \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace argocd \
    --sync-policy automated \
    --auto-prune \
    --self-heal \
    --helm-set environment=production

# Or apply as a Kubernetes manifest
kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-repo.git
    targetRevision: main
    path: apps
    helm:
      parameters:
        - name: environment
          value: production
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Verify — all child apps should appear
argocd app list
```

---

## 4. Private Container Registry with imagePullSecret

### Deploy a Docker Registry in-cluster

```yaml
# registry.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
        - name: registry
          image: registry:2
          ports:
            - containerPort: 5000
          volumeMounts:
            - name: registry-data
              mountPath: /var/lib/registry
          env:
            - name: REGISTRY_STORAGE_DELETE_ENABLED
              value: "true"
      volumes:
        - name: registry-data
          persistentVolumeClaim:
            claimName: registry-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  selector:
    app: registry
  ports:
    - port: 5000
      targetPort: 5000
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: registry
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
```

```bash
kubectl create namespace registry
kubectl apply -f registry.yaml
```

### Create an imagePullSecret

```bash
# Create the secret in the target namespace
kubectl create secret docker-registry regcred \
    --docker-server=registry.registry.svc.cluster.local:5000 \
    --docker-username=myuser \
    --docker-password=mypassword \
    --namespace my-app

# Reference it in a deployment
# spec.template.spec.imagePullSecrets:
#   - name: regcred

# Or attach it to the default service account for the namespace
kubectl patch serviceaccount default -n my-app \
    -p '{"imagePullSecrets": [{"name": "regcred"}]}'
```

### Configure k3s to trust a private registry (no imagePullSecret needed)

```yaml
# /etc/rancher/k3s/registries.yaml
mirrors:
  registry.example.com:
    endpoint:
      - "https://registry.example.com"
configs:
  "registry.example.com":
    auth:
      username: myuser
      password: mypassword
    tls:
      insecure_skip_verify: false
      ca_file: /etc/ssl/certs/registry-ca.crt
```

```bash
# Restart k3s to pick up the config
sudo systemctl restart k3s
```

### Push an image to the private registry

```bash
# Build and tag
docker build -t registry.example.com/myapp:v1.0.0 .

# Push
docker push registry.example.com/myapp:v1.0.0

# Use in a Kubernetes deployment
# image: registry.example.com/myapp:v1.0.0
```

---

## 5. etcd Backup CronJob

For k3s with embedded etcd, use k3s's built-in snapshot mechanism. For kubeadm or
standalone etcd, use etcdctl.

### k3s automatic snapshots (enabled by default)

```bash
# k3s takes snapshots every 12 hours and retains 5 by default
# Override in /etc/rancher/k3s/config.yaml:
cat <<'EOF' | sudo tee /etc/rancher/k3s/config.yaml
etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 10
etcd-snapshot-dir: /var/lib/rancher/k3s/server/db/snapshots
EOF

sudo systemctl restart k3s

# Manual snapshot
k3s etcd-snapshot save --name manual-$(date +%Y%m%d-%H%M)

# List snapshots
k3s etcd-snapshot list

# Restore from snapshot (DESTRUCTIVE — stops the cluster)
k3s server --cluster-reset --cluster-reset-restore-path=/path/to/snapshot.db
```

### kubeadm etcd backup CronJob (runs outside Kubernetes)

```bash
# /etc/cron.d/etcd-backup
0 */4 * * * root \
    ETCDCTL_API=3 etcdctl snapshot save /backups/etcd-$(date +\%Y\%m\%d-\%H\%M).db \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    && find /backups -name 'etcd-*.db' -mtime +7 -delete \
    2>&1 | logger -t etcd-backup
```

### Restore from etcd snapshot (kubeadm)

```bash
# Stop the API server and etcd (move static pod manifests)
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# Restore the snapshot
ETCDCTL_API=3 etcdutl snapshot restore /backups/etcd-20260314-0800.db \
    --data-dir=/var/lib/etcd-restored \
    --name=server-01 \
    --initial-cluster=server-01=https://10.0.1.1:2380 \
    --initial-advertise-peer-urls=https://10.0.1.1:2380

# Replace the etcd data directory
sudo rm -rf /var/lib/etcd
sudo mv /var/lib/etcd-restored /var/lib/etcd
sudo chown -R etcd:etcd /var/lib/etcd

# Restore the static pod manifests
sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

# Wait for the API server to come back
kubectl get nodes
```

---

## 6. Ingress with cert-manager and Let's Encrypt

### Install ingress-nginx and cert-manager via Helm

```bash
# ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.publishService.enabled=true

# cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace \
    --set crds.enabled=true
```

### ClusterIssuer for Let's Encrypt

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

### Ingress with automatic TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: my-app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

---

## 7. ArgoCD Webhook Configuration

Webhooks provide instant sync triggers instead of the default 3-minute polling interval.

### GitHub webhook

1. In the ArgoCD server, the webhook endpoint is: `https://argocd.example.com/api/webhook`
2. In your GitHub repository settings, add a webhook:
   - Payload URL: `https://argocd.example.com/api/webhook`
   - Content type: `application/json`
   - Secret: (configure in ArgoCD's `argocd-secret`)
   - Events: "Just the push event"

```bash
# Set the webhook secret in ArgoCD
kubectl -n argocd edit secret argocd-secret
# Add: webhook.github.secret: <base64-encoded-secret>
```

### ArgoCD notifications (Slack example)

```bash
# Install the notifications catalog
kubectl apply -n argocd -f \
    https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml

# Configure Slack token
kubectl -n argocd edit secret argocd-notifications-secret
# Add: slack-token: <base64-encoded-bot-token>

# Configure the notification service
kubectl -n argocd edit configmap argocd-notifications-cm
```

```yaml
# In argocd-notifications-cm
data:
  service.slack: |
    token: $slack-token
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} sync succeeded.
      Revision: {{.app.status.sync.revision}}
    slack:
      attachments: |
        [{
          "color": "#18be52",
          "title": "{{.app.metadata.name}} synced",
          "text": "Revision: {{.app.status.sync.revision}}"
        }]
```

Annotate applications to subscribe to notifications:

```bash
kubectl -n argocd annotate application my-app \
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack=my-channel
```
