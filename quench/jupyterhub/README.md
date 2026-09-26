# jupyterhub

JupyterHub on Kubernetes: users sign in and each gets their own Jupyter notebook
server as a pod. The chart runs the hub and configurable-http-proxy on QuenchWorks
images (hardened, nonroot, 0-CVE, pinned by digest, cosign-signed); KubeSpawner in
the hub starts the notebook pods.

## Install

```sh
helm install hub oci://ghcr.io/quenchworks/charts/jupyterhub
kubectl get secret hub-jupyterhub-secrets -o jsonpath='{.data.password}' | base64 -d
kubectl get secret hub-jupyterhub-secrets -o jsonpath='{.data.admin-password}' | base64 -d
kubectl port-forward svc/hub-jupyterhub-proxy-public 8000:80   # http://127.0.0.1:8000/
```

Sign in with any username and the first password. Users listed in
`auth.adminUsers` (default `admin`) sign in with the admin password and get the
admin panel.

## How it runs

- **Proxy.** configurable-http-proxy takes all user traffic (Service
  `<release>-jupyterhub-proxy-public`) and routes each user to their server. The hub
  manages its routes over the proxy's REST API with a shared token from the chart's
  Secret. Routes live in the proxy's memory; the hub re-adds them if the proxy
  restarts.
- **Hub.** One replica with its SQLite database on a volume. The cookie secret comes
  from the Secret, so sessions survive restarts.
- **Login.** JupyterHub's shared-password authenticator. For SSO, put an
  OAuthenticator in `extraConfig` (GitHub, GitLab, Google and generic OIDC are in the
  image).
- **Notebook servers.** KubeSpawner creates one pod (and, with
  `singleuser.storage.enabled`, one PVC) per user in the release namespace, under a
  namespaced Role. The default image is Jupyter's own `base-notebook` at the hub's
  version; it is not a QuenchWorks image. Point `singleuser.image` at your own build
  with the libraries your users need.

## Values

| Key | Default | Meaning |
|---|---|---|
| `auth.password` | generated | shared login password (8+ characters) |
| `auth.adminPassword` | generated | admin login password (32+ characters) |
| `auth.adminUsers` | `[admin]` | admin users |
| `singleuser.image` | Jupyter base-notebook `hub-6.0.1` | notebook server image |
| `singleuser.cpuLimit` / `memoryLimit` | `1` / `2G` | per-user limits |
| `singleuser.storage.enabled` | `true` | a PVC per user at `/home/jovyan` |
| `hub.persistence.enabled` | `true` | the hub database volume |
| `extraConfig` | `""` | Python appended to `jupyterhub_config.py` |
| `proxy.service.type` | `ClusterIP` | how users reach the proxy |

## Release gate

On kind, the gate logs in through the proxy (the user path, proxy to hub) as a user
and as the admin, requires a wrong password to be refused, reads the logged-in user back through the hub API
with the chart's service token, and requires the hub's route in the proxy. Spawning
a notebook server pulls the upstream notebook image and is not part of the gate.

The chart depends on the `quench-common` chart from `oci://ghcr.io/quenchworks/charts`.
