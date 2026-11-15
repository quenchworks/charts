# Quenchworks GLAuth

Hardened [GLAuth](https://github.com/glauth/glauth), a lightweight LDAP server: users and groups
come from its config, with bcrypt or SHA-256 passwords, TOTP and per-user capabilities, for apps
that only speak LDAP. The image is one static Go binary built from source; it runs as uid 1001 and
is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install ldap oci://ghcr.io/quenchworks/charts/glauth --set baseDN=dc=example,dc=com
kubectl get secret ldap-glauth-config -o jsonpath='{.data.admin-password}' | base64 -d
```

Apps bind as `cn=admin,ou=admins,dc=example,dc=com` (a search-capable service account) and find
users under the base DN. Add users and groups as TOML in `extraConfig`; a user's DN is
`cn=<name>,ou=<primary group name>,<baseDN>`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `baseDN` | `dc=glauth,dc=com` | The directory root |
| `admin.username`, `admin.password` | `admin`, generated | The search service account (`passsha256` of the password) |
| `extraConfig` | `""` | Your `[[users]]` and `[[groups]]` as GLAuth TOML |
| `service.port` | `389` | Service port (GLAuth listens on 3893) |

Passwords in `extraConfig` can be `passbcrypt` (the hex of a bcrypt string) or `passsha256`. The
config is rendered into a Secret. Plain LDAP is unencrypted: keep it inside the cluster.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/glauth \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
