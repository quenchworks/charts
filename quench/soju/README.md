# Quenchworks soju

Hardened [soju](https://codeberg.org/emersion/soju), an IRC bouncer: it stays connected to your
networks, keeps the history and plays it back to every client you use (desktop, phone, web). Users,
networks and messages live in SQLite on a volume. The image is built from source (pure Go, modernc
SQLite); it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install bouncer oci://ghcr.io/quenchworks/charts/soju --set hostname=bouncer.example.com --set tls.enabled=true
kubectl get secret bouncer-soju -o jsonpath='{.data.password}' | base64 -d   # user admin
```

Connect your client to port 6667 (or 6697 with TLS) as `admin` with that password, then add networks by
messaging BouncerServ:

```
/msg BouncerServ network create -addr ircs://irc.libera.chat -name libera
```

and reconnect as `admin/libera`. With the Ergo chart in the same namespace: `-addr irc+insecure://irc-ergo:6667`.
The Lounge chart can point at soju too (`defaults.host=bouncer-soju`, user `admin/<network>`).

## Configuration

| Key | Default | What it does |
|---|---|---|
| `hostname` | required | The bouncer's host name |
| `admin.username` | `admin` | The admin the chart creates and keeps in step with the Secret |
| `admin.existingSecret` | `""` | A Secret with key `password` |
| `extraConfig` | `""` | More soju directives, e.g. `max-user-networks 5` |
| `tls.enabled` | `false` | IRC over TLS on 6697 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `2Gi` | Users, networks and history |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/soju \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
