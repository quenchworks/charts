# Quenchworks croc relay

A self-hosted relay for hardened [croc](https://github.com/schollz/croc): croc sends files and
folders between two computers with a code phrase, end-to-end encrypted with PAKE, and the relay is
where the two sides meet when they cannot reach each other directly. The image is one static Go
binary built from source (relay and CLI); it runs as uid 1001 and is CVE-gated at build,
cosign-signed and pinned by digest.

## Install

```bash
helm install relay oci://ghcr.io/quenchworks/charts/croc --set service.type=LoadBalancer
kubectl get secret relay-croc -o jsonpath='{.data.password}' | base64 -d
```

```bash
CROC_RELAY=<relay-host>:9009 CROC_PASS=<password> CROC_SECRET=<code-phrase> croc send FILE
CROC_RELAY=<relay-host>:9009 CROC_PASS=<password> CROC_SECRET=<code-phrase> croc
```

croc speaks raw TCP on five ports (9009 to 9013 by default): clients dial the first and are handed
the others, so expose all of them with a LoadBalancer or NodePort Service, not an HTTP ingress.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `relay.basePort`, `relay.portCount` | `9009`, `5` | The relay ports (`CROC_PORTS`); the Service keeps the same numbers |
| `relay.password` | generated | `CROC_PASS`; clients without it are refused |
| `relay.existingSecret` | `""` | A Secret with key `password` instead |
| `settings` | `{}` | More relay env (`CROC_MAX_ROOMS_OPEN`, `CROC_SOURCE_JOIN_LIMIT`) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/croc \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
