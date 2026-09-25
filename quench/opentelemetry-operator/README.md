# OpenTelemetry Operator

The [OpenTelemetry Operator](https://opentelemetry.io/docs/platforms/kubernetes/operator/)
runs OpenTelemetry Collectors from `OpenTelemetryCollector` resources (as deployments,
daemonsets, statefulsets or sidecars), scales Prometheus scraping with the target
allocator, and injects auto-instrumentation into pods through `Instrumentation`
resources. This chart runs the operator on the QuenchWorks opentelemetry-operator image.
The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install otel-operator oci://ghcr.io/quenchworks/charts/opentelemetry-operator -n otel-operator --create-namespace
```

Collectors that name no image run the QuenchWorks collector (the contrib distribution,
`collector.image`). A collector's own `spec.image` still wins.

## Certificates

The operator's admission and CRD-conversion webhooks need TLS. The chart issues a CA and
serving certificate itself (no cert-manager), injects the CA into both webhook
configurations and the `OpenTelemetryCollector` conversion webhook, and reuses the same
Secret on upgrade.

## Default images

The target allocator, OpAMP bridge and auto-instrumentation images default to upstream's,
at the versions this operator release pins. They are not QuenchWorks images. Set them in
`images` (operator flag names) to use your own.

## Values

| Key | Default | Meaning |
|---|---|---|
| `collector.image` | the QuenchWorks otel-collector | default collector image |
| `images.*` | `""` | other default images, as operator flags |
| `podMutationFailurePolicy` | `Ignore` | pod injection webhook when the operator is down |
| `replicas` | `1` | leader election above 1 |

The CRDs are templates (the collector CRD's conversion webhook needs the chart's CA), kept
on uninstall so collectors and Instrumentation resources survive. Pods run with a read-only
root filesystem and all capabilities dropped.

The release gate installs the chart on kind, creates a collector with no image of its own
and requires the operator to run it on the QuenchWorks collector, reads it back through
the conversion webhook, has the validating webhook reject an invalid collector, and sends
a span through the collector.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
