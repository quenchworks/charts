# Mastodon

[Mastodon](https://joinmastodon.org) is a federated social network server. This chart runs
its three processes on QuenchWorks images: web (puma), sidekiq and the streaming server.
All three are nonroot, run on a read-only root filesystem, have 0 fixable CVEs, are
cosign-signed and are pinned by digest.

## Install

```sh
helm install mastodon oci://ghcr.io/quenchworks/charts/mastodon \
  --set localDomain=social.example.org
```

`localDomain` is written into every account and post, so pick it before the first start.
Mastodon expects HTTPS on that domain: turn on `ingress` with `tls`, or terminate TLS in
front of the Services. The ingress sends `/api/v1/streaming` to the streaming server and
everything else to web.

Create the first admin once the pods are Ready:

```sh
kubectl exec deploy/mastodon-web -c web -- ruby launch.rb tootctl accounts create admin \
  --email you@example.org --confirmed --role Owner
```

The email domain must be able to receive mail: Mastodon checks its MX record.

## Values

| Key | Default | Meaning |
|---|---|---|
| `localDomain` | `mastodon.local` | the domain in every handle, `@user@<localDomain>` |
| `webDomain` | `""` | serve the web interface on another host than `localDomain` |
| `registrationsMode` | `none` | `open`, `approved` or `none` |
| `secrets.existingSecret` | `""` | your own Rails secrets instead of the generated ones |
| `postgresql.enabled` | `true` | bundled PostgreSQL; `false` plus `externalDatabase.*` for your own |
| `valkey.enabled` | `true` | bundled Valkey; `false` plus `externalRedis.*` for your own |
| `persistence.*` | 20Gi RWO | media uploads under `public/system`, shared by web and sidekiq |
| `extraEnvVars` | `[]` | anything else Mastodon reads, for example `SMTP_*` or `S3_*` |
| `web`, `sidekiq`, `streaming` | 1 replica each | `replicaCount` and `resources` per process |

The web pod runs `rails db:prepare` before it starts: it loads the schema into an empty
database and migrates an existing one. Sidekiq waits until the schema exists.

The Secret `<release>-mastodon` holds `SECRET_KEY_BASE`, `OTP_SECRET` and the three Active
Record encryption keys. They are generated on the first install and reused on every
upgrade. Back that Secret up: losing it logs everyone out, breaks two-factor codes and
makes encrypted columns unreadable.

Media sits on a ReadWriteOnce volume by default, which keeps web and sidekiq on one node.
To spread them, use a ReadWriteMany class or object storage (`S3_ENABLED` and friends in
`extraEnvVars`) with persistence off.

Nothing sends mail until you set `SMTP_SERVER`, `SMTP_LOGIN`, `SMTP_PASSWORD` and
`SMTP_FROM_ADDRESS` in `extraEnvVars`. Sign-up and password mails fail until then.

The release gate installs the chart on kind, checks the instance API version, the
compiled packs and streaming health, creates an owner account and watches sidekiq take its
mail job, then upgrades and restarts web and requires the secrets and the account to survive.

The chart depends on `quench-common`, `postgresql` and `valkey` from `oci://ghcr.io/quenchworks/charts`.
