# Quenchworks nats-jetstream-controller

[NACK](https://github.com/nats-io/nack), the NATS JetStream Controller, 0.25.0 on
the QuenchWorks image (built from source, nonroot, CVE-gated at build, pinned by
digest, cosign-signed). It manages JetStream on a NATS server from Kubernetes
resources: `Stream`, `Consumer`, `KeyValue`, `ObjectStore`, `Account` and
`StreamTemplate`.

The chart installs the six CRDs from the release tag, the controller and
upstream's ClusterRole.

## Install

Point it at a NATS server with JetStream on, for example the QuenchWorks `nats`
chart:

```bash
helm install nats oci://ghcr.io/quenchworks/charts/nats
helm install nack oci://ghcr.io/quenchworks/charts/nats-jetstream-controller --set natsUrl=nats://nats-nats:4222
```

## Values

| Key | Default | Notes |
|---|---|---|
| `natsUrl` | `""` | required: the NATS server (`-s`) |
| `crdConnect` | `false` | each resource names its own servers and credentials (`--crd-connect`) |
| `watchNamespace` | `""` | one namespace only (`--namespace`); empty watches all |
| `controlLoop` | `true` | `--control-loop`; needed for KeyValue and ObjectStore |
| `readOnly` | `false` | reconcile without changing NATS (`--read-only`) |
| `extraArgs` | `[]` | more controller flags, e.g. `--cleanup-period=1m` |
| `rbac.create` | `true` | upstream's ClusterRole |

## Notes

- `controlLoop: true` (the default) runs upstream's `--control-loop` mode. It is
  marked experimental upstream, but the legacy event mode does not handle
  `KeyValue` or `ObjectStore` resources and serves no health endpoint. With
  `controlLoop: false` the pod has no probes.
- Credentials and TLS files named in resources are written to `/tmp/nack`
  (`--cache-dir`), an emptyDir, and the working directory is `/tmp`, because
  legacy mode ignores `--cache-dir`; the root filesystem stays read-only.
- Helm installs the CRDs on first install and never upgrades or deletes them.
  Apply the new `crds/crds.yaml` yourself before upgrading across NACK releases.
