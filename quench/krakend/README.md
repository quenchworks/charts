# Quenchworks KrakenD

Hardened [KrakenD](https://github.com/krakend/krakend-ce) Community Edition API
gateway on a minimal, nonroot, read-only-rootfs, 0-CVE image pinned by digest.
Built from source on Wolfi (no upstream distro binaries). Listens on `8080`,
which is unprivileged because the container runs as nonroot uid 1001.

KrakenD is stateless and entirely declarative: it reads one JSON config at boot
and holds nothing afterwards. This chart runs it as a `Deployment` with no
volumes and scales horizontally.

## Install

```bash
helm install api oci://ghcr.io/quenchworks/charts/krakend
```

The default install is a working gateway, not a stub. It ships a sample endpoint
so a fresh install serves real traffic immediately:

```bash
kubectl port-forward svc/api-krakend 8080:80
curl http://127.0.0.1:8080/__health        # {"agents":...,"status":"ok"}
curl http://127.0.0.1:8080/quench/sample   # routed through the gateway
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/krakend \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/krakend --owner quenchworks`.

## Configuration

KrakenD will not start without a config file. The `config` value is a map that
the chart renders to JSON, writes to a ConfigMap, and mounts read-only at
`/etc/krakend/krakend.json` — the path the image entrypoint already loads
(`krakend run -c /etc/krakend/krakend.json`).

The shipped default declares one endpoint whose backend is the gateway's *own*
built-in `/__health`. That keeps a default install self-contained (no upstream
to deploy first) while still exercising the whole path: router → proxy → backend
HTTP call → JSON decode → response. Replace `endpoints` with your own routes:

```yaml
config:
  version: 3
  timeout: 3s
  endpoints:
    - endpoint: /v1/users/{id}
      method: GET
      output_encoding: json
      backend:
        - host: ["http://users.default.svc.cluster.local:8080"]
          url_pattern: /users/{id}
          encoding: json
```

`config` is merged into by Helm the usual way, so `endpoints` (a list) is
replaced wholesale by your values file — the sample does not linger.

`port` is always taken from `containerPort` and overwrites anything you set in
`config.port`, so the config and the container port cannot drift. The sample
endpoint's loopback backend host is a literal `http://127.0.0.1:8080`; if you
change `containerPort`, replace the sample endpoint too.

Validate a config with the same binary before rolling it out:

```bash
krakend check -c krakend.json
```

### Existing ConfigMap

To manage `krakend.json` outside this chart (GitOps, a config generator, a
Secret-free bundle), point at an existing ConfigMap. The chart then renders no
ConfigMap of its own and `config` is ignored:

```yaml
existingConfigMap: my-krakend-config
existingConfigMapKey: krakend.json   # projected as /etc/krakend/krakend.json
```

The key may be named anything; it is projected to `krakend.json` in the mount.

### Rollouts

KrakenD reads its config once, at boot. The pod template carries a checksum of
the rendered config, so `helm upgrade` restarts the pods whenever the config
changes. With `existingConfigMap` that checksum cannot exist — restart the
Deployment yourself after editing the ConfigMap.

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/krakend` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `replicaCount` | `1` | Stateless; scale freely (ignored when autoscaling is on). |
| `containerPort` | `8080` | Gateway listen port; injected into `krakend.json` as `port`. |
| `config` | sample gateway | KrakenD config document rendered to `krakend.json`. |
| `existingConfigMap` | `""` | Serve `krakend.json` from an existing ConfigMap instead; takes precedence over `config`. |
| `existingConfigMapKey` | `krakend.json` | Key in that ConfigMap; projected as `krakend.json`. |
| `service.type` | `ClusterIP` | |
| `service.port` | `80` | Service port -> container `http` (8080). |
| `autoscaling.enabled` | `false` | Optional CPU HPA (`minReplicas`/`maxReplicas`). |
| `networkPolicy.enabled` | `true` | Ingress to the `http` port. |
| `networkPolicy.allowExternal` | `false` | Set `true` when clients live outside the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |
| `ingress.enabled` | `false` | Create an Ingress for this chart. HTTP only. |
| `ingress.className` | `""` | IngressClass to claim it. Empty leaves it unset, so the cluster default applies. |
| `ingress.annotations` | `{}` | Controller annotations (rewrite targets, body size, cert-manager issuer, ...). |
| `ingress.servicePort` | `null` | Backend port. Unset resolves `service.port`. |
| `ingress.hosts` | `[]` | e.g. `[{host: api.example.com}]`. A host with no `paths` gets a single `/` `Prefix` path. |
| `ingress.tls` | `[]` | Standard Ingress TLS list, e.g. `[{hosts: [api.example.com], secretName: api-tls}]`. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, extra
env/volumes, security contexts).

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped and privilege escalation disabled. There are no writable volumes at all
— KrakenD writes nothing at runtime — and the only mount is the read-only
config. Logs go to stdout. The NetworkPolicy is the trust boundary; the gateway
is namespace-only until you set `networkPolicy.allowExternal`.

## Notes

Depends on the `quench-common` library chart, pulled from
`oci://ghcr.io/quenchworks/charts/quench-common`.
