# Quenchworks kured

Hardened [kured](https://github.com/kubereboot/kured), the Kubernetes reboot
daemon, on a minimal 0-CVE image built from source and pinned by digest.

kured runs on every node and watches for a reboot-required sentinel file. When a
node needs a reboot it takes a cluster-wide lock, cordons and drains the node,
reboots it, then uncordons it and releases the lock, so nodes reboot one at a
time.

## Install

```sh
helm install kured oci://ghcr.io/quenchworks/charts/kured -n kube-system
```

The sentinel is the host's `/var/run/reboot-required`, which Debian and Ubuntu's
unattended-upgrades write after a kernel update. On other distributions, have
your update tooling create it, or point `sentinelHostPath` and `sentinelFile` at
the file it writes.

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/kured \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them
with `gh attestation verify oci://ghcr.io/quenchworks/images/kured --owner quenchworks`.

## Security model

kured reboots the host it runs on. It execs `nsenter` into PID 1's mount
namespace to run `rebootCommand`, so the pod runs as uid 0, privileged, with
`hostPID`. The root filesystem is read-only and the sentinel directory is
mounted read-only. Install it only where node reboots by a cluster component are
acceptable.

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `rebootCommand` | `/bin/systemctl reboot` | Run in the host's mount namespace. |
| `sentinelHostPath`, `sentinelFile` | `/var/run`, `reboot-required` | The file whose presence means a reboot is needed. |
| `period` | `1h` | How often each node checks. |
| `rebootDays`, `startTime`, `endTime`, `timeZone` | every day, all day, UTC | The reboot window. |
| `concurrency` | `1` | Nodes rebooting at once. |
| `lockTtl` | `0` | Lock lifetime; `0` holds it until released. |
| `drainTimeout`, `drainGracePeriod` | `0`, `-1` | Drain behaviour (`0` waits forever, `-1` uses each pod's grace period). |
| `blockingPodSelectors` | `[]` | Do not reboot while a pod matches any of these. |
| `notifyUrl` | `""` | Notification URL (shoutrrr format). |
| `tolerations` | control-plane | Run on control-plane nodes too. |

The lock is the `weave.works/kured-node-lock` annotation on the chart's own
DaemonSet; the chart grants `update` on that one object only.

## Metrics

`kured_reboot_required{node}` on `:8080/metrics` is 1 while a node waits for its
reboot.
