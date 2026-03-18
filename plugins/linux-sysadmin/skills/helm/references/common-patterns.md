# Common Helm Patterns

Practical patterns for day-to-day Helm usage with Helm 3/4.

---

## 1. Installing with Custom Values + Inline Overrides

Combine a values file with `--set` for one-off tweaks. The `--set` flags take
precedence over the file, and rightmost flags win when repeated.

```bash
helm install myapp bitnami/nginx \
  -f values-production.yaml \
  --set replicaCount=5 \
  --set image.tag=1.25.3 \
  --namespace production \
  --create-namespace
```

For complex values (lists, nested objects), `--set-json` avoids escaping headaches:

```bash
helm install myapp ./mychart \
  --set-json 'tolerations=[{"key":"dedicated","operator":"Equal","value":"gpu","effect":"NoSchedule"}]'
```

---

## 2. Managing Multiple Environments

Maintain a base `values.yaml` with per-environment overrides. Helm merges them
in order; later files override earlier ones.

```
mychart/
├── values.yaml             # shared defaults
├── values-dev.yaml         # dev overrides (fewer replicas, debug logging)
├── values-staging.yaml     # staging overrides
└── values-prod.yaml        # production overrides (more replicas, resource limits)
```

```bash
# Dev
helm upgrade --install myapp ./mychart -f values.yaml -f values-dev.yaml -n dev

# Staging
helm upgrade --install myapp ./mychart -f values.yaml -f values-staging.yaml -n staging

# Production
helm upgrade --install myapp ./mychart \
  -f values.yaml -f values-prod.yaml \
  --rollback-on-failure --wait --timeout 10m \
  -n production
```

Tip: `helm upgrade --install` (upsert) works for both first install and subsequent
upgrades, simplifying CI/CD scripts.

---

## 3. Upgrading with Rollback-on-Failure and Wait

For production upgrades, always combine `--rollback-on-failure` (called `--atomic`
in Helm 3) with `--wait` so a failed upgrade automatically reverts to the
previous revision and Helm waits for all resources to be ready.

```bash
# Helm 4
helm upgrade myapp bitnami/nginx \
  -f values-prod.yaml \
  --rollback-on-failure \
  --wait \
  --timeout 5m

# Helm 3 (still supported)
helm upgrade myapp bitnami/nginx \
  -f values-prod.yaml \
  --atomic \
  --wait \
  --timeout 5m
```

Without these flags, a failed upgrade leaves the release in `failed` state,
requiring manual intervention with `helm rollback`.

---

## 4. Rolling Back a Failed Release

```bash
# Check revision history
helm history myapp

# Rollback to the previous revision
helm rollback myapp

# Rollback to a specific revision
helm rollback myapp 3

# Rollback with wait (blocks until rollback resources are ready)
helm rollback myapp 3 --wait --timeout 3m
```

If a release is stuck in `pending-install` or `pending-upgrade` (operator crashed
mid-apply), you may need to uninstall and reinstall:

```bash
helm uninstall myapp
helm install myapp bitnami/nginx -f values.yaml
```

---

## 5. Using OCI Registries for Charts

OCI support is stable and the recommended approach for private chart distribution.
No `helm repo add` needed; reference charts directly by digest or version.

```bash
# Authenticate to the registry
helm registry login ghcr.io -u myuser

# Package and push a chart
helm package mychart/
helm push mychart-1.0.0.tgz oci://ghcr.io/myorg/charts
# Note: push infers the chart name and tag from the .tgz metadata.
# Do NOT include the chart name in the OCI reference.

# Install from OCI
helm install myapp oci://ghcr.io/myorg/charts/mychart --version 1.0.0

# Pull for inspection
helm pull oci://ghcr.io/myorg/charts/mychart --version 1.0.0

# Install by digest for supply chain security (Helm 4)
helm install myapp oci://ghcr.io/myorg/charts/mychart@sha256:abc123...
```

Common registries: GHCR (`ghcr.io`), Docker Hub, AWS ECR, Google Artifact
Registry, Azure Container Registry.

---

## 6. Chart Dependencies

Declare dependencies in Chart.yaml and let Helm manage the subchart lifecycle.

```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    version: "12.5.0"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: redis
    version: "17.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
```

```bash
# Download dependencies into charts/ and generate Chart.lock
helm dependency update mychart/

# Rebuild from lockfile (exact versions, for CI reproducibility)
helm dependency build mychart/
```

Override subchart values by nesting under the dependency name in values.yaml:

```yaml
# values.yaml
postgresql:
  enabled: true
  auth:
    postgresPassword: "changeme"
    database: myapp

redis:
  enabled: false
```

Always commit `Chart.lock` for reproducible builds. The `charts/` directory
can be gitignored since `helm dependency build` reconstructs it.

---

## 7. Pre/Post Install Hooks

Hooks run Jobs or other resources at specific points in the release lifecycle.
Add annotations to any template to make it a hook.

```yaml
# templates/db-migrate-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "mychart.fullname" . }}-db-migrate
  annotations:
    # Run after templates are rendered but before resources are created
    "helm.sh/hook": pre-install,pre-upgrade
    # Lower weight runs first; default is 0
    "helm.sh/hook-weight": "-5"
    # Delete the previous Job before creating a new one
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
  backoffLimit: 1
```

Available hook types: `pre-install`, `post-install`, `pre-upgrade`, `post-upgrade`,
`pre-delete`, `post-delete`, `pre-rollback`, `post-rollback`, `test`.

Hook deletion policies: `before-hook-creation` (default), `hook-succeeded`,
`hook-failed`.

Hooks are NOT managed as part of the release. Without a deletion policy, hook
resources accumulate in the cluster and need manual cleanup.

---

## 8. Helmfile for Declarative Releases

Helmfile manages multiple Helm releases declaratively in a single file,
supporting environment-specific values, dependency ordering, and diff previews.

```yaml
# helmfile.yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: ingress-nginx
    url: https://kubernetes.github.io/ingress-nginx

releases:
  - name: ingress
    namespace: ingress-nginx
    chart: ingress-nginx/ingress-nginx
    version: 4.9.0
    values:
      - values/ingress-{{ .Environment.Name }}.yaml

  - name: myapp
    namespace: myapp
    chart: ./charts/myapp
    values:
      - values/myapp-defaults.yaml
      - values/myapp-{{ .Environment.Name }}.yaml
    set:
      - name: image.tag
        value: {{ requiredEnv "IMAGE_TAG" }}
    needs:
      - ingress-nginx/ingress    # wait for ingress to be deployed first

environments:
  dev:
  staging:
  production:
```

```bash
# Preview changes
helmfile -e production diff

# Apply all releases
helmfile -e production apply

# Sync (install or upgrade all releases)
helmfile -e production sync

# Destroy all releases
helmfile -e production destroy
```

Install: `brew install helmfile` or download from https://github.com/helmfile/helmfile/releases
