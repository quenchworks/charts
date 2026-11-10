# Quenchworks zabbix

[Zabbix](https://www.zabbix.com) server and web frontend with a bundled PostgreSQL, on
minimal, nonroot, CVE-gated images built from source and pinned by digest.

## Install

```sh
helm install zabbix oci://ghcr.io/quenchworks/charts/zabbix
kubectl port-forward svc/zabbix-web 8080:8080
```

Open http://127.0.0.1:8080/ and log in as `Admin` with the generated password:

```sh
kubectl get secret zabbix-db -o jsonpath='{.data.admin-password}' | base64 -d
```

On first install an init container loads the schema of the same Zabbix release and
replaces upstream's `Admin`/`zabbix` password. Later restarts and upgrades find the schema
and load nothing; the server upgrades its own tables between versions. Agents and senders
reach the server at `<release>-zabbix-server:10051`.

## Verify the images

```sh
cosign verify ghcr.io/quenchworks/images/zabbix-server \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation
(`gh attestation verify oci://ghcr.io/quenchworks/images/zabbix-server --owner quenchworks`).

## Configuration

| Key | Default | Meaning |
|---|---|---|
| `admin.password` | generated | The `Admin` password set on first install (kept in the `zabbix-db` Secret). |
| `server.config` | `{}` | Extra `zabbix_server.conf` settings, e.g. `StartPollers: 10`. |
| `web.replicaCount` | `1` | Frontend replicas. The server always runs one replica. |
| `web.serverName` | `""` | Name shown in the frontend title. |
| `postgresql.primary.persistence.size` | `8Gi` | Database volume. |
| `web.service.httpsPort` | `8443` | web HTTPS (pod 8443), only with `tls.enabled` |
| `tls.enabled` | `false` | the web frontend's nginx also serves HTTPS on 8443 beside HTTP (cert at `/tls`); server port unchanged |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` from `tls.certManager.issuerRef` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate, kept across upgrades |

The database Secret (`zabbix-db`) and PostgreSQL (`zabbix-postgresql`) have fixed names,
so install one release per namespace. SNMP checks are not available: the server image is
built without net-snmp, because Wolfi's has no MD5 and Zabbix requires it.
