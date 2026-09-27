# Quenchworks backup-stack

Kubernetes backup and restore in one install, from QuenchWorks images (nonroot,
0 fixable CVEs, pinned by digest, cosign-signed):

| Component | Chart / image | Role |
|---|---|---|
| Velero | `velero` | backs up and restores namespaces and resources |
| Velero AWS plugin | `velero-plugin-for-aws` image | talks to any S3-compatible store |
| SeaweedFS | `seaweedfs` | the S3 store the backups go to |

The stack generates the S3 keys (Secret `backup-s3`), creates the `velero`
bucket with a Job, and configures Velero's default backup location on it.

## Install

```bash
helm install backup oci://ghcr.io/quenchworks/charts/backup-stack
kubectl get backupstoragelocation default   # PHASE Available
```

Then create `Backup`, `Restore` and `Schedule` resources in the release
namespace (or use the `velero` CLI against it).

## Values

| Key | Default | Notes |
|---|---|---|
| `velero.backupStorageLocation.*` | S3 on backup-seaweedfs | point elsewhere to keep backups outside the cluster |
| `seaweedfs.persistence.size` | `50Gi` | the backup store |
| `bucketJob.enabled` | `true` | creates the `velero` bucket |

## Notes

- The default store is in the same cluster: it covers mistakes and namespace
  loss, not the loss of the cluster itself. For disaster recovery, set the backup
  location to storage elsewhere or replicate the bucket.
- Resource backups work out of the box. Volume data needs Velero's node agent
  or CSI snapshots, which this stack does not configure.
