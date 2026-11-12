# Quenchworks sish

Hardened [sish](https://github.com/antoniomika/sish): self-hosted HTTP(S), WebSocket and TCP
tunnels over plain SSH. A developer runs `ssh -R app:80:localhost:3000` against sish and gets
`app.<your domain>` pointing at their laptop, with no client to install. The image is built from
source, runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install tun oci://ghcr.io/quenchworks/charts/sish --set domain=tunnel.example.com \
  --set-file 'auth.authorizedKeys[0]=~/.ssh/id_ed25519.pub' --set service.type=LoadBalancer
ssh -p 2222 -R app:80:localhost:3000 <load balancer address>
```

Point a wildcard DNS record `*.tunnel.example.com` at the Service (or an Ingress in front of
port 8080). The SSH host key is generated once into a Secret and kept across upgrades, so
clients keep trusting the server.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `domain` | `tunnel.example.com` | Base domain; tunnels are served at `<name>.<domain>` |
| `auth.enabled` | `true` | Require an authorized SSH key |
| `auth.authorizedKeys` | `[]` | OpenSSH public keys allowed to open tunnels |
| `auth.existingSecret` | `""` | A Secret of public keys instead of the list |
| `randomSubdomains` | `false` | Hand out random subdomains instead of the requested one |
| `extraArgs` | `[]` | More `sish` flags (`--idle-connection-timeout`, `--tcp-aliases`) |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/sish \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
