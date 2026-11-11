# Quenchworks Kroxylicious

Hardened [Kroxylicious](https://github.com/kroxylicious/kroxylicious), a Kafka protocol proxy
that sits between Kafka clients and brokers and runs filters on the traffic (record
encryption, record validation, multi-tenancy), on a minimal, shell-free, nonroot, CVE-gated
image, cosign-signed and pinned by digest. It runs as a stateless Deployment on a read-only
rootfs.

## Install

```bash
helm install kproxy oci://ghcr.io/quenchworks/charts/kroxylicious \
  --set targetCluster.bootstrapServers=my-kafka.kafka.svc.cluster.local:9092
```

Clients then bootstrap through the proxy instead of the brokers:

```properties
bootstrap.servers=kproxy-kroxylicious.default.svc.cluster.local:9192
```

## How brokers are reached

The gateway uses port-identifies-node: clients bootstrap on `gateway.bootstrapPort` (9192),
and the proxy rewrites every broker address in Kafka metadata to its own Service name, one port
per broker after the bootstrap port (9193, 9194, ...). The ports follow `gateway.nodeIdRanges`
in order, and the ranges must cover every `node.id` in the target cluster:

```yaml
gateway:
  nodeIdRanges:
    - name: brokers
      start: 0
      end: 5        # six brokers, ports 9193-9198
```

`gateway.advertisedHost` overrides the name handed to clients (for example a LoadBalancer or
external DNS name).

## Filters

`filterDefinitions` and `defaultFilters` go into the config verbatim:

```yaml
filterDefinitions:
  - name: validate
    type: RecordValidation
    config:
      rules:
        - topicNames: [orders]
          valueRule:
            syntacticallyCorrectJson: {}
defaultFilters: [validate]
```

For anything the values do not cover, `config.raw` replaces the whole proxy config (keep
management on 9190 and the gateway ports in step with the Service).

## TLS

`tls.enabled=true` makes the gateway speak TLS with the chart certificate: a Helm-generated
one by default, `tls.existingSecret`, or cert-manager (`tls.certManager.enabled`). Clients set
`security.protocol=SSL` and trust `ca.crt` from the TLS Secret. A busybox init container writes
the PKCS#8 copy of the key the proxy's TLS stack reads.

## Monitoring

The management port (9190) serves `/livez` (used by the probes) and Prometheus metrics at
`/metrics`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/kroxylicious \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
