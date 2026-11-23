# MITRE Caldera

[MITRE Caldera](https://github.com/mitre/caldera) runs adversary emulation for red and purple teams: ATT&CK-mapped
abilities executed by agents (sandcat, manx) on the hosts you enroll, driven from the magma web UI or the REST API.
The image is built by QuenchWorks from the 5.3.0 tag and the plugin commits it pins, CVE-gated, signed with cosign
and pinned by digest.

**For authorized testing only.** Caldera runs real attack techniques on every host its agents land on.

## Install

```sh
helm install caldera oci://ghcr.io/quenchworks/charts/caldera \
  --set-string 'config.app\.contact\.http=https://caldera.example.com'
```

Log in as `red` (or `blue`). The passwords and API keys are generated once and kept in the release Secret:

```sh
kubectl get secret caldera -o jsonpath='{.data.red-password}' | base64 -d
kubectl get secret caldera -o jsonpath='{.data.api-key-red}' | base64 -d
```

## How it runs

- One replica. Caldera keeps its state in memory and saves it to `data/` (a PVC) on shutdown, so updates stop the
  old pod first and the pod gets 60 s to save.
- An init container renders `conf/local.yml` from the image's `default.yml`, your `config` overrides and the Secret.
  None of `default.yml`'s stock credentials (admin/admin, ADMIN123) work, and the FTP contact password is random.
- Read-only root filesystem. `conf/`, the FTP contact's directory and fieldmanual's docs tree are emptyDirs
  seeded from the image.
- One port: 8888 carries the UI, the API and the agents' HTTP contact. Other contacts (TCP 7010, UDP 7011,
  websocket 7012, DNS 8853, FTP 2222) listen in the pod but are not exposed; add them with your own Service.

## Plugins

Enabled: access, compass, debrief, fieldmanual, manx, response, sandcat, stockpile, training, magma.
`atomic` is shipped but off: it git-clones atomic-red-team at startup and the image has no git.
Not shipped: builder (needs Docker), emu (its pyminizip dependency has an unfixed CVE), gameboard, human, ssl
(use an Ingress for TLS).

The sandcat and manx agents are compiled from source. Every other prebuilt binary in the plugins is removed,
including stockpile's Windows payloads (Akagi64.exe, debugger.dll, debugger.exe, minidump.exe, totallylegit.exe,
HostingCLRx64.dll) and sshpass: abilities that drop them fail with a missing payload.

## Values

| Key | Default | Meaning |
|---|---|---|
| `auth.redPassword`, `auth.bluePassword` | generated | Web logins for red and blue. |
| `auth.apiKeyRed`, `auth.apiKeyBlue` | generated | API keys (`KEY` header). |
| `config` | `{}` | Merged over `default.yml`, e.g. `plugins`, `app.contact.http`. |
| `persistence.size` | `2Gi` | The `data/` volume. `persistence.enabled=false` uses an emptyDir. |
| `service.type`, `service.port` | `ClusterIP`, `8888` | |
| `ingress.*` | off | HTTP Ingress to port 8888. |
| `resources` | 100m / 384Mi requests, 2 / 1Gi limits | |

## Verify the image

```sh
cosign verify ghcr.io/quenchworks/images/caldera \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
