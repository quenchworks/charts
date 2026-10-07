# Quenchworks registry-stack

One self-hosted artifact registry in one install:

- [Harbor](https://goharbor.io) stores container images, OCI Helm charts and any OCI
  artifact, with projects, robot accounts, replication and Trivy vulnerability scanning.
- [Terralist](https://www.terralist.io) is a private Terraform and OpenTofu registry for
  modules and providers, speaking the registry protocols `terraform init` uses.

Every image is minimal, nonroot, 0-CVE, cosign-signed and pinned by digest. The two are
independent services in one release; values under `harbor` and `terralist` pass straight
through to the [harbor](../harbor) and [terralist](../terralist) charts.

## Install

Both need the public URL their clients use, and Terralist needs an OAuth provider for
logins (GitHub shown; see the terralist chart for the others):

```bash
helm install reg oci://ghcr.io/quenchworks/charts/registry-stack -n registry --create-namespace \
  --set harbor.externalURL=https://harbor.example.com \
  --set harbor.ingress.host=harbor.example.com \
  --set terralist.url=https://modules.example.com \
  --set terralist.oauth.provider=github \
  --set terralist.oauth.clientId=<id> --set terralist.oauth.clientSecret=<secret>
```

Harbor's own Ingress (Traefik class) is on by default; Terralist's is `terralist.ingress`.

| Key | Meaning |
|---|---|
| `harbor.externalURL` | Address docker and helm clients use; tokens are minted for it |
| `harbor.ingress.*` | Harbor's front door |
| `terralist.enabled` | Install Terralist (default `true`) |
| `terralist.url` | Address terraform and tofu use; download links point here |
| `terralist.oauth.*` | Login provider |
