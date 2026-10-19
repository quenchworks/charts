# Quenchworks runtime-security-stack

Runtime security in one install, both sensors in the kernel through eBPF:

- [Falco](https://falco.org) matches every node's syscalls against a curated
  ruleset (falco-rules 5.2.0) and prints each alert as a JSON line naming the
  container and pod. Custom rules go in `falco.customRules`.
- [Tetragon](https://tetragon.io) records process, file and network events
  with pod context, and adds custom hooks and enforcement through
  TracingPolicy CRDs.

Every image is built from source, 0-CVE, cosign-signed and pinned by digest.

| Component | Chart | Workload |
|---|---|---|
| Falco 0.45.1 | `falco` 0.0.2 | DaemonSet `<release>-falco` |
| Tetragon 1.7.1 agent | `tetragon` 0.0.6 | DaemonSet `<release>-tetragon-agent` |
| Tetragon operator (CRDs) | `tetragon` 0.0.6 | Deployment `<release>-tetragon-operator` |

## Install

One per cluster (Tetragon's CRDs and ClusterRoles are cluster-wide):

```bash
helm install rs oci://ghcr.io/quenchworks/charts/runtime-security-stack -n security --create-namespace
```

Nodes need a kernel with BTF (`/sys/kernel/btf/vmlinux`); Falco's modern eBPF
probe also needs Linux 5.8 or newer.

## Privileges

| Workload | Runs as |
|---|---|
| Falco | root, host PID, not privileged: all capabilities dropped, then `BPF`, `PERFMON`, `SYS_RESOURCE`, `SYS_PTRACE`; read-only `/proc`, `/etc` and `/run/containerd` from the host |
| Tetragon agent | privileged root with host PID |
| Tetragon operator | nonroot |

See the [falco](../falco/README.md) and [tetragon](../tetragon/README.md)
charts for every option; their values pass through under `falco:` and
`tetragon:`. Either one can be turned off with `<name>.enabled: false`.

## See them work

Read `/etc/shadow` in any container. Falco alerts:

```bash
kubectl -n security logs -l app.kubernetes.io/instance=rs,app.kubernetes.io/name=falco -f
# {"output":"... Sensitive file opened for reading by non-trusted program | file=/etc/shadow ...",
#  "output_fields":{"container.name":"web",...},"rule":"Read sensitive file untrusted",...}
```

Tetragon records the exec:

```bash
kubectl -n security exec ds/rs-tetragon-agent -c tetragon -- tetra getevents -o compact
# 🚀 process default/web /usr/bin/cat /etc/shadow
```

The release gate does exactly this in kind: one pod reads `/etc/shadow`, and
it requires both the Falco alert with `container.name` and the Tetragon exec
event for the same pod.

## Verify the images

```bash
for i in falco tetragon tetragon-operator; do
  cosign verify ghcr.io/quenchworks/images/$i \
    --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
```

## Values

| Key | Default | Description |
|---|---|---|
| `falco.enabled` | `true` | Install Falco |
| `falco.*` | falco chart defaults | Passed to the falco chart (`customRules`, `config`, `capabilities`, ...) |
| `tetragon.enabled` | `true` | Install Tetragon |
| `tetragon.*` | tetragon chart defaults | Passed to the tetragon chart (`agent.*`, `operator.*`) |
