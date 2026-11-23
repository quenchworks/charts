# EJBCA

[EJBCA Community Edition](https://www.ejbca.org), Keyfactor's open-source PKI: certificate authorities, registration,
CRLs and OCSP, with SCEP, CMP, web services and REST endpoints. It runs on WildFly with its database in the bundled
PostgreSQL. The image is built from source by QuenchWorks, CVE-gated, signed with cosign and pinned by digest.

## Install

```sh
helm install ejbca oci://ghcr.io/quenchworks/charts/ejbca
```

The first start creates the database tables and takes a few minutes. The startup probe waits up to 10 minutes.

## Administer

Run the EJB CLI inside the pod. It reaches the server over loopback (port 4447), which is not exposed outside the pod.

```sh
kubectl exec deploy/ejbca -- ejbca ca init --caname MyCA --dn "CN=MyCA" --tokenType soft --tokenPass null \
  --keytype RSA --keyspec 3072 -v 3650 --policy null -s SHA256WithRSA
kubectl exec deploy/ejbca -- ejbca ca listcas
```

The admin and RA web UIs require client-certificate TLS, which this chart does not configure yet.

## Values

| Key | Default | Meaning |
|---|---|---|
| `postgresql.enabled` | `true` | Bundled PostgreSQL. Set `false` and fill `externalDatabase` to use your own. |
| `externalDatabase.host`, `.port`, `.database`, `.username` | `""`, `5432`, `ejbca`, `ejbca` | External PostgreSQL. |
| `externalDatabase.existingSecret` | `""` | Secret holding the password (key `externalDatabase.existingSecretPasswordKey`). |
| `javaOpts` | `""` | Extra JVM options for WildFly. |
| `resources` | 1Gi request, 3Gi limit | The JVM needs about 1.5Gi at steady state. |
| `ingress.*` | off | Ingress for the public endpoints. Terminate TLS there. |
| `networkPolicy.enabled` | `true` | Allows 8080 in, DNS and PostgreSQL out. |

Plain HTTP: put TLS in front with an Ingress before exposing the service.
