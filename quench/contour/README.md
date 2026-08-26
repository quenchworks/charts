# Quenchworks Contour

Hardened [Project Contour](https://github.com/projectcontour/contour) on minimal,
nonroot, 0-CVE images, pinned by digest. Contour is a Kubernetes ingress controller
that programs an [Envoy](https://www.envoyproxy.io/) data plane over xDS. It serves
the standard `networking.k8s.io` Ingress API plus its own `HTTPProxy` CRD, which adds
cross-namespace route delegation, per-route TLS, traffic splitting and rate limiting
without annotation soup.

## Install

```sh
helm install contour oci://ghcr.io/quenchworks/charts/contour \
  -n projectcontour --create-namespace
```

## Architecture

Contour is two halves that must both be present for traffic to flow. This chart ships
both, from two QuenchWorks images.

| Workload | Image | Role |
|----------|-------|------|
| `Deployment/<release>-contour` | `contour` | the control plane: watches Ingress/HTTPProxy/Service/EndpointSlice/Secret, builds the routing DAG, writes status onto the objects, serves it over gRPC xDS |
| `DaemonSet/<release>-contour-envoy` | `envoy` + `contour` | the data plane: one Envoy per node, plus a `shutdown-manager` sidecar from the contour image |
| `Job/<release>-contour-certgen` (hook) | `contour` | mints the Contour <-> Envoy xDS mTLS keypairs before the release is applied |

The contour image's entrypoint is the **bare binary with no default subcommand**, on
purpose: one image plays four roles here (`serve`, `bootstrap`, `envoy shutdown-manager`,
`certgen`) and a baked-in default would make three of them an override. The image also
ships **no shell**, so every command in this chart is exec form.

Inside the Envoy pod:

* an `envoy-initconfig` initContainer runs `contour bootstrap` — a fully offline code
  path — to write `/config/envoy.json` and the two SDS descriptor files into an
  `emptyDir`. Everything after that arrives over xDS.
* `/admin` is a second `emptyDir` shared with the sidecar, because Envoy's admin
  interface here is a **unix socket**, not a port.
* Envoy's `preStop` is an HTTP call **into** the shutdown-manager (`:8090/shutdown`),
  not an exec — the Envoy image has neither a shell nor the contour binary. The sidecar
  drains Envoy over the admin socket, which is why the grace period is 300s.
* Both containers run read-only-rootfs, nonroot, all capabilities dropped.

Envoy listens on `8080`/`8443` in the pod; the Service maps `80`/`443` onto them.
Those listener ports are fixed. Do **not** pass `--envoy-service-http-port` through
`contour.extraArgs`: despite its name it moves the port Envoy *binds*, not the Service
port, and setting it to 80 silently strands the data plane away from the containerPorts
the Service targets.

### Version pairing

Contour hard-pairs each release with one Envoy minor. Chart `appVersion` 1.33.6 ships
the Envoy 1.38 line. Moving one image without the other is not supported upstream.

## Contour <-> Envoy xDS mTLS

The xDS stream is mutually authenticated. `contour certgen` mints a self-signed CA and
one keypair per side straight into Secrets, from a `pre-install`/`pre-upgrade` hook, so
neither workload ever starts into a namespace without its certificates. The hook's
ServiceAccount is the only identity in the chart allowed to write Secrets, and it is
deleted again once the hook succeeds.

Two consequences worth knowing:

* The Secrets are **not owned by the Helm release**. `helm uninstall` leaves them.
* The hook **does not overwrite** existing Secrets, so upgrades are a no-op. This is
  deliberate. Envoy watches the SDS descriptor files its bootstrap wrote, not the
  `ca.crt` those files point at, so a re-minted CA leaves every xDS stream failing
  `CERTIFICATE_VERIFY_FAILED` until the pods restart. Rotating is therefore an explicit,
  two-step operation:

  ```sh
  helm upgrade contour oci://ghcr.io/quenchworks/charts/contour \
    -n projectcontour --set xdsTLS.certgen.overwrite=true
  kubectl -n projectcontour rollout restart \
    deployment/contour-contour daemonset/contour-contour-envoy
  ```

To bring your own certificates instead (cert-manager, Vault, ...), set
`xdsTLS.contourSecretName` / `xdsTLS.envoySecretName`. Both must be
`kubernetes.io/tls` Secrets carrying `ca.crt`, `tls.crt` and `tls.key`, and the Contour
certificate **must** carry the DNS SAN `contour` — the Envoy bootstrap pins that exact
SAN and no flag changes it.

## CRDs

`crds/contour.crds.yaml` holds `HTTPProxy`, `ContourConfiguration`, `ExtensionService`
and `TLSCertificateDelegation`, verbatim from the upstream 1.33.6 release manifest.
Helm installs `crds/` before the templates and never upgrades or deletes them, so a
Contour upgrade that changes a CRD schema needs them applied by hand:

```sh
kubectl apply --server-side -f quench/contour/crds/contour.crds.yaml
```

`ContourDeployment` is not included: it is only consumed by
`contour gateway-provisioner`, which this chart does not run.

## Smoke test

`--wait` returning 0 only means the pods are Ready. These two checks prove the halves
actually work.

```sh
# 1. the control plane is reconciling: it writes status onto an object you create
kubectl -n projectcontour apply -f - <<'EOF'
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: smoke
spec:
  virtualhost:
    fqdn: direct.example.com
  routes:
    - conditions: [{prefix: /}]
      directResponsePolicy:
        statusCode: 200
        body: "contour-xds-ok"
EOF
kubectl -n projectcontour get httpproxy smoke -o jsonpath='{.status.currentStatus}'
# -> valid

# 2. the data plane is programmed: that route reached Envoy over the xDS stream
kubectl -n projectcontour port-forward svc/contour-contour-envoy 18080:80 &
curl -H 'Host: direct.example.com' http://127.0.0.1:18080/     # -> contour-xds-ok
curl -o /dev/null -w '%{http_code}\n' -H 'Host: nope' http://127.0.0.1:18080/   # -> 404
```

A 404 for an unknown host means Envoy is serving but has no such route; a refused
connection means the data plane is not listening where you think it is.

## Routing traffic here

Ingress objects: set `ingressClassName: contour`, or leave the class off entirely —
Contour with no configured class matches both. Set `ingressClass.name` to run several
Contours in one cluster; the Deployment then passes the matching `--ingress-class-name`
automatically. `IngressClass` is cluster-scoped, so that name must be unique.

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.contour.digest` / `image.envoy.digest` | (CI-maintained) | signed multi-arch indexes, pinned by digest |
| `contour.replicaCount` | `2` | stateless; a leader-election Lease picks the status writer |
| `contour.config` | `{}` | rendered to `contour.yaml` and passed via `--config-path`; see the [Contour configuration reference](https://projectcontour.io/docs/1.33/configuration/) |
| `contour.existingConfigMap` | `""` | mount your own ConfigMap (key `contour.yaml`) instead |
| `contour.watchNamespaces` | `[]` | restrict the controller's informers |
| `contour.rootNamespaces` | `[]` | namespaces allowed to hold *root* HTTPProxies |
| `contour.extraArgs` | `[]` | appended to `contour serve` |
| `envoy.enabled` | `true` | off only if an Envoy fleet managed elsewhere points at this control plane |
| `envoy.service.type` | `LoadBalancer` | use `NodePort` or `hostPorts` where there is no LB controller |
| `envoy.service.externalTrafficPolicy` | `Local` | preserves the client source IP |
| `envoy.hostPorts.enabled` | `false` | binds `:80`/`:443` on the node; makes the DaemonSet unschedulable where those are taken |
| `envoy.terminationGracePeriodSeconds` | `300` | the connection drain window; shortening it defeats the shutdown-manager |
| `envoy.nodeSelector` / `envoy.tolerations` | `{}` / `[]` | scheduling for the DaemonSet, separate from the controller's |
| `xdsTLS.certgen.enabled` | `true` | mint the xDS keypairs in-cluster |
| `xdsTLS.certgen.overwrite` | `false` | see the mTLS section before turning this on |
| `xdsTLS.contourSecretName` / `xdsTLS.envoySecretName` | `""` | bring your own; disables certgen |
| `ingressClass.create` / `.name` / `.default` | `true` / `""` / `false` | |
| `rbac.create` | `true` | cluster-wide read, writes confined to `/status`, events and its own Lease |
| `podDisruptionBudget.enabled` | `true` | guards the control plane only |

The usual QuenchWorks pod knobs (`nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, `podLabels`, `extraEnvVars`, `extraVolumes`, `sidecars`,
probes, security contexts) apply to the Contour Deployment.

## Verify the images

```sh
cosign verify ghcr.io/quenchworks/images/contour \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
