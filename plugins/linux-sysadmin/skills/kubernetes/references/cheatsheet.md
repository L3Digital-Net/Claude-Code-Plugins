# kubectl Cheat Sheet

Essential commands organized by category. All commands assume `kubectl` is configured
with a valid kubeconfig. Add `-n <namespace>` to scope to a specific namespace, or
`-A` / `--all-namespaces` to query across all namespaces.

---

## Cluster Management

```bash
# Cluster info and health
kubectl cluster-info                              # API server and CoreDNS endpoints
kubectl version                                   # Client and server versions
kubectl get componentstatuses                     # Scheduler, controller-manager, etcd (deprecated but functional)
kubectl api-resources                             # All resource types the cluster supports
kubectl api-versions                              # All API group/versions available

# Node management
kubectl get nodes -o wide                         # List nodes with IP, OS, kernel, runtime
kubectl describe node <node>                      # Detailed node info (capacity, allocatable, conditions, pods)
kubectl top nodes                                 # CPU/memory usage per node (requires metrics-server)
kubectl cordon <node>                             # Mark node unschedulable (existing pods stay)
kubectl uncordon <node>                           # Mark node schedulable again
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data   # Evict pods for maintenance
kubectl taint nodes <node> key=value:NoSchedule   # Add taint
kubectl taint nodes <node> key=value:NoSchedule-  # Remove taint (trailing dash)
kubectl label nodes <node> disktype=ssd           # Add/update label
kubectl label nodes <node> disktype-              # Remove label (trailing dash)
```

## Resource Inspection

```bash
# Listing resources
kubectl get pods                                  # Pods in current namespace
kubectl get pods -o wide                          # Include IP, node, nominated node
kubectl get pods -o yaml                          # Full YAML output
kubectl get pods -o json                          # Full JSON output
kubectl get pods --sort-by=.metadata.creationTimestamp  # Sort by creation time
kubectl get pods --selector=app=nginx             # Filter by label selector
kubectl get pods --field-selector=status.phase=Running  # Filter by field
kubectl get all                                   # Pods, services, deployments, replicasets in namespace
kubectl get deploy,svc,ing                        # Multiple resource types at once

# Detailed inspection
kubectl describe pod <pod>                        # Full details including events
kubectl describe deployment <deploy>              # Deployment details, conditions, events
kubectl describe node <node>                      # Node capacity, allocations, conditions

# Events (sorted by time, most useful for debugging)
kubectl events                                    # All events in namespace
kubectl get events --sort-by=.metadata.creationTimestamp   # Sorted chronologically
kubectl get events --field-selector involvedObject.name=<pod>  # Events for specific resource

# YAML/JSON schema exploration
kubectl explain pod                               # Top-level pod schema
kubectl explain pod.spec.containers               # Nested field docs
kubectl explain deployment.spec --recursive       # Full recursive schema
```

## Resource Creation and Modification

```bash
# Declarative (preferred — idempotent)
kubectl apply -f manifest.yaml                    # Create or update from file
kubectl apply -f ./manifests/                     # Apply all files in directory
kubectl apply -f https://example.com/manifest.yaml  # Apply from URL
kubectl apply -k ./overlays/production/           # Apply Kustomize overlay

# Imperative creation
kubectl create deployment nginx --image=nginx:1.27 --replicas=3
kubectl create service clusterip my-svc --tcp=80:8080
kubectl create configmap my-config --from-literal=key1=val1 --from-file=config.txt
kubectl create secret generic my-secret --from-literal=password=s3cr3t
kubectl create namespace staging
kubectl create job my-job --image=busybox:1.36 -- echo "done"
kubectl create cronjob my-cron --image=busybox:1.36 --schedule="*/5 * * * *" -- echo "tick"

# Modification
kubectl edit deployment <deploy>                  # Open in $EDITOR
kubectl patch deployment <deploy> -p '{"spec":{"replicas":5}}'  # Inline JSON patch
kubectl label pod <pod> env=production            # Add/update label
kubectl annotate pod <pod> description="my pod"   # Add/update annotation
kubectl set image deployment/<deploy> <container>=<image>:<tag>  # Update container image

# Scaling
kubectl scale deployment <deploy> --replicas=5    # Manual scale
kubectl autoscale deployment <deploy> --min=2 --max=10 --cpu-percent=80  # Create HPA

# Deletion
kubectl delete pod <pod>                          # Delete single resource
kubectl delete -f manifest.yaml                   # Delete resources defined in file
kubectl delete deployment <deploy>                # Delete deployment (cascades to pods)
kubectl delete pod <pod> --grace-period=0 --force  # Force immediate deletion (skip graceful shutdown)
kubectl delete pods --all -n <namespace>           # Delete all pods in namespace
```

