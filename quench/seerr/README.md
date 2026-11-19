# Quenchworks Seerr

Hardened [Seerr](https://github.com/fallenbagel/jellyseerr) (formerly Jellyseerr), media request management for
Jellyfin, Emby and Plex: users request films and series, Seerr sends them to Sonarr and Radarr and tracks them to
availability, with quotas, approvals and notifications. The image is built from source on Wolfi Node 24 with sqlite3
on Wolfi's SQLite; it runs as uid 1001 and is CVE-gated at build, cosign-signed and pinned by digest.

## Install

```bash
helm install requests oci://ghcr.io/quenchworks/charts/seerr
kubectl port-forward svc/requests-seerr 5055:5055
```

Then open http://localhost:5055 and finish the setup **before exposing the Service**: the first person to sign in
through your Jellyfin, Emby or Plex server becomes the Seerr admin. Seerr has no local admin to pre-create, so the
chart cannot claim the account for you.

Settings, logs and the SQLite database live on the chart's volume at `/app/config`.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `timezone` | `UTC` | `TZ` for schedules and logs |
| `persistence.size` | `2Gi` | Settings, logs and the SQLite database |
| `settings` | `{}` | More environment variables, e.g. `LOG_LEVEL`, or `DB_TYPE=postgres` with `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME` |

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/seerr \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
