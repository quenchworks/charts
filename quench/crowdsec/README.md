# Quenchworks CrowdSec

Hardened [CrowdSec](https://github.com/crowdsecurity/crowdsec): agents read logs, match them against community attack
scenarios and send alerts to the Local API (LAPI), which turns them into block decisions that bouncers (nginx,
Traefik, a firewall) fetch. The image is crowdsec and cscli built from source with upstream's container entrypoint,
CVE-gated at build, cosign-signed and pinned by digest.

The chart runs the LAPI as a Deployment (uid 1001, read-only rootfs, SQLite on a PVC) and one agent per node as a
DaemonSet that reads the kubelet's container logs from `/var/log`. The agent runs as uid 0 with every capability
dropped, because pod log files are 0640 root.

## Install

```bash
helm install crowdsec oci://ghcr.io/quenchworks/charts/crowdsec
kubectl exec deploy/crowdsec-lapi -- cscli bouncers add my-bouncer
```

Bouncers reach the LAPI at `http://crowdsec-lapi.<namespace>:8080` with that key.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `lapi.env` | `{}` | Upstream container env for the LAPI (`ENROLL_KEY`, `DISABLE_ONLINE_API`, ...) |
| `lapi.envSecret` | `""` | A Secret loaded with `envFrom`; `BOUNCER_KEY_<name>=<key>` there pre-registers a bouncer |
| `lapi.persistence.enabled` | `true` | Keeps decisions and registered bouncers across restarts |
| `agent.enabled` | `true` | One agent per node |
| `agent.collections` / `agent.parsers` | `crowdsecurity/linux` / `crowdsecurity/cri-logs` | Hub items installed at start (needs egress to the hub) |
| `agent.acquisition` | `/var/log/containers/*.log` | Log sources, one acquisition document each |
| `auth.agentPassword` | generated | The agents' login on the LAPI, kept across upgrades |
| `networkPolicy.enabled` | `true` | Ingress allowed on 8080 and 6060 only |