## Debugging

```bash
# Logs
kubectl logs <pod>                                # Stdout from single-container pod
kubectl logs <pod> -c <container>                 # Specific container in multi-container pod
kubectl logs <pod> --previous                     # Logs from the previous (crashed) container instance
kubectl logs -f <pod>                             # Stream logs (follow)
kubectl logs -l app=nginx                         # Logs from all pods matching label
kubectl logs <pod> --tail=100                     # Last 100 lines
kubectl logs <pod> --since=1h                     # Logs from last hour

# Exec and attach
kubectl exec <pod> -- ls /app                     # Run single command
kubectl exec -it <pod> -- /bin/sh                 # Interactive shell
kubectl exec -it <pod> -c <container> -- /bin/sh  # Shell into specific container
kubectl attach <pod> -it                          # Attach to running process stdin/stdout

# Port forwarding
kubectl port-forward pod/<pod> 8080:80            # Forward localhost:8080 to pod port 80
kubectl port-forward svc/<svc> 8080:80            # Forward through a service
kubectl port-forward deploy/<deploy> 8080:80      # Forward to first pod of deployment

# Copying files
kubectl cp <pod>:/path/to/file ./local-file       # Copy from pod to local
kubectl cp ./local-file <pod>:/path/to/file       # Copy from local to pod
kubectl cp <pod>:/path/to/file ./local-file -c <container>  # Specify container

# Debug containers (ephemeral containers, stable since v1.25)
kubectl debug pod/<pod> -it --image=busybox:1.36          # Attach debug container
kubectl debug pod/<pod> -it --image=nicolaka/netshoot     # Network debugging toolkit
kubectl debug pod/<pod> --copy-to=debug-pod --share-processes  # Copy pod for debugging
kubectl debug node/<node> -it --image=busybox:1.36        # Debug a node (chroot /host)

# Resource usage
kubectl top pods                                  # CPU/memory per pod
kubectl top pods --containers                     # CPU/memory per container
kubectl top pods --sort-by=memory                 # Sort by memory usage
kubectl top nodes                                 # CPU/memory per node

# RBAC verification
kubectl auth can-i create deployments             # Check current user's permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa  # Check SA permissions
kubectl auth can-i '*' '*'                        # Check for cluster-admin
kubectl auth whoami                               # Show current authenticated identity
```

## Configuration (Contexts and Namespaces)

```bash
# Kubeconfig management
kubectl config view                               # Show merged kubeconfig
kubectl config view --minify                      # Show only current context
kubectl config get-contexts                       # List all contexts
kubectl config current-context                    # Show active context
kubectl config use-context <context>              # Switch context
kubectl config set-context --current --namespace=<ns>  # Set default namespace for context
kubectl config set-context <name> --cluster=<cluster> --user=<user>  # Create context
kubectl config delete-context <context>           # Remove context

# Namespace operations
kubectl get namespaces                            # List all namespaces
kubectl create namespace <ns>                     # Create namespace
kubectl delete namespace <ns>                     # Delete namespace (deletes ALL resources in it)
```

## Rollout Management

```bash
# Status and history
kubectl rollout status deployment/<deploy>        # Watch rollout progress
kubectl rollout history deployment/<deploy>       # List revision history
kubectl rollout history deployment/<deploy> --revision=3  # Details of specific revision

# Rollback
kubectl rollout undo deployment/<deploy>          # Rollback to previous revision
kubectl rollout undo deployment/<deploy> --to-revision=2  # Rollback to specific revision

# Pause/resume (for batching multiple changes)
kubectl rollout pause deployment/<deploy>         # Pause rollout
kubectl rollout resume deployment/<deploy>        # Resume rollout

# Restart (trigger rolling restart with same image)
kubectl rollout restart deployment/<deploy>       # Rolling restart all pods
```

## Useful Aliases and Shortcuts

```bash
# Common aliases
alias k=kubectl
alias kx='kubectl config use-context'
alias kn='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Output formatting
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
kubectl get pods -o name                          # Just resource names (pod/my-pod format)
kubectl get pods --no-headers                     # Skip header row

# Dry run and diff (preview changes before applying)
kubectl apply -f manifest.yaml --dry-run=client   # Validate locally
kubectl apply -f manifest.yaml --dry-run=server   # Validate against API server
kubectl diff -f manifest.yaml                     # Show diff between live and file
```
