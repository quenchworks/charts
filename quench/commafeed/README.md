# CommaFeed

[CommaFeed](https://www.commafeed.com), a self-hosted RSS reader inspired by Google Reader: categories, keyboard
shortcuts, a REST API and Fever-compatible clients. It runs on the bundled PostgreSQL. The image is QuenchWorks' build
of the upstream Quarkus distribution with vulnerable libraries swapped, CVE-gated, signed with cosign and pinned by
digest.

## Install

```sh
helm install feeds oci://ghcr.io/quenchworks/charts/commafeed
kubectl port-forward svc/feeds-commafeed 8082:8082   # create the admin account on the first visit
```

## Values

| Key | Default | Meaning |
|---|---|---|
| `allowRegistrations` | `false` | Let anyone create an account. |
| `publicUrl` | `""` | Public URL for password-recovery mails. |
| `settings` | `{}` | Extra `QUARKUS_*` / `COMMAFEED_*` settings. |
| `secret.existingSecret` | `""` | Secret with `session-key` (Quarkus session encryption key), else generated and kept. |
| `postgresql.enabled` / `externalDatabase.*` | bundled | PostgreSQL. |
| `tls.enabled` | `false` | Quarkus serves HTTPS on 8082 (existing Secret, cert-manager, or a Helm-made CA). |
| `javaOpts` | `""` | `JAVA_TOOL_OPTIONS`. |

CommaFeed blocks feeds on local addresses by default (SSRF protection); set
`settings.COMMAFEED_HTTP_CLIENT_BLOCK_LOCAL_ADDRESSES: "false"` to read feeds served inside the cluster.
