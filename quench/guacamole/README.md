# guacamole

Apache Guacamole, clientless remote desktop in the browser for RDP, VNC, SSH and
telnet hosts, in one install:
- **the web app** (Tomcat 9), which users open at `/guacamole/`;
- **guacd**, the proxy daemon that speaks each remote protocol;
- **PostgreSQL**, for users, connections and history (QuenchWorks postgresql chart).

Every image is hardened, nonroot, 0-CVE, pinned by digest and cosign-signed.

## Install

```sh
helm install guac oci://ghcr.io/quenchworks/charts/guacamole
kubectl get secret guacamole-db -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/guac-guacamole 8080:8080   # http://127.0.0.1:8080/guacamole/
```

Log in as `guacadmin` with that password, then add connections under Settings.

## How the pieces connect

- **Database init.** Guacamole does not create its own tables. On first install an
  init container copies the schema SQL out of the guacamole image, and a second one
  (psql, the postgresql image) applies it once. Later upgrades see the tables and
  skip it.
- **No default password.** Upstream's schema creates `guacadmin/guacadmin`. The init
  replaces that password with `admin.password`, or a generated one kept in the
  `guacamole-db` Secret.
- **Configuration** is environment variables: the image enables Guacamole's
  `enable-environment-properties`, so any property works as an upper-case variable
  through `extraEnvVars` (for example `LDAP_HOSTNAME` with the LDAP extension added).
- **guacd isolation.** guacd has no authentication and connects to any host it is
  told to, so a NetworkPolicy admits only the web app's pods.
- **Fixed names.** The PostgreSQL pieces are `guacamole-postgresql` and the
  `guacamole-db` Secret. Install one per namespace.

## What the images leave out

guacd is built without the Kubernetes-exec protocol, and the web app ships only the
PostgreSQL auth extension. RDP runs on FreeRDP 2, as in upstream's own image.

## Values

| Key | Default | Meaning |
|---|---|---|
| `admin.password` | `""` | guacadmin password on first install; empty generates one |
| `replicaCount` | `1` | web app replicas |
| `guacd.logLevel` | `info` | guacd log level |
| `extraEnvVars` | `[]` | extra Guacamole properties as environment variables |
| `postgresql.primary.persistence.size` | `8Gi` | database volume |
| `networkPolicy.enabled` | `true` | restrict guacd to the web app |

## Release gate

On kind, the gate installs the chart, logs in through the REST API as guacadmin with
the configured password, requires the default `guacadmin` password to be refused,
lists connections with the token, and runs the protocol handshake against guacd for
RDP, VNC and SSH.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
