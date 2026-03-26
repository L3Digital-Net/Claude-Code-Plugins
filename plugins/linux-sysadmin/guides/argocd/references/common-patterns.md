# Argo CD Common Patterns

Each section is a complete, copy-paste-ready reference. All YAML examples use
the `argoproj.io/v1alpha1` API version.

---

## 1. Application from Git Repository (Plain YAML)

The simplest Argo CD application: deploy Kubernetes manifests from a Git repo directory.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/my-app.git
    targetRevision: HEAD
    path: k8s/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```bash
# Or create via CLI
argocd app create my-app \
  --repo https://github.com/example/my-app.git \
  --path k8s/manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

---

## 2. Application from Helm Chart

Deploy a Helm chart with custom values.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: "15.4.0"
    helm:
      releaseName: nginx-prod
      valuesObject:
        replicaCount: 3
        service:
          type: ClusterIP
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: web
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=true
```

```bash
# CLI equivalent
argocd app create nginx \
  --repo https://charts.bitnami.com/bitnami \
  --helm-chart nginx \
  --revision 15.4.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace web \
  --helm-set replicaCount=3 \
  --helm-set service.type=ClusterIP
```

---

## 3. Auto-Sync with Self-Heal and Prune

Full automated sync policy that keeps the cluster in sync with Git, reverts
manual changes, and removes resources deleted from Git.

```yaml
spec:
  syncPolicy:
    automated:
      # Sync when Git changes are detected
      enabled: true
      # Delete resources removed from Git
      prune: true
      # Revert manual cluster changes to match Git
      selfHeal: true
      # Allow syncing to an empty resource set (dangerous; protects against
      # accidental deletion of all manifests)
      allowEmpty: false
    retry:
      # Retry sync when a new revision is detected
      refresh: true
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
```

---

## 4. App-of-Apps Pattern

A parent Application whose Git path contains child Application manifests.
Changes to the parent repo automatically create/update/delete child apps.

Parent application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/platform.git
    targetRevision: HEAD
    path: apps          # Directory containing child Application YAMLs
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd   # Child apps are created in the argocd namespace
  syncPolicy:
    automated:
      prune: true       # Deleting a child app YAML removes it from the cluster
      selfHeal: true
```

Child application (in `apps/monitoring.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/monitoring.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 5. ApplicationSet with Git Generator

Generate one Application per directory in a Git repo. Each directory represents
an environment or microservice.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/example/microservices.git
        revision: HEAD
        directories:
          - path: services/*      # Each subdirectory becomes an app
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/microservices.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

---

## 6. ApplicationSet with Cluster Generator

Deploy the same application to all registered clusters.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: monitoring-everywhere
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            env: production
  template:
    metadata:
      name: 'monitoring-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/monitoring.git
        targetRevision: HEAD
        path: manifests
      destination:
        server: '{{server}}'
        namespace: monitoring
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## 7. ApplicationSet with Matrix Generator

Combine two generators (e.g., clusters x environments) to create a cross-product
of applications.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-apps
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - git:
              repoURL: https://github.com/example/apps.git
              revision: HEAD
              directories:
                - path: apps/*
          - clusters:
              selector:
                matchLabels:
                  env: production
  template:
    metadata:
      name: '{{path.basename}}-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/example/apps.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: '{{server}}'
        namespace: '{{path.basename}}'
```

---

## 8. RBAC Configuration

Define who can do what in Argo CD. Policies go in the `argocd-rbac-cm` ConfigMap.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default policy for authenticated users (restrict for production)
  policy.default: role:readonly

  policy.csv: |
    # Developers: can sync and view apps in the 'dev' project
    p, role:developer, applications, get, dev/*, allow
    p, role:developer, applications, sync, dev/*, allow

    # Operators: full app control in all projects
    p, role:operator, applications, *, */*, allow
    p, role:operator, clusters, get, *, allow
    p, role:operator, repositories, *, *, allow

    # Map GitHub team to role
    g, my-org:developers, role:developer
    g, my-org:platform-team, role:operator

    # Map individual user to role
    g, alice@example.com, role:operator
```

---

## 9. SSO with OIDC (Generic)

Configure SSO in the `argocd-cm` ConfigMap. Works with any OIDC provider
(Keycloak, Auth0, Okta, etc.).

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com

  oidc.config: |
    name: Keycloak
    issuer: https://keycloak.example.com/realms/argocd
    clientID: argocd
    clientSecret: $oidc.keycloak.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
      - groups
```

The `clientSecret` references a key in the `argocd-secret` Secret:
```bash
kubectl -n argocd patch secret argocd-secret -p \
  '{"stringData": {"oidc.keycloak.clientSecret": "<your-client-secret>"}}'
```

---

## 10. Disaster Recovery

Export and import Argo CD applications for backup or migration.

```bash
# Export all applications as YAML
argocd app list -o yaml > argocd-apps-backup.yaml

# Export specific application
argocd app get my-app -o yaml > my-app-backup.yaml

# Export all via kubectl (includes ApplicationSets, AppProjects)
kubectl get applications,applicationsets,appprojects -n argocd -o yaml > full-backup.yaml

# Restore applications
kubectl apply -f argocd-apps-backup.yaml

# Force refresh after restore
argocd app get my-app --hard-refresh
argocd app sync my-app
```
