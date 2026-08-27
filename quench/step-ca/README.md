# Quenchworks step-ca

Hardened [step-ca](https://smallstep.com/docs/step-ca/) — the Smallstep online
certificate authority — on a minimal, nonroot, 0-CVE image, cosign-signed
(keyless / Sigstore) and pinned by digest. Serves an ACME / step CA over HTTPS. Single node; the PKI (root + intermediate
CA, provisioners, ca.json and the badger db) persists to a PVC.

## Install

```bash
helm install my-ca oci://ghcr.io/quenchworks/charts/step-ca \
  --set auth.password='<ca-key-password>' \
  --set auth.provisionerPassword='<first-provisioner-password>'
```

A one-shot **pre-install Job** runs `step ca init` (via the bundled `step` CLI)
to generate the PKI onto the PVC. It runs exactly once at install; pod restarts,
reschedules and `helm upgrade` never re-run it, so the CA identity is stable.
Then port-forward and check health:

```bash
kubectl port-forward svc/my-ca-step-ca 9000:443
curl -k https://127.0.0.1:9000/health        # {"status":"ok"}
curl -sk https://127.0.0.1:9000/roots.pem     # the CA root certificate
```

> `step-ca` serves HTTPS only and presents its own CA-signed leaf, so clients
> must trust the root (`/roots.pem`); `curl -k` skips verification for a quick check.

## Passwords

Set them via a Secret (recommended) or inline values, and **rotate after
bootstrap**:

```yaml
auth:
  existingSecret: my-ca-secret # keys: password, provisioner-password
  # or, inline (rendered into a chart-managed Secret):
  # password: "..."
  # provisionerPassword: "..."
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/step-ca \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/step-ca --owner quenchworks`.

## Values

| Key                           | Default                              | Notes                                                                                     |
| ----------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------- |
| `image.repository`            | `ghcr.io/quenchworks/images/step-ca` | Ships both `step-ca` and `step`.                                                          |
| `image.digest`                | (CI-written)                         | Required. Charts pin by digest, never a tag.                                              |
| `replicaCount`                | `1`                                  | Stateful single node; do not scale out.                                                   |
| `containerPort`               | `9000`                               | HTTPS port step-ca binds; wired into `ca.json` and the probes.                            |
| `service.port`                | `443`                                | Service port, forwards to the container's `https` port.                                   |
| `ca.name`                     | `QuenchWorks CA`                     | PKI / root subject name (init only).                                                      |
| `ca.provisioner`              | `admin@quench-works.com`             | First JWK provisioner created at init.                                                    |
| `ca.dnsNames`                 | `[]`                                 | Extra SANs; the in-cluster Service names + `localhost` are always added.                  |
| `ca.deploymentType`           | `standalone`                         | `step ca init --deployment-type`.                                                         |
| `auth.existingSecret`         | `""`                                 | Secret with `password` + `provisioner-password`.                                          |
| `auth.password`               | `""`                                 | CA key password (required unless `existingSecret`).                                       |
| `auth.provisionerPassword`    | `""`                                 | First provisioner password (required unless `existingSecret`).                            |
| `persistence.enabled`         | `true`                               | Standalone PVC at STEPPATH `/home/step`; **required** (the CA is stateful).               |
| `persistence.size`            | `1Gi`                                |                                                                                           |
| `persistence.existingClaim`   | `""`                                 | Bind an existing PVC instead of provisioning one.                                         |
| `serviceAccount.create`       | `true`                               | Token automount is off.                                                                   |
| `rbac.create`                 | `false`                              | Minimal empty Role/RoleBinding when enabled.                                              |
| `networkPolicy.enabled`       | `true`                               | Client ingress from the namespace; set `allowExternal: true` to open it.                  |
| `podDisruptionBudget.enabled` | `true`                               | `minAvailable: 1`.                                                                        |
| `ingress.enabled`             | `false`                              | Create an Ingress for this chart. HTTP only.                                              |
| `ingress.className`           | `""`                                 | IngressClass to claim it. Empty leaves it unset, so the cluster default applies.          |
| `ingress.annotations`         | `{}`                                 | Controller annotations (rewrite targets, body size, cert-manager issuer, ...).            |
| `ingress.servicePort`         | `null`                               | Backend port. Unset resolves `service.port`, then `service.ports.http` / `.https`.        |
| `ingress.hosts`               | `[]`                                 | e.g. `[{host: app.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls`                 | `[]`                                 | Standard Ingress TLS list, e.g. `[{hosts: [app.example.com], secretName: app-tls}]`.      |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init
containers, extra env/volumes, security contexts, update strategy).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the STEPPATH PVC (`/home/step`) and an emptyDir `/tmp` are
writable; the password Secret is mounted read-only. step-ca serves `/health`
(returns `{"status":"ok"}`), used for liveness/readiness/startup probes over
HTTPS.

## Notes

Single node only: step-ca stores its CA keys, config and badger database on one
local volume, so it cannot be horizontally scaled. The bootstrap Job and the
server share the same PVC, so `persistence.enabled` must stay true (or set
`persistence.existingClaim`). For HA / cloud KMS-backed keys you would move to a
`linked`/`hosted` deployment type, tracked as a follow-up.
