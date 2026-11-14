# Quenchworks dev-platform-stack

Git hosting and CI in one install: [Forgejo](https://codeberg.org/forgejo/forgejo) 15.0.11 on
PostgreSQL with Valkey for cache, sessions and queues, and [Woodpecker CI](https://woodpecker-ci.org)
3.18.1 signing in through Forgejo. All images are QuenchWorks (nonroot, CVE-gated at build, pinned
by digest, cosign-signed). The stack creates the Forgejo administrator and the Forgejo OAuth app
for Woodpecker at install, so Woodpecker sign-in works without any clicks in Forgejo.

## Install

```bash
helm install dev oci://ghcr.io/quenchworks/charts/dev-platform-stack -n dev --create-namespace \
  --set urls.forgejo=https://git.example.com --set forgejo.config.rootUrl=https://git.example.com/ \
  --set urls.woodpecker=https://ci.example.com --set woodpecker.host=https://ci.example.com
```

Expose Forgejo and Woodpecker at those addresses (Ingress). Woodpecker's sign-in sends the browser
to `urls.forgejo`, and the OAuth app's redirect URI is `<urls.woodpecker>/authorize`.

## What the stack sets up

- Secret `devplat-secrets`: the PostgreSQL, Valkey, Forgejo administrator and Woodpecker agent
  passwords, generated once and kept across upgrades and on uninstall.
- Forgejo on PostgreSQL (`devplat-postgresql`, database `forgejo`) and Valkey (`devplat-valkey`),
  with the administrator `forgejo-admin` (`admin.username`).
- A Job, `<release>-oauth-<revision>`, that signs in to Forgejo as the administrator, creates the
  OAuth app `woodpecker`, and stores its client ID and secret in the Secret
  `devplat-woodpecker-oauth`. It does nothing when that Secret exists, so upgrades keep the app.
  Woodpecker's init container waits for the Secret.
- Woodpecker with Forgejo as its forge; the Forgejo administrator is a Woodpecker administrator.

## Values

| Key | Default | Notes |
|---|---|---|
| `urls.forgejo`, `urls.woodpecker` | in-cluster names | the addresses the OAuth wiring uses; set to your public URLs |
| `forgejo.config.rootUrl`, `woodpecker.host` | in-cluster names | the same addresses, for each app |
| `admin.username`, `admin.email` | `forgejo-admin` | also set `forgejo.admin.*` and `WOODPECKER_ADMIN` if you change it |
| `forgejo.*`, `woodpecker.*`, `postgresql.*`, `valkey.*` | | pass to the component charts |

## Notes

- Pipelines need Woodpecker agents, which this stack does not run. Point agents at
  `devplat-woodpecker:9000` with the agent secret from `devplat-secrets`.
- One stack per namespace: the components and Secrets have fixed names, because the subcharts are
  wired from plain values.
- Woodpecker keeps its own data in SQLite on its volume; PostgreSQL and Valkey serve Forgejo.
- Changing `urls.*` after the first install does not update the OAuth app's redirect URI. Edit
  the app in Forgejo (Site administration, Applications) or delete `devplat-woodpecker-oauth` and
  the app, then upgrade to create a new one.
