# Quenchworks linkerd

[Linkerd](https://linkerd.io) on QuenchWorks images built from source, 0-CVE, cosign-signed and
pinned by digest: the control plane AND the data plane. Annotated workloads get the
linkerd-proxy sidecar and talk mutual TLS with a certificate for their ServiceAccount.

Tracks Linkerd's EDGE releases (this is edge-26.8.4 with linkerd2-proxy v2.366.0): upstream has
not cut an open stable release since stable-2.14.10 and gates stable builds commercially.

| Component | Pod | Mesh identity |
|---|---|---|
| destination + policy server | `linkerd-destination` | `linkerd-destination` |
| identity (the mesh CA) | `linkerd-identity` | `linkerd-identity` |
| proxy injector (webhook) | `linkerd-proxy-injector` | `linkerd-proxy-injector` |

Each control-plane pod runs its own proxy, like upstream. Object names are upstream's fixed names
because the injected proxies dial and verify them by name, so install one release per namespace,
in `linkerd`.

## Install

Three QuenchWorks charts, in this order. There is no proxy-init image, so the data plane runs in
CNI mode: the linkerd-cni plugin sets up each meshed pod's traffic redirection, and pods get no
privileged `linkerd-init` container.

```sh
# 1. CRDs (destination exits without them)
helm install linkerd-crds oci://ghcr.io/quenchworks/charts/linkerd-crds -n linkerd --create-namespace
# 2. the CNI plugin, before any meshed pod starts
helm install linkerd-cni oci://ghcr.io/quenchworks/charts/linkerd-cni -n linkerd-cni --create-namespace --wait

# 3. a trust anchor and an issuer signed by it (keep ca.key offline)
openssl req -new -x509 -nodes -days 3650 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout ca.key -out ca.crt -subj "/CN=root.linkerd.cluster.local" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"
openssl req -new -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout issuer.key -out issuer.csr -subj "/CN=identity.linkerd.cluster.local"
printf 'basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n' > ext
openssl x509 -req -in issuer.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 \
  -extfile ext -out issuer.crt
kubectl -n linkerd create secret generic linkerd-identity-issuer \
  --from-file=crt.pem=issuer.crt --from-file=key.pem=issuer.key

# 4. this chart
helm install linkerd oci://ghcr.io/quenchworks/charts/linkerd -n linkerd \
  --set-file identity.trustAnchorsPEM=ca.crt --set identity.existingSecret=linkerd-identity-issuer
```

The issuer's CN must be `identity.<namespace>.<trustDomain>` (`identity.linkerd.cluster.local`
for the defaults): the identity controller refuses any other.

## Mesh a workload

```sh
kubectl annotate namespace web linkerd.io/inject=enabled
kubectl -n web rollout restart deploy
kubectl get --raw /api/v1/namespaces/web/pods/<pod>:4191/proxy/metrics | grep 'tls="true"'
```

The injector adds the `linkerd-proxy` native sidecar and a `linkerd-network-validator` init
container (which checks the CNI redirect), never `linkerd-init`.

## Upgrading from 0.0.x

0.1.0 renamed every object (0.0.x used `<release>-linkerd-*` names, ran the policy server in its
own Deployment and shipped no data plane). It cannot be upgraded in place: `helm upgrade` from
0.0.x stops with an error naming the old Deployment. Uninstall the 0.0.x release, then follow
Install above.

## Values

| Key | Default | Meaning |
|---|---|---|
| `identity.trustAnchorsPEM` | required | the trust anchor certificate (public) |
| `identity.existingSecret` | required | Secret with the issuer's `crt.pem` and `key.pem` |
| `identity.trustDomain` | `cluster.local` | suffix of every mesh identity |
| `proxy.defaultInboundPolicy` | `all-unauthenticated` | meshed pods' default inbound policy |
| `proxy.logLevel` | `warn,linkerd=info,hickory=error` | proxy log filter |
| `proxyInjector.failurePolicy` | `Ignore` | `Fail` blocks pod creation while the injector is down |
| `kubeAPIServerPorts` | `443,6443` | the control plane reaches the API server on these ports without its proxy |
| `clusterNetworks`, `defaultOpaquePorts` | upstream defaults | |

## Not included

linkerd-viz, multicluster, the heartbeat CronJob, the ServiceProfile and policy validating
webhooks, proxy-init (sidecar iptables setup without CNI), and a NetworkPolicy.

## Release gate

The gate installs linkerd-crds, linkerd-cni and this chart into kind with freshly generated
certificates. It requires every control-plane proxy to hold its identity certificate, an injected
pod with no `linkerd-init` reaching another injected pod with `tls="true"` on its proxy's outbound
metrics, and the policy server answering.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
