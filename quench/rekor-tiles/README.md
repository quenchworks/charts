# Quenchworks Rekor v2 (rekor-tiles)

[Rekor v2](https://github.com/sigstore/rekor-tiles) is the Sigstore
transparency log, rebuilt on Trillian Tessera tiles. It needs no Trillian or
MySQL: the log is a directory of tiles and signed checkpoints. This chart runs
the QuenchWorks rekor-tiles image (POSIX backend) as a StatefulSet with the log
on a PVC, and Caddy serving that directory as the read API. The images are
nonroot, 0 fixable CVEs, pinned by digest and cosign-signed.

## Install

```bash
helm install rekor oci://ghcr.io/quenchworks/charts/rekor-tiles --set hostname=rekor.example.com
kubectl logs statefulset/rekor-rekor-tiles -c rekor | grep "Loaded signing key"
```

- Write API: `POST http://rekor-rekor-tiles:3000/api/v2/log/entries` (gRPC on 3001).
- Read API: `http://rekor-rekor-tiles:8080/checkpoint`, `/tile/...`, `/tile/entries/...`.
- Clients verify checkpoints with the public key printed at start.

## Values

| Key | Default | Notes |
|---|---|---|
| `hostname` | release fullname | the log origin, signed into every checkpoint |
| `signer.existingSecret` | `""` | Secret with a PEM key under `signer.key`; an ed25519 key is generated when empty |
| `checkpointInterval` | `10s` | how often a new checkpoint is signed |
| `extraArgs` | `[]` | extra rekor-server flags (`--witness-policy-path`, ...) |
| `readServer.enabled` | `true` | Caddy serving the log directory read-only on 8080 |
| `persistence.enabled` | `true` | a PVC mounted at `/var/lib/rekor` |

## Notes

- One writer. The POSIX backend keeps the log in one directory on one volume.
- Set `hostname` before the first entry. Changing it, or the signing key, later
  starts a different log that existing clients will not verify.
- The generated key Secret has `helm.sh/resource-policy: keep`, so an uninstall
  leaves it behind. Delete it by hand only when the log is gone too.
- The GCP and AWS backends are separate upstream binaries and are not in this image.
