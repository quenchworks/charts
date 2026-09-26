# secrets-stack

OpenBao (the open-source Vault fork) behind Keycloak sign-in, ready on first start:

- **OpenBao** auto-unseals with a static seal key and configures itself once, on first
  start (declarative self-initialization):
  - `secret/`: KV v2. The `secrets-user` policy covers `secret/shared/*`.
  - `auth/oidc`: people sign in through Keycloak, role `user`.
  - `auth/jwt`: workloads log in with Keycloak client-credentials tokens (audience
    `openbao`), role `machine`.
  - `auth/userpass`: a break-glass `admin` with the `admin` policy.
- **Keycloak** imports a `secrets` realm with the confidential `openbao` client, and
  runs on the bundled PostgreSQL.

Every component is a QuenchWorks chart on a hardened, nonroot, 0-CVE image, pinned by
digest and cosign-signed.

## Install

```sh
helm install sec oci://ghcr.io/quenchworks/charts/secrets-stack
kubectl port-forward svc/sec-openbao 8200:8200
export BAO_ADDR=http://127.0.0.1:8200
bao login -method=oidc role=user
```

The install NOTES print the workload (JWT) and break-glass commands.

## How it fits together

- **Seal key.** `secrets-stack-openbao` holds the 32-byte static seal key, the admin
  password and the Keycloak client secret. They are generated once and read back on
  upgrade. The Secret carries `helm.sh/resource-policy: keep`: **back it up**, because
  without the seal key the stored data cannot be decrypted. See OpenBao's static
  seal notes before using it where a KMS is available.
- **Issuer.** `keycloak.production.hostname` is the token issuer, and the stack builds
  OpenBao's discovery URL from the same value, so they cannot disagree. The default is
  the in-cluster Service (`http://secrets-keycloak:8080`). For browser sign-in, set it
  to a public URL that both browsers and the OpenBao pod can reach, add that
  deployment's UI callback to `realm.redirectUris`, and set
  `keycloak.production.proxyHeaders` behind an ingress.
- **Start order.** Self-init runs once, and writing `auth/oidc/config` fetches the
  realm's discovery document. An init container (bash `/dev/tcp`, in the keycloak
  image) therefore holds OpenBao until the realm answers.
- **Fixed names.** `secrets-keycloak` and `secrets-stack-*`, so one stack per namespace.

## Values

Each component takes its own chart's values under `keycloak.*` and `openbao.*`.

| Key | Default | Meaning |
|---|---|---|
| `realm.redirectUris` | `[http://localhost:8250/oidc/callback]` | OIDC callbacks (the bao CLI; add your UI's) |
| `realm.users` | `[]` | optional realm users `{username, password}` for a demo |
| `keycloak.production.hostname` | `http://secrets-keycloak:8080` | the issuer; see above |

Self-initialization runs only on first start. Later changes to the auth setup are
made through OpenBao's API, as the admin.

## Release gate

On kind, the gate checks:
1. OpenBao reports initialized and unsealed.
2. A Keycloak client-credentials token logs in through JWT.
3. A secret under `secret/shared` is written and read back, and a write outside it is
   denied.
4. OIDC produces a Keycloak authorize URL.
5. The break-glass admin logs in.
6. After OpenBao's pod is deleted, it comes back unsealed with the secret intact.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
