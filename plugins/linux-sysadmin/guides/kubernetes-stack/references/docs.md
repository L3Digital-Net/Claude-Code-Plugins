# Kubernetes Stack Documentation

## Kubernetes

- Home: https://kubernetes.io/docs/home/
- Concepts: https://kubernetes.io/docs/concepts/
- Components: https://kubernetes.io/docs/concepts/overview/components/
- Cluster Architecture: https://kubernetes.io/docs/concepts/architecture/
- kubectl reference: https://kubernetes.io/docs/reference/kubectl/
- kubectl quick reference: https://kubernetes.io/docs/reference/kubectl/quick-reference/
- Ports and Protocols: https://kubernetes.io/docs/reference/networking/ports-and-protocols/
- RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Persistent Volumes: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- Secrets: https://kubernetes.io/docs/concepts/configuration/secret/
- Probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- HPA: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- Troubleshooting: https://kubernetes.io/docs/tasks/debug/debug-application/

## K3s

- Home: https://docs.k3s.io/
- Quick Start: https://docs.k3s.io/quick-start
- Installation: https://docs.k3s.io/installation
- Configuration: https://docs.k3s.io/installation/configuration
- Requirements: https://docs.k3s.io/installation/requirements
- HA with embedded etcd: https://docs.k3s.io/datastore/ha-embedded
- Cluster access: https://docs.k3s.io/cluster-access

## kubeadm

- Creating a cluster: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
- HA clusters: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
- Installing kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- Upgrading clusters: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

## Helm

- Docs home: https://helm.sh/docs/
- Installing Helm: https://helm.sh/docs/intro/install/
- Using Helm: https://helm.sh/docs/intro/using_helm/
- Chart development guide: https://helm.sh/docs/topics/charts/
- Chart template guide: https://helm.sh/docs/chart_template_guide/
- Best practices: https://helm.sh/docs/chart_best_practices/
- OCI registries: https://helm.sh/docs/topics/registries/
- Dependency management: https://helm.sh/docs/helm/helm_dependency/
- Artifact Hub (chart discovery): https://artifacthub.io/
- Helmfile: https://helmfile.readthedocs.io/
- GitHub: https://github.com/helm/helm

## ArgoCD

- Getting started: https://argo-cd.readthedocs.io/en/stable/getting_started/
- Core concepts: https://argo-cd.readthedocs.io/en/stable/core_concepts/
- Architecture: https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/
- Declarative setup: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/
- App-of-apps pattern: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/
- ApplicationSets: https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/
- Sync options: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/
- Auto-sync policy: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
- Helm support: https://argo-cd.readthedocs.io/en/stable/user-guide/helm/
- Notifications: https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/
- Metrics: https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/
- HA deployment: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/
- Disaster recovery: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/
- RBAC: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/
- Ingress configuration: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/
- GitHub: https://github.com/argoproj/argo-cd
- Argo Helm charts: https://github.com/argoproj/argo-helm

## Container Registries

- Docker Registry (distribution): https://distribution.github.io/distribution/
- Docker Registry deployment: https://distribution.github.io/distribution/about/deploying/
- Docker Registry configuration: https://distribution.github.io/distribution/about/configuration/
- Harbor (enterprise registry): https://goharbor.io/docs/
- Harbor installation: https://goharbor.io/docs/latest/install-config/
- Kubernetes imagePullSecrets: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
- containerd registry configuration: https://github.com/containerd/containerd/blob/main/docs/hosts.md
- OCI Image Spec: https://github.com/opencontainers/image-spec

## etcd (Kubernetes Context)

- Operating etcd for Kubernetes: https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- HA etcd with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/
- etcd documentation: https://etcd.io/docs/v3.5/
- Disaster recovery: https://etcd.io/docs/v3.5/op-guide/recovery/
- Maintenance (compaction, defrag): https://etcd.io/docs/v3.5/op-guide/maintenance/
- GitHub: https://github.com/etcd-io/etcd

## Supplementary Tools

- k9s (terminal UI): https://k9scli.io/
- kubectx + kubens: https://github.com/ahmetb/kubectx
- Kustomize: https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/
- Lens (IDE): https://k8slens.dev/
- stern (multi-pod log tailing): https://github.com/stern/stern
- chart-testing (ct): https://github.com/helm/chart-testing
- Helm Diff plugin: https://github.com/databus23/helm-diff
