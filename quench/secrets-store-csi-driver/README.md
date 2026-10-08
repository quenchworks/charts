# Quenchworks Secrets Store CSI Driver

The [Secrets Store CSI Driver](https://github.com/kubernetes-sigs/secrets-store-csi-driver)
1.6.1 mounts secrets from external stores into pods as volumes. Each store plugs in through
a provider (Vault, AWS, Azure, GCP), installed separately. The driver and both CSI sidecars
are built from source by QuenchWorks on Wolfi, 0-CVE, cosign-signed, and pinned by digest.

```sh
helm install csi-secrets-store oci://ghcr.io/quenchworks/charts/secrets-store-csi-driver -n kube-system
```

The chart installs the `SecretProviderClass` and `SecretProviderClassPodStatus` CRDs, the
`secrets-store.csi.k8s.io` CSIDriver, and a privileged DaemonSet on every node: the driver
mounts tmpfs volumes into pod directories under the kubelet with bidirectional mount
propagation, which needs privileged mode. Providers place their sockets in
`/var/run/secrets-store-csi-providers` or `/etc/kubernetes/secrets-store-csi-providers`.

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata: { name: app-secrets }
spec:
  provider: vault
  parameters: { ... }   # provider specific
---
# in the pod spec
volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes: { secretProviderClass: app-secrets }
```

## Values

| Key | Default | Notes |
|---|---|---|
| `syncSecret.enabled` | `false` | Mirror objects into Kubernetes Secrets (`spec.secretObjects`); grants the driver write access to Secrets cluster-wide |
| `enableSecretRotation` | `false` | Re-fetch mounted secrets every `rotationPollInterval` (`2m`) |
| `kubeletDir` | `/var/lib/kubelet` | Change for distributions that move the kubelet root |
| `extraArgs` | `[]` | Extra driver flags |
| `image`, `registrar`, `livenessProbe` | pinned digests | Driver, node-driver-registrar 2.18.0, livenessprobe 2.20.0 |
| `tolerations` | `[{operator: Exists}]` | Runs on every node, tainted or not |

## Testing

The release workflow installs the chart in kind with upstream's e2e mock provider (built
from the same tag, test only), mounts a SecretProviderClass in a pod, reads the secret from
the volume, and checks that the synced Kubernetes Secret holds the same value.
