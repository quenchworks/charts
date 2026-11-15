# Quenchworks Ergo

Hardened [Ergo](https://github.com/ergochat/ergo), a modern IRC server with integrated services
(NickServ accounts, ChanServ channel registration), bouncer features (always-on clients, history
playback) and IRCv3. The image is built from source (pure Go); it runs as uid 1001 and is CVE-gated at
build, cosign-signed and pinned by digest.

## Install

```bash
helm install irc oci://ghcr.io/quenchworks/charts/ergo --set serverName=irc.example.com --set tls.enabled=true
kubectl get secret irc-ergo -o jsonpath='{.data.oper-password}' | base64 -d
```

The chart runs the image's config (upstream's defaults) with a few `ERGO__*` overrides: the network and
server names, the listeners, and the operator password. Upstream's sample config ships a well-known
operator password hash; the image replaces it with the hash of a random throwaway password, and the chart
sets a generated one you can read from the Secret.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `serverName` | required | The server's host name |
| `networkName` | `QuenchIRC` | The network name shown to clients |
| `oper.existingSecret` | `""` | A Secret with `oper-password` and `oper-password-hash` (bcrypt) |
| `tls.enabled` | `false` | IRC over TLS on 6697 (existing Secret, cert-manager or a Helm-made CA) |
| `persistence.size` | `2Gi` | Accounts, channel registrations and history |
| `settings` | `{}` | More `ERGO__*` overrides, e.g. `ERGO__ACCOUNTS__REGISTRATION__ENABLED: "false"` |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/ergo \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
