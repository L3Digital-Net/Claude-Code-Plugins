# Kubernetes Common Patterns

Practical YAML examples for everyday workloads. All examples use `apiVersion` values
current as of Kubernetes v1.35. Apply with `kubectl apply -f <file>.yaml`.

---

## 1. Basic Deployment + Service

A stateless web app with 3 replicas exposed internally via ClusterIP.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
```

To expose externally via NodePort, change `type: NodePort` and optionally add
`nodePort: 30080` under ports.

---

## 2. ConfigMap and Secret Usage

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Simple key-value pairs (injected as env vars)
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"

  # File-like key (mounted as a file in a volume)
  app.conf: |
    [server]
    port = 8080
    workers = 4
    debug = false
```

### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
# Values must be base64-encoded: echo -n 'value' | base64
data:
  username: YWRtaW4=
  password: cDRzc3cwcmQ=
```

### Pod using both

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    # From ConfigMap
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: LOG_LEVEL
    # From Secret
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    # Mount ConfigMap as file
    - name: config-volume
      mountPath: /etc/app
      readOnly: true
    # Mount Secret as file
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
      - key: app.conf
        path: app.conf
  - name: secret-volume
    secret:
      secretName: db-credentials
```

---

## 3. Resource Requests and Limits

Every production container should have these set. Without `requests`, the scheduler
has no data for placement. Without `limits`, a runaway container can starve the node.

```yaml
containers:
- name: api
  image: myapi:2.0
  resources:
    requests:
      # Guaranteed minimum — scheduler uses these for placement decisions.
      # 250m = 0.25 CPU cores; 256Mi = 256 mebibytes RAM.
      cpu: 250m
      memory: 256Mi
    limits:
      # Hard ceiling — container is throttled (CPU) or OOMKilled (memory)
      # if it exceeds these.
      cpu: 500m
      memory: 512Mi
```

QoS classes based on requests/limits:
- **Guaranteed**: requests == limits for both CPU and memory (highest priority, last to be evicted)
- **Burstable**: requests < limits (evicted after BestEffort pods)
- **BestEffort**: no requests or limits set (first to be evicted under pressure)

---

## 4. Liveness and Readiness Probes

```yaml
containers:
- name: web
  image: myapp:1.0
  ports:
  - containerPort: 8080
  # Readiness: controls whether the pod receives traffic from Services.
  # Failing readiness removes the pod from endpoints but does NOT restart it.
  readinessProbe:
    httpGet:
      path: /healthz
      port: 8080
    initialDelaySeconds: 5
    periodSeconds: 10
    failureThreshold: 3
    successThreshold: 1
  # Liveness: detects deadlocks or unrecoverable states.
  # Failing liveness RESTARTS the container. Use a higher threshold than
  # readiness to avoid unnecessary restart loops.
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8080
    initialDelaySeconds: 15
    periodSeconds: 20
    failureThreshold: 5
  # Startup: for slow-starting apps. Liveness and readiness probes are
  # disabled until the startup probe succeeds.
  startupProbe:
    httpGet:
      path: /healthz
      port: 8080
    periodSeconds: 5
    failureThreshold: 30     # 30 * 5s = 150s max startup time
```

Probe types available: `httpGet`, `tcpSocket`, `exec`, `grpc`.

```yaml
# TCP probe (just checks port is open)
livenessProbe:
  tcpSocket:
    port: 3306

# Exec probe (runs command; exit 0 = healthy)
readinessProbe:
  exec:
    command:
    - cat
    - /tmp/ready

# gRPC probe (calls gRPC health check protocol)
livenessProbe:
  grpc:
    port: 50051
```

---

## 5. Horizontal Pod Autoscaler

