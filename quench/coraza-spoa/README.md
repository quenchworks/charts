# Quenchworks Coraza SPOA

Hardened [Coraza SPOA](https://github.com/corazawaf/coraza-spoa): the OWASP Coraza web application firewall as an
HAProxy SPOE agent. HAProxy sends each request to the agent and denies what the OWASP Core Rule Set flags (XSS, SQL
injection, scanners, protocol abuse). The CRS is compiled into the image. Static Go built from source, uid 1001 on a
read-only rootfs, CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install waf oci://ghcr.io/quenchworks/charts/coraza-spoa
```

Then point HAProxy's spoe backend at `waf-coraza-spoa.<namespace>:9000`; the chart notes print the frontend and
backend lines (upstream's `example/haproxy` has the full `coraza.cfg`).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `config` | CRS, blocking | The whole `config.yaml`. Use `SecRuleEngine DetectionOnly` to tune a new site before blocking. `bind` must stay on :9000 |
| `replicaCount` | `2` | Stateless; HAProxy spreads SPOE connections across the Service |
| `podDisruptionBudget.enabled` | `true` | Keeps one agent up during drains, since HAProxy answers 500 when the agent is gone (with the example's error rule) |
| `networkPolicy.enabled` | `true` | Ingress allowed on 9000 only, from any namespace (HAProxy usually runs elsewhere) |
