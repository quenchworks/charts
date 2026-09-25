# WireMock

[WireMock](https://wiremock.org) is an HTTP API mock server: stubs with request matching,
handlebars response templating, proxying and recording, fault injection, a request
journal and an admin API. This chart runs it on the QuenchWorks wiremock image, which is
built on Jetty 12 from WireMock's unshaded artifacts so every bundled library is scanned.
The image is nonroot, 0 fixable CVEs, cosign-signed and pinned by digest.

## Install

```sh
helm install wiremock oci://ghcr.io/quenchworks/charts/wiremock -f stubs.yaml
kubectl port-forward svc/wiremock 8080:8080
curl http://127.0.0.1:8080/__admin/mappings
```

`stubs.yaml`:

```yaml
mappings:
  hello.json:
    request: { method: GET, urlPath: /hello }
    response: { status: 200, body: "hi {{request.query.name}}", transformers: [response-template] }
files:
  big.json: '{"items": []}'     # served by a stub with bodyFileName: big.json
```

`mappings` becomes WireMock's `mappings/` directory and `files` its `__files/`, loaded at
start (a change rolls the pods). Stubs added through the admin API live in memory only.

## Security

The admin API (`/__admin`) is open to anyone who reaches the Service and can add, change
and delete stubs, or turn WireMock into a proxy. Keep the Service internal to test
environments.

## Values

| Key | Default | Meaning |
|---|---|---|
| `mappings` | `{}` | stub files, name to JSON object or string |
| `files` | `{}` | response body files |
| `globalResponseTemplating` | `false` | template every response |
| `https.enabled` | `false` | HTTPS on 8443 (self-signed; HTTP/2 over TLS) |
| `extraArgs` | `[]` | more WireMock flags |
| `replicas` | `1` | each replica has its own admin stubs and journal |

Pods run with a read-only root filesystem and all capabilities dropped.

The release gate installs the chart on kind with two stubs and a body file from values,
and requires exactly two stubs loaded, the templated and file responses, a stub added
through the admin API, HTTPS over HTTP/2 and the calls in the request journal.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
