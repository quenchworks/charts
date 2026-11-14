# Quenchworks cdi-operator

The KubeVirt [Containerized Data Importer](https://github.com/kubevirt/containerized-data-importer)
1.66.1 through its operator. CDI fills PVCs with disk images: a DataVolume names a source (HTTP(S),
S3, GCS, a container registry, an upload, or another PVC) and CDI imports it, converting to a raw
disk image with qemu-img. KubeVirt VMs boot from those PVCs, but CDI works without KubeVirt too.

All seven component images are QuenchWorks-built from source (nonroot, CVE-gated at build, pinned by
digest, cosign-signed): cdi-operator, cdi-controller, cdi-apiserver, cdi-uploadproxy, and the
per-DataVolume cdi-importer (with nbdkit built from source), cdi-uploadserver and cdi-cloner.

## Install

```bash
helm install cdi oci://ghcr.io/quenchworks/charts/cdi-operator -n cdi --create-namespace
kubectl wait cdi cdi --for=condition=Available --timeout=10m
```

The chart installs the CDI CRD, the operator and a CDI resource; the operator then deploys the
controller, API server and upload proxy in the same namespace. CDI is one per cluster.

## Import a disk image

```yaml
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: my-disk
spec:
  source:
    http:
      url: https://example.com/images/disk.qcow2   # qcow2, raw or iso, optionally .gz or .xz
  storage:
    resources:
      requests:
        storage: 10Gi
```

With the default `HonorWaitForFirstConsumer` feature gate and a WaitForFirstConsumer storage class,
the import starts when a pod uses the PVC.

## Values

| Key | Default | Notes |
|---|---|---|
| `images.<component>.repository`, `.digest` | QuenchWorks images | all seven pinned by digest |
| `cdi.create` | `true` | create the CDI resource that deploys CDI |
| `cdi.spec` | feature gate `HonorWaitForFirstConsumer`, linux node selectors | the CDI resource's spec, as written |
| `verbosity` | `1` | klog level of the CDI components |
| `resources` | 100m / 150Mi requests | the operator only |

## Notes

- Uninstall in two steps: `kubectl delete cdi cdi` (the operator removes CDI and the resource's
  finalizer), then `helm uninstall`. The CRD stays, as Helm leaves `crds/` in place.
- HTTP imports go through scratch space: CDI adds a scratch PVC from the same storage class, so
  that class needs room for a second copy during the import.
- VMware (VDDK) imports are not supported: they need VMware's proprietary VDDK library.
- The oVirt and OpenStack populators run from the importer image, as upstream ships them.
