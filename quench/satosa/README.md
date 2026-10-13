# Quenchworks SATOSA

Hardened [SATOSA](https://github.com/IdentityPython/SATOSA), the IdentityPython proxy
that translates between SAML2 and OpenID Connect or OAuth2, so services and identity
providers that speak different protocols can federate. Runs on a minimal, nonroot,
0-CVE image (the official wheel under gunicorn on Wolfi Python, with xmlsec1 for SAML
signatures), cosign-signed and pinned by digest.

## Install

```bash
helm install proxy oci://ghcr.io/quenchworks/charts/satosa \
  --set baseUrl=https://proxy.example.com
```

The default config is a SAML2 service provider backend plus the ping frontend, enough
to boot and to publish SP metadata:

```bash
kubectl port-forward svc/proxy-satosa 8080:8080
curl http://127.0.0.1:8080/ping
curl http://127.0.0.1:8080/Saml2/metadata.xml
```

A real deployment sets `config.proxyConf` to its own `proxy_conf.yaml` with the
frontends its services use (SAML2 IdP, OpenID Connect provider) and the backends for
its identity providers.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/satosa \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each build also ships an SPDX SBOM and SLSA provenance attestation. Verify them with
`gh attestation verify oci://ghcr.io/quenchworks/images/satosa --owner quenchworks`.

## Values

| Key | Default | Notes |
| --- | --- | --- |
| `image.repository` | `ghcr.io/quenchworks/images/satosa` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `image.pullPolicy` | `IfNotPresent` | |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `replicaCount` | `1` | Stateless Deployment (ignored when autoscaling is on). |
| `workers` | `2` | gunicorn worker processes per pod. |
| `extraArgs` | `[]` | Extra gunicorn flags. |
| `baseUrl` | `""` | SATOSA `BASE`, the public URL. Empty uses the in-cluster Service URL. |
| `config.proxyConf` | `""` | Full `proxy_conf.yaml` (templated). Empty uses the default SAML2 SP + ping config. |
| `config.internalAttributes` | `mail` map | `INTERNAL_ATTRIBUTES` of the default config. |
| `config.idpMetadata` | `{local: []}` | pysaml2 metadata sources of the default config. |
| `config.extraFiles` | `{}` | Extra files next to `proxy_conf.yaml` in `/etc/satosa/config` (plugin configs, metadata). |
| `config.existingConfigMap` | `""` | Your own ConfigMap (key `proxy_conf.yaml`); wins over the above. |
| `stateEncryption.key` | `""` | State cookie key. Empty generates one, kept across upgrades. |
| `stateEncryption.existingSecret` | `""` | Secret with key `state-encryption-key`. |
| `samlKeyPair.existingSecret` | `""` | `kubernetes.io/tls` Secret with the SAML key pair. Empty generates a self-signed pair, kept across upgrades. |
| `resources.requests` | `cpu 50m / mem 128Mi` | |
| `resources.limits` | `cpu 500m / mem 512Mi` | |
| `service.type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `service.port` | `8080` | |
| `autoscaling.enabled` | `false` | HPA on CPU (autoscaling/v2). |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Restricts ingress to the HTTP port. |
| `networkPolicy.allowExternal` | `true` | Set `false` to restrict ingress to the release namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |
| `ingress.enabled` | `false` | Create an Ingress (HTTP only). Set `baseUrl` to its URL. |

Plus the shared `quench-common` knobs (scheduling, probes, sidecars, init containers,
extra env/volumes, security contexts, update strategy).

## Architecture

A stateless Deployment runs `gunicorn satosa.wsgi:app` on container port 8080. SATOSA
keeps each login's state in an encrypted cookie, so replicas need only share two
Secrets: the state encryption key (passed as `SATOSA_STATE_ENCRYPTION_KEY`) and the
SAML key pair (mounted at `/etc/satosa/saml/tls.{key,crt}`). The chart generates both
on first install and keeps them on upgrade. `proxy_conf.yaml` and `config.extraFiles`
are mounted read-only at `/etc/satosa/config`. Liveness and readiness probe `/ping`,
the ping frontend of the default config: a custom `proxyConf` keeps one or overrides
the probes. The container runs nonroot on a read-only root filesystem with all
capabilities dropped; `/tmp` is an emptyDir for gunicorn and the xmlsec1 temp files.

## Configuration example

A SAML2 IdP frontend in front of an upstream SAML2 IdP:

```yaml
baseUrl: https://proxy.example.com
config:
  extraFiles:
    idp.xml: |
      <EntityDescriptor ...>...</EntityDescriptor>
  proxyConf: |
    BASE: {{ .Values.baseUrl }}
    COOKIE_STATE_NAME: SATOSA_STATE
    INTERNAL_ATTRIBUTES: /etc/satosa/config/internal_attributes.yaml
    BACKEND_MODULES:
      - /etc/satosa/config/saml2_backend.yaml
    FRONTEND_MODULES:
      - /etc/satosa/config/saml2_frontend.yaml
      - module: satosa.frontends.ping.PingFrontend
        name: ping
        config: {}
```

## Uninstall

```bash
helm uninstall proxy
```

The generated Secrets go with the release. Nothing else persists.
