# Quenchworks headscale

Hardened [headscale](https://headscale.net/) — an open-source implementation of
the Tailscale control server — on a minimal, nonroot, 0-CVE image pinned by
digest. Single node; persists its SQLite DB and generated noise/machine keys to a
PVC. Config is shipped via a ConfigMap mounted at `/etc/headscale/config.yaml`.

## Install

```bash
helm install my-headscale oci://ghcr.io/quenchworks/charts/headscale \
  --set serverUrl=https://headscale.example.com
```

Then create a user and a pre-auth key, and point a client at the server:

```bash
kubectl exec -it my-headscale-headscale-0 -- \
  headscale --config /etc/headscale/config.yaml users create alice
kubectl exec -it my-headscale-headscale-0 -- \
  headscale --config /etc/headscale/config.yaml preauthkeys create --user 1

tailscale up --login-server https://headscale.example.com
```

> `serverUrl` MUST be a URL your nodes can reach (normally an HTTPS endpoint via
> an Ingress/LoadBalancer terminating TLS in front of this Service) and MUST NOT
> be a subdomain of `dns.base_domain`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/headscale \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/headscale` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateful single writer (SQLite); do not scale out. |
| `containerPort` | `8080` | HTTP API / coordination port (nonroot). |
| `metricsPort` | `9090` | Prometheus metrics port, exposed on the Service as `metrics`. |
| `serverUrl` | `http://127.0.0.1:8080` | The login-server URL clients use. **Override this.** |
| `config` | (see values.yaml) | Full headscale config.yaml, `tpl`-rendered into a ConfigMap. |
| `service.port` | `8080` | Service port, forwards to the container's `http` port. |
| `persistence.enabled` | `true` | 1Gi PVC mounted at `/var/lib/headscale` (DB + noise key + socket). |
| `persistence.size` | `1Gi` | |
| `persistence.dataDir` | `/var/lib/headscale` | Mount point; must match the paths in `config`. |
| `persistence.existingClaim` | `""` | Bind an existing PVC instead of provisioning one. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal empty Role/RoleBinding when enabled. |
| `networkPolicy.enabled` | `true` | Client ingress from the namespace; set `allowExternal: true` to open it. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Configuration

The entire headscale `config.yaml` lives in `.Values.config` and is rendered
through Helm's `tpl`, so `{{ .Values.serverUrl }}` and the ports/data-dir resolve
at render time. It is mounted read-only at `/etc/headscale/config.yaml`. All
state paths (noise key, SQLite DB, control socket) point at the PVC data dir so
headscale can write them under the read-only root filesystem. Editing `config`
and running `helm upgrade` rolls the pod via a checksum annotation.

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the PVC at `/var/lib/headscale` is writable — headscale generates
its noise private key there on first boot. headscale serves `/health` (HTTP 200),
used for both liveness and readiness probes.

## Notes

Single node only: headscale is the single writer of a local SQLite database plus
generated keys, so it cannot be horizontally scaled with this chart. For HA you
would run an external PostgreSQL backend and a different topology, tracked as a
follow-up.
