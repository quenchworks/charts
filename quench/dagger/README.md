# Quenchworks Dagger

Hardened [Dagger](https://github.com/dagger/dagger), the programmable CI/CD engine that runs
pipelines as code in containers, on a CVE-gated image built from source on Wolfi, cosign-signed
and pinned by digest. This chart runs the Dagger engine as a StatefulSet with a persistent cache;
your `dagger` CLI connects to it through the Kubernetes API.

The image follows upstream's engine layout: the engine, runc, the CNI plugins and the CLI are
built from source with current dependencies, and the Go SDK runtime the engine runs Go modules in
is assembled on Wolfi and scanned on its own. The Python and TypeScript SDK runtimes are not
bundled yet; modules on those SDKs do not load on this engine.

## Install

```bash
helm install dagger oci://ghcr.io/quenchworks/charts/dagger
```

## Use it

Use a `dagger` CLI of the same minor version as the engine (the chart's appVersion):

```bash
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://dagger-0?namespace=default&container=dagger"
dagger core version
dagger -c 'container | from alpine | with-exec -- echo hello | stdout'
```

The CLI ships in the image too: `kubectl exec dagger-0 -- dagger core version`.

## Security

The engine runs containers itself (runc, CNI networking, cgroup nesting), so like upstream's
engine it runs as root in a privileged container. Anyone who can exec into the pod can run any
container on its node: limit `pods/exec` on this namespace to the people and CI identities that
run pipelines, and schedule the engine on nodes meant for build workloads (`nodeSelector`,
`tolerations`). The engine has no network listener; the NetworkPolicy admits no ingress.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `persistence.enabled` | `true` | Keep `/var/lib/dagger` (cache, images, client databases) on a PVC |
| `persistence.size` | `50Gi` | Size of that PVC |
| `config` | `""` | `engine.toml` contents, mounted at `/etc/dagger/engine.toml` |
| `extraArgs` | `[]` | Extra `dagger-engine` flags, for example `--debug` |
| `terminationGracePeriodSeconds` | `300` | Time the engine gets to finish running pipelines on shutdown |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/dagger \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
