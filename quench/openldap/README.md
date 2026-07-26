# Quenchworks OpenLDAP

Hardened OpenLDAP `slapd` on a minimal, nonroot, 0-CVE image pinned by digest.
A single-instance directory server on the LMDB (`back-mdb`) backend, with its own
PVC, an admin password in a `Secret`, and the base DN seeded on first boot.

## Install

```bash
helm install my-openldap oci://ghcr.io/quenchworks/charts/openldap
```

Bootable as-is: the defaults create `dc=example,dc=org` with a generated admin
password. Set your own suffix and password for anything real:

```bash
helm install my-openldap oci://ghcr.io/quenchworks/charts/openldap \
  --set ldap.baseDN=dc=corp,dc=example \
  --set ldap.organization="Example Corp" \
  --set auth.adminPassword='<password>'
```

## Port 1389, not 389

The container runs as uid 1001, which cannot bind a privileged port, so `slapd`
listens on **1389** (and 1636 for `ldaps`, once you supply TLS material). Point
clients at the Service port; if you need 389 on the wire, remap it at an
upstream `Service`/`LoadBalancer` rather than granting `NET_BIND_SERVICE`.

## How it boots

`slapd` cannot start without a config file, and the config has to carry the
hashed admin password — which lives in a `Secret` the chart may never see (an
`auth.existingSecret`). So an init container does the bootstrap, and it is
idempotent on every restart:

1. Creates the LMDB and pidfile directories on the volume.
2. Renders `slapd.conf` from the ConfigMap template, replacing `__ROOTPW__` with
   `slappasswd -s "$LDAP_ADMIN_PASSWORD"`, into an `emptyDir` shared with `slapd`.
3. **Only when the volume has no `data.mdb`**, creates the database offline with
   `slapadd`, loading the base entry plus `ldap.extraLdif`.

The `slapd` container then execs the binary directly (no shell wrapper) against
that rendered config. The image also carries a working default config at
`/etc/openldap/slapd.conf` so a bare `docker run` works, but the chart never uses
it.

### Why there is a `ulimit -n` in the command

`slapd` sizes its connection table from `RLIMIT_NOFILE` at startup. containerd hands
containers a soft limit of `1073741816`, so an unconstrained `slapd` tries to
allocate roughly 56 GB of connection slots and is OOM-killed before it ever listens
(Docker's own 1M default is small enough to hide the bug, which is why this only
shows up in Kubernetes). The command is therefore
`/bin/sh -c "ulimit -n <ldap.maxOpenFiles>; exec /usr/bin/slapd ..."` — `slapd` is
`exec`ed, so it remains PID 1 and receives signals directly, and the shell exists
only for that one line. `ldap.maxOpenFiles` doubles as the concurrent-connection
ceiling; raise it if you need more than ~4k clients.

### Config format

Config format is the classic single-file `slapd.conf`, not `slapd.d`/`cn=config`.
That is deliberate: a declarative file rendered from values is reproducible and
diffable, whereas a `cn=config` tree is mutable runtime state that would drift
away from the chart on every `ldapmodify`.

## Seeding entries

Only the base entry is created, and only on first boot. Seed the rest at that
same moment with `ldap.extraLdif`:

```yaml
ldap:
  baseDN: dc=example,dc=org
  extraLdif: |
    dn: ou=users,dc=example,dc=org
    objectClass: organizationalUnit
    ou: users

    dn: ou=groups,dc=example,dc=org
    objectClass: organizationalUnit
    ou: groups
```

It is ignored on every later start (the database already exists), so it is a
bootstrap hook, not a reconciler. Add entries afterwards with `ldapadd`.

## Access control

The defaults are a normal directory-service posture: `userPassword` is
write-self / auth-only and never readable, everything else is readable. Tighten
it with `ldap.extraConfig`, which is injected **before** the defaults — `slapd`
stops at the first matching `access to` rule:

```yaml
ldap:
  extraConfig: |
    access to *
      by dn.exact="cn=admin,dc=example,dc=org" write
      by users read
      by * none
```

If you deny anonymous reads, also replace the readiness probe (it is an anonymous
base-scope search on the base DN) with `customReadinessProbe`.

## TLS

Not wired by default — supply the material and the directives yourself:

```yaml
extraVolumes:
  - name: tls
    secret: { secretName: openldap-tls }
extraVolumeMounts:
  - name: tls
    mountPath: /opt/quench/tls
    readOnly: true
ldap:
  extraConfig: |
    TLSCertificateFile     /opt/quench/tls/tls.crt
    TLSCertificateKeyFile  /opt/quench/tls/tls.key
    TLSCACertificateFile   /opt/quench/tls/ca.crt
args: ["-h", "ldap://0.0.0.0:1389/ ldaps://0.0.0.0:1636/", "-f", "/opt/quench/openldap/slapd.conf", "-d", "256"]
```

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/openldap \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Each image also ships an SPDX SBOM and SLSA build provenance as attestations.
Verify them with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/quenchworks/images/openldap \
  --owner quenchworks
```

## Values

| Key | Default | Notes |
|-----|---------|-------|
| `image.repository` | `ghcr.io/quenchworks/images/openldap` | |
| `image.digest` | (CI-written) | Required. Charts pin by digest, never a tag. |
| `ldap.baseDN` | `dc=example,dc=org` | dc-style suffix; the seeded base entry matches it. |
| `ldap.organization` | `QuenchWorks` | `o:` of the base entry. |
| `ldap.maxSize` | `1073741824` | LMDB map size — the hard ceiling on database size. |
| `ldap.logLevel` | `256` | `slapd -d` level; any value keeps it in the foreground. |
| `ldap.maxOpenFiles` | `4096` | `ulimit -n` cap; also the concurrent-connection ceiling. See below. |
| `ldap.extraConfig` | `""` | Extra `slapd.conf` directives, injected before the default ACLs. |
| `ldap.extraLdif` | `""` | LDIF loaded once, on first boot only. |
| `auth.adminUsername` | `admin` | rootdn becomes `cn=admin,<baseDN>`. |
| `auth.adminPassword` | `""` | Generated and stored in a `Secret` if unset. |
| `auth.existingSecret` | `""` | Use your own `Secret` instead. |
| `persistence.enabled` | `true` | 8Gi PVC at `/var/lib/openldap`. |
| `service.port` | `1389` | Unprivileged LDAP port. |
| `serviceAccount.create` | `true` | Token automount is off. |
| `rbac.create` | `false` | Minimal Role/RoleBinding. |
| `networkPolicy.enabled` | `true` | Ingress on `ldap` from the namespace. |
| `podDisruptionBudget.enabled` | `true` | `minAvailable: 1`. |

## Security

Runs nonroot (uid 1001) on a read-only root filesystem with all capabilities
dropped. Only the data volume (`/var/lib/openldap`) and the rendered-config
`emptyDir` are writable; the rendered `slapd.conf` is mode 0600.

## Notes

Single instance by design — the LMDB volume has one writer. Multi-master
replication (`syncrepl` / mirrormode) and `ldaps` termination in-chart are
tracked as follow-ups. There is no metrics exporter yet; `database monitor` is
enabled, so `cn=Monitor` can be scraped by an external collector.
