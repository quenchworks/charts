# Quenchworks Falco

Hardened [Falco](https://github.com/falcosecurity/falco) runtime threat
detection, built from source, 0-CVE, cosign-signed and pinned by digest. One
pod per node watches syscalls with the modern eBPF probe, the container plugin
adds container and pod names, and every rule match is printed as one JSON line
on stdout.

| Component | Workload | Image |
|---|---|---|
| Falco + container plugin + falco-rules 5.2.0 | DaemonSet `<release>-falco` | `falco` |

## Install

```bash
helm install falco oci://ghcr.io/quenchworks/charts/falco -n falco --create-namespace
```

Nodes need Linux 5.8 or newer with BTF (`/sys/kernel/btf/vmlinux`), which
every current distribution ships. The image carries the modern eBPF probe only:
no kernel module, no legacy eBPF probe.

## Privileges

The pods run **as root with host PID, not privileged**. All capabilities are
dropped and these are added back:

| Capability | Why |
|---|---|
| `BPF` | load the probe and its maps |
| `PERFMON` | attach the tracing programs |
| `SYS_RESOURCE` | raise the memlock limit for the ring buffers |
| `SYS_PTRACE` | read other processes' `/proc` entries |

Also: `allowPrivilegeEscalation: false`, seccomp `RuntimeDefault`, read-only
root filesystem. This set was measured, not copied: the release gate brings
the probe up with exactly these capabilities and requires a real alert. On a
kernel older than 5.8 (no `CAP_BPF`), add `SYS_ADMIN` to `capabilities` or set
`privileged: true`.

Host mounts, all read-only: `/proc` and `/etc` at `/host/proc` and `/host/etc`
(`HOST_ROOT=/host`), and each directory in `runtimeSocketDirs` (default
`/run/containerd`) at `/host<dir>`, where the container plugin finds the CRI
socket. The tracefs is not mounted, so Falco logs that its TOCTOU mitigation
programs for `open*`, `connect` and `creat` could not attach; detection works
without them.

## Read alerts

```bash
kubectl logs -n falco -l app.kubernetes.io/name=falco -f
```

Reading `/etc/shadow` in any container triggers the default rule
`Read sensitive file untrusted`:

```json
{"output":"... Warning Sensitive file opened for reading by non-trusted program | file=/etc/shadow ... container_name=web ...",
 "output_fields":{"container.name":"web","fd.name":"/etc/shadow","k8s.pod.name":"web",...},
 "priority":"Warning","rule":"Read sensitive file untrusted","source":"syscall",...}
```

Ship them with any log collector that reads pod stdout (the `vector` chart's
DaemonSet, for one).

## Custom rules

Each key of `customRules` becomes a file in `/etc/falco/rules.d`, loaded after
the default ruleset. Falco watches the files and reloads on change.

```yaml
customRules:
  my-rules.yaml: |-
    - rule: Shell in web pods
      desc: A shell started in a web container
      condition: spawned_process and proc.name in (sh, bash) and container.name = web
      output: shell in web (command=%proc.cmdline)
      priority: WARNING
    - list: read_sensitive_file_images
      items: [ghcr.io/acme/backup]
      override: { items: append }
```

## Configuration

`config` is `falco.yaml`, rendered as is into a ConfigMap. Keys left out take
Falco's built-in defaults. Helm merges maps key by key and replaces lists, so
setting `config.plugins` replaces the whole plugins list. The webserver must
stay on: its `/healthz` backs the probes.

Other runtimes: CRI-O is `/run/crio/crio.sock` (add `/run/crio` to
`runtimeSocketDirs` and the socket to
`config.plugins[0].init_config.engines.cri.sockets`); k3s is
`/run/k3s/containerd/containerd.sock`.

## Verify the image

```bash
cosign verify ghcr.io/quenchworks/images/falco \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `privileged` | `false` | Run privileged instead of the capability set |
| `capabilities` | `[BPF, PERFMON, SYS_RESOURCE, SYS_PTRACE]` | Added to an empty set |
| `runtimeSocketDirs` | `[/run/containerd]` | Host dirs mounted read-only at `/host<dir>` |
| `customRules` | `{}` | Rules files, `{name.yaml: content}` |
| `config.engine.kind` | `modern_ebpf` | `modern_ebpf`, `nodriver` or `replay` |
| `config.json_output` | `true` | One JSON object per alert |
| `config.webserver.listen_port` | `8765` | `/healthz` for the probes |
| `config.plugins` | container plugin, CRI on containerd | Container metadata engines |
| `resources` | 100m / 512Mi, limit 1 CPU / 1Gi | Per pod |
| `tolerations` | tolerate all | Run on every node, control plane included |
| `imagePullSecrets` | `[]` | Pull secrets |
