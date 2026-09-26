# nifi

Apache NiFi, the visual dataflow engine for routing, transforming and moving data
between systems, as a single node on the QuenchWorks image: hardened, nonroot,
0-CVE, pinned by digest and cosign-signed.

## Install

```sh
helm install flow oci://ghcr.io/quenchworks/charts/nifi
kubectl get secret flow-nifi-auth -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/flow-nifi 8443:8443   # https://localhost:8443/nifi/
```

The first start takes a few minutes while NiFi unpacks its NARs. The UI is HTTPS with
a certificate NiFi generates; log in as `admin` with the password above.

## How it runs

- **One node.** A StatefulSet with one replica. NiFi's Kubernetes clustering (leader
  election and state provider) is not wired yet.
- **Persistence.** `conf/` (the flow, the generated keystore and sensitive-properties
  key), the flowfile, content, provenance, status, NAR and database repositories, the
  asset directories and local state share one volume. Logs and the NAR working directory are emptyDirs.
- **Login.** Single-user mode. An init container applies `auth.username` and
  `auth.password` (12+ characters) on every start, so changing them in values takes
  effect on the next restart.
- **Host names.** NiFi rejects unknown Host headers. The Service names and
  `localhost:8443` are allowed; add the name you expose it under to `proxyHosts`.
- **Probes** are TCP: the kubelet's HTTP probes carry the pod IP as Host, which NiFi
  refuses.

## What the image leaves out

The Hazelcast map cache services NAR is removed (hazelcast 5.7.0 bundles vulnerable
jackson). The aws NAR runs with wire 6.4.5 in place of 5.2.0.

## Values

| Key | Default | Meaning |
|---|---|---|
| `auth.username` / `auth.password` | `admin` / generated | single-user login |
| `auth.existingSecret` | `""` | Secret with `username` and `password` keys |
| `heap` | `1g` | JVM -Xms/-Xmx |
| `persistence.size` | `20Gi` | flow and repository volume |
| `proxyHosts` | `[]` | extra accepted Host headers |

## Release gate

On kind, the gate installs the chart, logs in, checks the version, creates a
GenerateFlowFile processor, deletes the pod, and requires the processor to be there
after the restart.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
