# Quenchworks draw.io

Hardened [draw.io](https://github.com/jgraph/drawio): the diagramming web app (flowcharts, architecture,
UML, network diagrams), self-hosted. Diagrams are edited in the browser and saved to the user's device;
the server only serves static files. The image unpacks upstream's official draw.war (without the
WEB-INF servlets and jars) and serves it with Wolfi nginx; it runs as uid 1001 and is CVE-gated at
build, cosign-signed and pinned by digest.

## Install

```bash
helm install diagrams oci://ghcr.io/quenchworks/charts/drawio
kubectl port-forward svc/diagrams-drawio 8080:8080   # open http://127.0.0.1:8080/
```

## Configuration

| Key | Default | What it does |
|---|---|---|
| `replicaCount` | `2` | Stateless replicas |
| `tls.enabled` | `false` | HTTPS on 8080 (existing Secret, cert-manager or a Helm-made CA) |

The usual production knobs (resources, probes, network policy, PDB, scheduling) are in `values.yaml`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/drawio \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
