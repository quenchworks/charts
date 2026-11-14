# Quenchworks automation-stack

[n8n](https://github.com/n8n-io/n8n) 2.40.7 in queue mode, in one install: the main instance takes
the editor, the REST API, webhooks and schedules and puts executions on a Valkey queue; workers
take them from the queue and run them; both share PostgreSQL. All images are QuenchWorks
(nonroot, CVE-gated at build, pinned by digest, cosign-signed). The stack generates the database
password, the queue password and n8n's encryption key at install and keeps them across upgrades.

## Install

```bash
helm install automation oci://ghcr.io/quenchworks/charts/automation-stack -n automation --create-namespace \
  --set n8n.n8n.host=n8n.example.com --set n8n.n8n.webhookUrl=https://n8n.example.com/
```

The first visit to the editor creates the owner account.

## Values

| Key | Default | Notes |
|---|---|---|
| `worker.replicas` | `2` | workers running executions; scale out here |
| `worker.concurrency` | `10` | executions each worker runs at once |
| `worker.image.digest` | pinned | keep equal to the n8n subchart's image |
| `n8n.*` | | passes to the [n8n chart](../n8n): `n8n.host`, `n8n.webhookUrl`, `ingress`, `tls`, `persistence` |
| `postgresql.*` | | passes to the [postgresql chart](../postgresql) |
| `valkey.*` | | passes to the [valkey chart](../valkey) |

## Notes

- Back up the Secret `automation-secrets`. Its `encryption-key` decrypts every credential
  stored in n8n; Helm keeps the Secret on uninstall.
- One stack per namespace: the Secret and the PostgreSQL and Valkey Services
  (`automation-postgresql`, `automation-valkey`) have fixed names, because the subcharts are
  wired from plain values.
- Editor runs go to the workers too (`OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS`).
- Workers and the main instance wait up to 2 minutes for Valkey at startup instead of exiting
  after n8n's default 10 seconds.