Requires metrics-server installed and resource `requests` defined on containers.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60               # Scale down max 10% per minute
    scaleUp:
      stabilizationWindowSeconds: 0      # Scale up immediately
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15               # Can double pod count per 15s
```

The algorithm: `desiredReplicas = ceil(currentReplicas * (currentMetric / targetMetric))`.
A 10% tolerance prevents flapping (no action if ratio is between 0.9 and 1.1).

---

## 6. Namespace-Scoped RBAC (Role + RoleBinding)

Grant a service account read-only access to pods and services in a specific namespace.

```yaml
# ServiceAccount for the application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: production
---
# Role: namespace-scoped permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
# RoleBinding: binds Role to ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: production
```

For cluster-wide permissions, use `ClusterRole` + `ClusterRoleBinding` (no namespace field).
Avoid wildcards (`*`) in verbs or resources; they grant access to future resource types too.

Verify permissions: `kubectl auth can-i get pods --as=system:serviceaccount:production:app-reader`

---

## 7. CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "0 2 * * *"                  # Daily at 02:00 UTC
  concurrencyPolicy: Forbid             # Skip if previous run still active
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  startingDeadlineSeconds: 600           # Fail if can't start within 10 min of scheduled time
  jobTemplate:
    spec:
      backoffLimit: 2                    # Retry failed pods up to 2 times
      activeDeadlineSeconds: 3600        # Kill job if it runs longer than 1 hour
      template:
        spec:
          restartPolicy: OnFailure       # Required: Never or OnFailure for Jobs
          containers:
          - name: backup
            image: postgres:16-alpine
            command:
            - /bin/sh
            - -c
            - pg_dump -h $DB_HOST -U $DB_USER $DB_NAME | gzip > /backups/$(date +%Y%m%d).sql.gz
            env:
            - name: DB_HOST
              value: "postgres-svc"
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: username
            - name: DB_NAME
              value: "myapp"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: password
            volumeMounts:
            - name: backup-storage
              mountPath: /backups
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
```

Concurrency policies: `Allow` (default, multiple jobs can run), `Forbid` (skip if
previous still running), `Replace` (kill previous, start new).

---

## 8. Init Containers

Init containers run to completion before app containers start. Use them for
setup tasks: waiting for dependencies, running migrations, populating config.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
spec:
  initContainers:
  # Init container 1: wait for a dependency service to be reachable
  - name: wait-for-db
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      until nc -z postgres-svc 5432; do
        echo "Waiting for PostgreSQL..."
        sleep 2
      done
      echo "PostgreSQL is ready"

  # Init container 2: run database migrations
  - name: run-migrations
    image: myapp:1.0
    command: ["python", "manage.py", "migrate"]
    env:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: url

  containers:
  - name: app
    image: myapp:1.0
    ports:
    - containerPort: 8080
```

Init containers run sequentially in order. If any init container fails, Kubernetes
restarts the pod (subject to `restartPolicy`). The app containers don't start until
all init containers succeed.

---

## 9. Node Affinity and Anti-Affinity

### Node Affinity (schedule pods to specific nodes)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-workload
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gpu-workload
  template:
    metadata:
      labels:
        app: gpu-workload
    spec:
      affinity:
        nodeAffinity:
          # Hard requirement: pod MUST be scheduled on a node with this label
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: gpu-type
                operator: In
                values:
                - nvidia-a100
                - nvidia-h100
          # Soft preference: prefer nodes with SSD, but not required
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 50
            preference:
              matchExpressions:
              - key: disk-type
                operator: In
                values:
                - ssd
      containers:
      - name: trainer
        image: ml-trainer:latest
```

### Pod Anti-Affinity (spread replicas across nodes)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      affinity:
        podAntiAffinity:
          # Hard: never place two web-app pods on the same node
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - web-app
            topologyKey: kubernetes.io/hostname
      containers:
      - name: web
        image: nginx:1.27-alpine
```

`topologyKey` options: `kubernetes.io/hostname` (per-node), `topology.kubernetes.io/zone`
(per-AZ), `topology.kubernetes.io/region` (per-region).

---

## 10. PersistentVolumeClaim (Dynamic Provisioning)

Most clusters have a default StorageClass that provisions volumes automatically.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  # Omit storageClassName to use the cluster default.
  # Specify explicitly if you need a specific storage class:
  # storageClassName: fast-ssd
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-storage
spec:
  replicas: 1                            # RWO volumes can only attach to one node
  selector:
    matchLabels:
      app: app-with-storage
  template:
    metadata:
      labels:
        app: app-with-storage
    spec:
      containers:
      - name: app
        image: myapp:1.0
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: data-pvc
```

For StatefulSets, use `volumeClaimTemplates` instead of standalone PVCs; each replica
gets its own PVC automatically:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:16-alpine
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: pgdata
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
```

---

## 11. Ingress with TLS

Requires an Ingress controller installed in the cluster (nginx-ingress, Traefik, etc.).

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    # Annotations are controller-specific. These are for nginx-ingress:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls-secret          # Must contain tls.crt and tls.key
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

Create the TLS secret: `kubectl create secret tls app-tls-secret --cert=tls.crt --key=tls.key`

The Ingress API is frozen. For new deployments, consider Gateway API instead.
