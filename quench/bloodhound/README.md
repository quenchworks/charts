# Quenchworks BloodHound CE

Hardened [BloodHound Community Edition](https://github.com/SpecterOps/BloodHound): attack-path analysis for Active
Directory and Entra ID. SharpHound and AzureHound collect the data; BloodHound maps it as a graph and shows the paths
an attacker could take to privileged accounts. The image builds the Go API from the release tag with the React UI
embedded, runs as uid 1001 on a read-only root filesystem, and is CVE-gated at build, cosign-signed and pinned by
digest. The collector binaries are not bundled: download them from their GitHub releases.

The chart keeps both the application data and the graph in the bundled QuenchWorks PostgreSQL (BloodHound's pg
graph driver), so no Neo4j is needed. It generates the admin password once and can serve native TLS.

## Install

```bash
helm install bloodhound oci://ghcr.io/quenchworks/charts/bloodhound -n bloodhound --create-namespace \
  --set rootURL=https://bloodhound.example.com/
```

Sign in at `/ui/` as `admin` with the password from the chart Secret (see the install notes). Only analyze
environments you are authorized to assess.

## Configuration

| Value | Default | Notes |
|---|---|---|
| `rootURL` | `""` | Public URL (`bhe_root_url`); defaults to the Service URL |
| `admin.password` | `""` | Generated when empty |
| `admin.expireNow` | `false` | Force a password change at first sign-in |
| `workSizeLimit` | `10Gi` | Upload staging space |
| `postgresql.enabled` | `true` | Or `externalDatabase.*` (needs pg_trgm) |
| `settings` | `{}` | More `bhe_*` settings |
| `tls.enabled` | `false` | HTTPS on 8080 from `tls.existingSecret`, cert-manager, or a Helm-made CA |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/bloodhound \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
