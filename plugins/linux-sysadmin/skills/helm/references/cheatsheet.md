# Helm Cheatsheet

## Repository Management

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update                     # refresh all repo indexes
helm repo list                       # show configured repos
helm repo remove bitnami             # remove a repo
helm search repo nginx               # search local repos
helm search repo nginx --versions    # show all available versions
helm search hub prometheus           # search Artifact Hub
```

## Install / Upgrade / Rollback / Uninstall

```bash
# Install
helm install myapp bitnami/nginx
helm install myapp bitnami/nginx -f custom-values.yaml
helm install myapp bitnami/nginx --set service.type=ClusterIP --set replicaCount=3
helm install myapp bitnami/nginx --namespace production --create-namespace
helm install myapp bitnami/nginx --version 15.4.0         # pin chart version
helm install myapp ./my-local-chart                        # from local directory
helm install myapp oci://registry.example.com/charts/nginx --version 1.0.0  # from OCI

# Upgrade
helm upgrade myapp bitnami/nginx -f custom-values.yaml
helm upgrade myapp bitnami/nginx --rollback-on-failure --wait --timeout 5m
helm upgrade --install myapp bitnami/nginx                 # install if not exists
helm upgrade myapp bitnami/nginx --reuse-values --set image.tag=1.2.3  # keep existing values

# Rollback
helm rollback myapp                    # rollback to previous revision
helm rollback myapp 3                  # rollback to specific revision

# Uninstall
helm uninstall myapp
helm uninstall myapp --namespace production
helm uninstall myapp --keep-history    # retain release history
```

## Inspect Releases

```bash
helm list                              # releases in current namespace
helm list -A                           # releases in all namespaces
helm list --filter 'myapp'             # filter by name pattern
helm list --deployed                   # only deployed releases
helm list --failed                     # only failed releases
helm status myapp                      # release status and notes
helm history myapp                     # revision history
helm get values myapp                  # user-supplied values
helm get values myapp --all            # all values (including defaults)
helm get manifest myapp                # rendered Kubernetes manifests
helm get hooks myapp                   # hook manifests
helm get notes myapp                   # NOTES.txt output
helm get all myapp                     # everything above combined
```

## Inspect Charts (before installing)

```bash
helm show chart bitnami/nginx          # Chart.yaml contents
helm show values bitnami/nginx         # default values.yaml
helm show readme bitnami/nginx         # README
helm show all bitnami/nginx            # all of the above
helm show values bitnami/nginx > custom-values.yaml  # save defaults to customize
```

## Chart Development

```bash
helm create mychart                    # scaffold a new chart
helm lint mychart/                     # validate chart structure
helm lint mychart/ --strict            # strict mode (warnings = errors)
helm template myrelease mychart/       # render templates locally
helm template myrelease mychart/ -f values-prod.yaml --debug  # with overrides
helm install myrelease mychart/ --dry-run --debug  # server-side dry run
helm package mychart/                  # create .tgz archive
helm package mychart/ --version 1.2.3  # override version in archive
```

## Dependencies

```bash
helm dependency list mychart/          # show declared dependencies
helm dependency update mychart/        # download deps, generate Chart.lock
helm dependency build mychart/         # rebuild from Chart.lock (exact versions)
```

## OCI Registries

```bash
helm registry login registry.example.com -u user
helm registry logout registry.example.com
helm push mychart-1.0.0.tgz oci://registry.example.com/charts
helm pull oci://registry.example.com/charts/mychart --version 1.0.0
helm install myapp oci://registry.example.com/charts/mychart --version 1.0.0
```

## Plugins

```bash
helm plugin list                       # installed plugins
helm plugin install https://github.com/databus23/helm-diff   # install by URL
helm plugin update diff                # update a plugin
helm plugin uninstall diff             # remove a plugin
helm diff upgrade myapp bitnami/nginx -f values.yaml  # example: diff plugin usage
```

## Environment and Debugging

```bash
helm env                               # show all Helm environment variables
helm version                           # client version
helm get values myapp -o json          # output as JSON
helm get values myapp -o yaml          # output as YAML
HELM_DEBUG=1 helm install ...          # verbose debug output
```
