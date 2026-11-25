# Quenchworks Suricata

Hardened [Suricata](https://suricata.io): network intrusion detection on every node. It captures the node's traffic
with AF_PACKET, matches it against the Emerging Threats open rules (and your own), and writes alerts and protocol
logs as EVE JSON. The image is C and Rust built from source, CVE-gated at build (including the statically linked Rust
crates), cosign-signed and pinned by digest.

## Install

```bash
helm install ids oci://ghcr.io/quenchworks/charts/suricata --set interface=eth0
```

Each pod starts as root with NET_RAW, NET_ADMIN and SYS_NICE to open the capture socket (plus SETUID, SETGID and
SETPCAP for the switch), then Suricata drops to uid
1001. An init container fetches the ET open rules with suricata-update on every start.

## Configuration

| Key | Default | What it does |
|---|---|---|
| `interface` | `eth0` | Node interface to capture |
| `rules.update` | `true` | Fetch the ET open rules at start (needs egress to rules.emergingthreats.net) |
| `rules.localRules` | `""` | Extra signatures in Suricata syntax |
| `logHostPath` | `""` | Keep eve.json on the node instead of an emptyDir |
| `resources.limits.memory` | `2Gi` | The full ET rule set needs about 1 GiB |
