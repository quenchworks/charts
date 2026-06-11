# Quenchworks charts

Clean-room Helm charts for the [Quenchworks](https://github.com/quenchworks) catalog. Each chart
pins its image by `sha256` digest to a signed, 0-CVE image from the
[images](https://github.com/quenchworks/images) factory, and is published as an OCI artifact to
GHCR and listed on ArtifactHub.

## Layout

```
quench/<app>/             one app chart per directory, e.g. quench/redis
.github/workflows/        release (lint, install, package, push) and digest repin
```

> The shared `quench-common` library chart lives in its own repo,
> [quenchworks/common](https://github.com/quenchworks/common), and is published as an OCI artifact at
> `oci://ghcr.io/quenchworks/charts/quench-common`. App charts depend on it via
> `repository: oci://ghcr.io/quenchworks/charts` and pull it at build time, so it is no longer
> vendored in this repo.

## Install a chart

```bash
helm install my-redis oci://ghcr.io/quenchworks/charts/redis
```

## How releases work

The image factory builds and signs an image, then sends an `image-published` dispatch to this repo.
`on-digest.yml` repins the chart's `values.yaml` to the new digest and commits. The push triggers
`release-<app>.yml`, which lints, templates, installs into kind, packages, and pushes the OCI chart.

## The clean-room rule

Charts here are written from each application's own upstream documentation. They are not copied or
adapted from any other vendor's charts. See
[CONTRIBUTING](https://github.com/quenchworks/.github/blob/main/CONTRIBUTING.md).

## License

MIT.
