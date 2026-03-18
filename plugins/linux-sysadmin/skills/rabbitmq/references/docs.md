# RabbitMQ Documentation

## Official

- Documentation home: https://www.rabbitmq.com/docs
- Installation (Debian/Ubuntu): https://www.rabbitmq.com/docs/install-debian
- Installation (RHEL/CentOS): https://www.rabbitmq.com/docs/install-rpm
- Docker images: https://hub.docker.com/_/rabbitmq/
- Configuration reference: https://www.rabbitmq.com/docs/configure
- Networking and ports: https://www.rabbitmq.com/docs/networking
- TLS/SSL guide: https://www.rabbitmq.com/docs/ssl
- Clustering guide: https://www.rabbitmq.com/docs/clustering
- Network partitions: https://www.rabbitmq.com/docs/partitions
- Quorum queues: https://www.rabbitmq.com/docs/quorum-queues
- Streams: https://www.rabbitmq.com/docs/streams
- Classic queues: https://www.rabbitmq.com/docs/classic-queues
- Exchanges and routing: https://www.rabbitmq.com/tutorials/amqp-concepts
- Virtual hosts: https://www.rabbitmq.com/docs/vhosts
- Access control (users, permissions): https://www.rabbitmq.com/docs/access-control
- Shovel plugin: https://www.rabbitmq.com/docs/shovel
- Federation plugin: https://www.rabbitmq.com/docs/federation
- Management plugin (UI + HTTP API): https://www.rabbitmq.com/docs/management
- Monitoring guide: https://www.rabbitmq.com/docs/monitoring
- Prometheus integration: https://www.rabbitmq.com/docs/prometheus
- Memory and disk alarms: https://www.rabbitmq.com/docs/alarms
- Flow control: https://www.rabbitmq.com/docs/flow-control
- Publisher confirms: https://www.rabbitmq.com/docs/confirms
- Consumer acknowledgments: https://www.rabbitmq.com/docs/confirms#consumer-acknowledgements
- Dead lettering: https://www.rabbitmq.com/docs/dlx
- TTL (message and queue): https://www.rabbitmq.com/docs/ttl
- Lazy queues: https://www.rabbitmq.com/docs/lazy-queues
- Policies and operator policies: https://www.rabbitmq.com/docs/parameters#policies
- Upgrading: https://www.rabbitmq.com/docs/upgrade
- Blue-green deployment upgrades: https://www.rabbitmq.com/docs/blue-green-upgrade
- Troubleshooting: https://www.rabbitmq.com/docs/troubleshooting
- Production checklist: https://www.rabbitmq.com/docs/production-checklist

## CLI References

- rabbitmqctl man page: https://www.rabbitmq.com/docs/man/rabbitmqctl.8
- rabbitmq-diagnostics man page: https://www.rabbitmq.com/docs/man/rabbitmq-diagnostics.8
- rabbitmq-plugins man page: https://www.rabbitmq.com/docs/man/rabbitmq-plugins.8
- rabbitmq-queues man page: https://www.rabbitmq.com/docs/man/rabbitmq-queues.8
- rabbitmq-upgrade man page: https://www.rabbitmq.com/docs/man/rabbitmq-upgrade.8
- All manual pages index: https://www.rabbitmq.com/docs/manpages

## Tools

- Management UI: `http://<host>:15672/` (enable with `rabbitmq-plugins enable rabbitmq_management`)
- HTTP API reference: `http://<host>:15672/api/` (self-documenting when management plugin is active)
- rabbitmqadmin CLI (bundled with management plugin): `http://<host>:15672/cli/rabbitmqadmin`

## Client Libraries

- Official client libraries: https://www.rabbitmq.com/client-libraries
- Pika (Python): https://pika.readthedocs.io/
- amqplib (Node.js): https://amqp-node.github.io/amqplib/
- Bunny (Ruby): https://github.com/ruby-amqp/bunny
- Spring AMQP (Java): https://spring.io/projects/spring-amqp

## Tutorials

- Official tutorials (all languages): https://www.rabbitmq.com/tutorials
- AMQP 0-9-1 concepts: https://www.rabbitmq.com/tutorials/amqp-concepts
- Migrating mirrored queues to quorum queues: https://www.rabbitmq.com/blog/2023/03/02/quorum-queues-migration

## Community

- GitHub repository: https://github.com/rabbitmq/rabbitmq-server
- Community Discord: https://www.rabbitmq.com/discord
- Mailing list: https://groups.google.com/g/rabbitmq-users
- CloudAMQP blog (practical guides): https://www.cloudamqp.com/blog/
