# Keycloak Documentation

## Official -- keycloak.org

- Main documentation: https://www.keycloak.org/documentation
- Guides index: https://www.keycloak.org/guides
- Server administration guide: https://www.keycloak.org/docs/latest/server_admin/index.html
- All configuration options reference: https://www.keycloak.org/server/all-config
- Release notes: https://www.keycloak.org/docs/latest/release_notes/index.html
- Downloads: https://www.keycloak.org/downloads

## Getting Started

- Docker quick start: https://www.keycloak.org/getting-started/getting-started-docker
- OpenJDK / bare-metal quick start: https://www.keycloak.org/getting-started/getting-started-zip
- Kubernetes quick start: https://www.keycloak.org/getting-started/getting-started-kube

## Server Configuration

- Configuring Keycloak (keycloak.conf, env vars, CLI): https://www.keycloak.org/server/configuration
- Production configuration checklist: https://www.keycloak.org/server/configuration-production
- Database configuration: https://www.keycloak.org/server/db
- Hostname configuration (v2): https://www.keycloak.org/server/hostname
- Configuring TLS: https://www.keycloak.org/server/enabletls
- Configuring a reverse proxy: https://www.keycloak.org/server/reverseproxy
- Running in a container: https://www.keycloak.org/server/containers
- Configuring caching and clustering: https://www.keycloak.org/server/caching
- Configuring logging: https://www.keycloak.org/server/logging
- Enabling and disabling features: https://www.keycloak.org/server/features
- Bootstrap admin and recovery: https://www.keycloak.org/server/bootstrap-admin-recovery

## Observability

- Health checks: https://www.keycloak.org/observability/health
- Management interface (port 9000): https://www.keycloak.org/server/management-interface
- Metrics (Prometheus): https://www.keycloak.org/observability/metrics

## Identity Providers

- Identity brokering overview: https://www.keycloak.org/docs/latest/server_admin/index.html#_identity_broker
- OpenID Connect v1.0 IdP: https://www.keycloak.org/docs/latest/server_admin/index.html#_identity_broker_oidc
- SAML v2.0 IdP: https://www.keycloak.org/docs/latest/server_admin/index.html#saml-v2-0-identity-providers
- Social identity providers (GitHub, Google, Facebook, etc.): https://www.keycloak.org/docs/latest/server_admin/index.html#social-identity-providers

## Themes and Customization

- Working with themes: https://www.keycloak.org/ui-customization/themes
- Server developer guide (theme development): https://www.keycloak.org/docs/latest/server_development/
- Custom REST endpoints (SPIs): https://www.keycloak.org/docs/latest/server_development/index.html#_providers

## Admin CLI (kcadm.sh)

- Admin CLI reference (Red Hat docs, applies to upstream): https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/22.0/html/server_administration_guide/admin_cli
- Admin REST API: https://www.keycloak.org/docs/latest/server_admin/index.html#admin-rest-api

## Upgrading

- Upgrading guide: https://www.keycloak.org/docs/latest/upgrading/index.html
- Migration from WildFly to Quarkus: https://www.keycloak.org/migration/migrating-to-quarkus

## GitHub

- Source repository: https://github.com/keycloak/keycloak
- Releases: https://github.com/keycloak/keycloak/releases
- Container images: https://quay.io/repository/keycloak/keycloak
- Docker Hub mirror: https://hub.docker.com/r/keycloak/keycloak

## Red Hat Build (downstream)

- Red Hat build of Keycloak docs: https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/
- Server configuration guide (26.0): https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.0/html/server_configuration_guide/

## Community

- Keycloak blog: https://www.keycloak.org/blog
- GitHub discussions: https://github.com/keycloak/keycloak/discussions
- CNCF project page: https://www.cncf.io/projects/keycloak/

## CLI Help

```bash
bin/kc.sh --help
bin/kc.sh start --help
bin/kc.sh start-dev --help
bin/kc.sh build --help
bin/kc.sh show-config --help
bin/kc.sh export --help
bin/kc.sh import --help
bin/kc.sh bootstrap-admin --help
bin/kcadm.sh --help
bin/kcadm.sh config credentials --help
bin/kcadm.sh create --help
bin/kcadm.sh get --help
bin/kcadm.sh update --help
bin/kcadm.sh delete --help
bin/kcadm.sh set-password --help
bin/kcadm.sh add-roles --help
bin/kcadm.sh get-roles --help
```
