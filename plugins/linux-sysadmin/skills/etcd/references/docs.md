# etcd Documentation

## Official -- etcd.io

- Main documentation (v3.5): https://etcd.io/docs/v3.5/
- Main documentation (v3.6): https://etcd.io/docs/v3.6/
- Install guide: https://etcd.io/docs/v3.5/install/
- Configuration options: https://etcd.io/docs/v3.5/op-guide/configuration/
- FAQ: https://etcd.io/docs/v3.5/faq/

## Clustering and Operations

- Clustering guide: https://etcd.io/docs/v3.5/op-guide/clustering/
- Runtime reconfiguration (member add/remove): https://etcd.io/docs/v3.5/op-guide/runtime-configuration/
- Hardware recommendations: https://etcd.io/docs/v3.5/op-guide/hardware/
- Supported platforms: https://etcd.io/docs/v3.5/op-guide/supported-platform/
- Maintenance (compaction, defrag, quota): https://etcd.io/docs/v3.5/op-guide/maintenance/
- Disaster recovery: https://etcd.io/docs/v3.5/op-guide/recovery/
- Performance tuning: https://etcd.io/docs/v3.5/tuning/

## Security

- Transport security (TLS): https://etcd.io/docs/v3.5/op-guide/security/
- Authentication and RBAC: https://etcd.io/docs/v3.5/op-guide/authentication/rbac/

## Tutorials

- Set up a demo cluster: https://etcd.io/docs/v3.5/tutorials/how-to-setup-cluster/
- Member management: https://etcd.io/docs/v3.5/tutorials/how-to-deal-with-membership/
- Interacting with etcd (v3 API): https://etcd.io/docs/v3.5/dev-guide/interacting_v3/

## etcdctl and etcdutl

- etcdctl README: https://github.com/etcd-io/etcd/blob/main/etcdctl/README.md
- etcdutl README: https://github.com/etcd-io/etcd/blob/main/etcdutl/README.md

## Kubernetes Integration

- Operating etcd for Kubernetes: https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- HA etcd with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/
- etcd cluster recovery (CNCF blog): https://www.cncf.io/blog/2025/05/08/the-kubernetes-surgeons-handbook-precision-recovery-from-etcd-snapshots/

## Version and Release Info

- v3.6.0 announcement: https://etcd.io/blog/2025/announcing-etcd-3.6/
- Large DB size debugging: https://etcd.io/blog/2023/how_to_debug_large_db_size_issue/

## GitHub

- Source repository: https://github.com/etcd-io/etcd
- Releases: https://github.com/etcd-io/etcd/releases
- Changelog (v3.5): https://github.com/etcd-io/etcd/blob/main/CHANGELOG/CHANGELOG-3.5.md
- Changelog (v3.6): https://github.com/etcd-io/etcd/blob/main/CHANGELOG/CHANGELOG-3.6.md

## CNCF

- Project page: https://www.cncf.io/projects/etcd/

## CLI Help

```bash
etcd --help
etcdctl --help
etcdctl put --help
etcdctl get --help
etcdctl del --help
etcdctl watch --help
etcdctl lease --help
etcdctl member --help
etcdctl snapshot --help
etcdctl endpoint --help
etcdctl alarm --help
etcdctl auth --help
etcdctl user --help
etcdctl role --help
etcdctl compaction --help
etcdctl defrag --help
etcdutl --help
etcdutl snapshot restore --help
etcdutl defrag --help
```
