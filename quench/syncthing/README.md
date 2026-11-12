# Quenchworks Syncthing

Hardened [Syncthing](https://github.com/syncthing/syncthing), continuous peer-to-peer file
synchronisation, CVE-gated, cosign-signed and pinned by digest. The image is built from source
(CGO-free, self-upgrade off) on a nonroot Wolfi base.

## Install

```bash
helm install syncthing oci://ghcr.io/quenchworks/charts/syncthing
kubectl port-forward svc/syncthing 8384
```

Log in as `admin` with the generated password:

```bash
kubectl get secret syncthing -o jsonpath='{.data.password}' | base64 -d
```

An init container sets the GUI user and password in `config.xml` on every start, so the Secret
stays the source of truth. The same Secret holds the REST API key (`api-key`, header `X-API-Key`).

## Storage

Everything lives on one volume at `/var/syncthing`: config, device key, database, and folders
(default location `/var/syncthing/<folder>`). The device ID comes from the key on that volume, so
keep it. The Deployment runs one replica with `Recreate`.

## Reaching peers

Sync runs on 22000 over TCP (TLS) and UDP (QUIC) through the Service `<fullname>-sync`. Set
`syncService.type: LoadBalancer` (or NodePort) so peers outside the cluster connect directly;
on ClusterIP Syncthing still reaches remote peers through the public relays. The GUI Service
stays ClusterIP: put an Ingress or a port-forward in front of it.

## TLS

`tls.enabled` serves the GUI and REST API over HTTPS on 8384 with a certificate from
`tls.existingSecret`, else a cert-manager `Certificate`, else a Helm-generated CA (`ca.crt` in
the Secret `<fullname>-tls`). Syncthing reads it as `https-cert.pem` / `https-key.pem` in its
config directory. Device-to-device traffic is always TLS with the device key.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/syncthing \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `gui.user` | `admin` | GUI user |
| `gui.password` / `gui.apiKey` / `gui.existingSecret` | generated | GUI password and REST API key |
| `settings` | `{}` | More `ST*` environment variables |
| `persistence.size` | `10Gi` | The `/var/syncthing` volume |
| `service.guiPort` | `8384` | GUI and REST API Service port |
| `service.syncPort` | `22000` | Sync Service port (TCP + UDP) |
| `syncService.type` | `ClusterIP` | Sync Service type; LoadBalancer for direct outside peers |
| `tls.enabled` | `false` | HTTPS on the GUI |
| `tls.existingSecret` | `""` | a `kubernetes.io/tls` Secret to use (1st choice) |
| `tls.certManager.enabled` | `false` | request a cert-manager `Certificate` (2nd choice) |
| `tls.selfSigned.validityDays` | `365` | otherwise Helm generates a CA + certificate, kept across upgrades |
