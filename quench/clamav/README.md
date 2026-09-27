# Quenchworks ClamAV

Hardened [ClamAV](https://github.com/Cisco-Talos/clamav), built from the release
tarball, on a minimal, nonroot, 0-CVE image, cosign-signed and pinned by digest.
clamd scans streams over TCP 3310 for apps that check uploads. A freshclam init
container fills the signature database before clamd starts, and a freshclam
sidecar keeps it current.

## Install

```bash
helm install av oci://ghcr.io/quenchworks/charts/clamav
```

Apps connect to `av-clamav:3310` and send files with the clamd protocol
(`zINSTREAM`); most languages have a client library. Check it answers:

```bash
kubectl run -it --rm ping --image=ghcr.io/quenchworks/images/busybox:1.38.0 --restart=Never -- \
  sh -c "printf 'zPING\\0' | nc av-clamav 3310"
```

## The signature database and rate limits

database.clamav.net is a CDN that rate-limits heavy users and whole cloud IP
ranges. A client on cool-down gets only part of the database (often just
`bytecode.cvd`), and **freshclam still exits 0**, so clamd starts with far
fewer signatures than you expect. Watch the `freshclam-init` log for
`cool-down`. With more than a couple of clusters, run a private mirror
(ClamAV's cvdupdate tool) and set `freshclam.privateMirror`.

For air-gapped clusters, set `freshclam.enabled=false` and supply the database
yourself through `customSignatures`, or mount one with `extraVolumes`.

## Memory

The full database needs about 1.5 GiB resident, and briefly twice that while
clamd reloads it after an update. The defaults request 1.5 GiB and allow 3 GiB.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/clamav \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/clamav --owner quenchworks`.

## Values

| Key | Default | Description |
|---|---|---|
| `freshclam.enabled` | `true` | Init container plus updater sidecar |
| `freshclam.checks` | `12` | Update checks per day |
| `freshclam.mirror` | `database.clamav.net` | Official mirror |
| `freshclam.privateMirror` | `""` | Your own mirror, preferred when set |
| `customSignatures` | `{}` | Extra signature files, `{filename: content}` |
| `clamd.maxThreads` | `10` | Concurrent scans |
| `clamd.streamMaxLength` | `100M` | Largest stream accepted |
| `clamd.selfCheck` | `600` | Seconds between database reload checks |
| `clamd.extraConfig` | `""` | Raw `clamd.conf` lines |
| `resources` | 1.5Gi / 3Gi memory | See Memory above |
| `service.port` | `3310` | clamd Service port |
| `networkPolicy.allowExternal` | `true` | Allow clients from other namespaces |

The common quench-common knobs (`nodeSelector`, `tolerations`, `extraVolumes`,
`sidecars`, probes and so on) are available as in every QuenchWorks chart.
