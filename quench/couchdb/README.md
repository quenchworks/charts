# Quenchworks CouchDB

Hardened [Apache CouchDB 3.x](https://couchdb.apache.org/) on a minimal, nonroot,
0-CVE image pinned by digest. CouchDB is built from source on Wolfi onto the Erlang
runtime. The JavaScript view server is the **bundled QuickJS engine** (no
SpiderMonkey/mozjs, which removes that entire CVE surface). **Fauxton (the web UI)
and the docs are not bundled** to keep Node and Python/Sphinx off the scan surface.
The clustered HTTP API is served on port `5984`. Single node by default.

## Install

```bash
helm install db oci://ghcr.io/quenchworks/charts/couchdb
```

CouchDB 3.x refuses to start in admin-party mode, so an admin user is required. The
admin password, the Erlang cookie and the cookie-auth secret are stored in a Secret
(generated if you do not supply them, and preserved across upgrades). After the
StatefulSet is ready, a post-install hook Job creates the system databases
(`_users`, `_replicator`, `_global_changes`), which the image does not create on its
own; a single-node CouchDB is not functional without them.

## Connect

```bash
# admin password
kubectl get secret db-couchdb -o jsonpath="{.data.adminPassword}" | base64 -d
```

Create a database, put a document, and query a JavaScript map view (admin creds in
`$USER`/`$PASS`):

```bash
HOST=http://db-couchdb:5984
curl -fsS "$HOST/"                                   # {"couchdb":"Welcome",...}
curl -fsS -u "$USER:$PASS" -X PUT "$HOST/demo"
curl -fsS -u "$USER:$PASS" -X PUT "$HOST/demo/doc1" \
  -H 'Content-Type: application/json' -d '{"name":"quench","n":7}'
curl -fsS -u "$USER:$PASS" -X PUT "$HOST/demo/_design/d" \
  -H 'Content-Type: application/json' \
  -d '{"views":{"by_name":{"map":"function(doc){ if(doc.name){ emit(doc.name, doc.n); } }"}}}'
curl -fsS -u "$USER:$PASS" "$HOST/demo/_design/d/_view/by_name"   # row from the JS view
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/couchdb \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/couchdb \
  --owner quenchworks
```

## Values

| Key                           | Default                              | Notes                                                                                     |
| ----------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/couchdb` |                                                                                           |
| `image.digest`                | (CI-written)                         | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                  | Single node (`couchdb@127.0.0.1`).                                                        |
| `auth.username`               | `admin`                              | Admin user; the image will not start without one.                                         |
| `auth.password`               | (generated)                          | 24-char random if empty; stored in the Secret.                                            |
| `auth.erlangCookie`           | (generated)                          | 32-char random if empty; shared cluster cookie.                                           |
| `auth.secret`                 | (generated)                          | 32-char random if empty; `[chttpd_auth]` secret.                                          |
| `auth.existingSecret`         | `""`                                 | Use an existing Secret for the credentials.                                               |
| `systemDatabases.create`      | `true`                               | Post-install hook Job creates `_users`/`_replicator`/`_global_changes`.                   |
| `systemDatabases.image.*`     | `curlimages/curl:8.11.1`             | Stock curl image for the init Job (runtime image has no HTTP client).                     |
| `persistence.enabled`         | `true`                               | 8Gi PVC at `/var/lib/couchdb`.                                                            |
| `service.port`                | `5984`                               | Clustered HTTP API.                                                                       |
| `networkPolicy.enabled`       | `true`                               | Restricts HTTP ingress to the release namespace.                                          |
| `podDisruptionBudget.enabled` | `true`                               | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                              | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                 | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                 | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                               | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                 | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                 | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. All writable state (data dirs, the layered `local.ini`/`local.d`, and the
Erlang cookie via `HOME`) lives on the writable `/var/lib/couchdb` volume; `/tmp` is
an emptyDir. Credentials live in a Kubernetes Secret. The QuickJS view server means
there is no SpiderMonkey/mozjs on the image. Readiness and liveness use the
unauthenticated `GET /` welcome endpoint (`/_up` requires admin auth once an admin is
set). Keep CouchDB behind the NetworkPolicy for internal use.

## Notes

Single node by default (`couchdb@127.0.0.1`, no extra ports). The system-database
Job is idempotent (it treats an "already exists" 412 as success), so it is safe on
restarts and upgrades. Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.
