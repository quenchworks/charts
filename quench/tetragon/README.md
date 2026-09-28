# Quenchworks Tetragon

Hardened [Tetragon](https://github.com/cilium/tetragon), eBPF runtime security,
with both images built from source, 0-CVE, cosign-signed and pinned by digest.
An agent on every node sees process execution, file access and network
activity in the kernel. TracingPolicy CRDs add custom hooks and enforcement.

| Component | Workload | Image |
|---|---|---|
| Agent + tetra CLI | DaemonSet `<release>-tetragon-agent` | `tetragon` |
| Operator (installs the CRDs) | Deployment `<release>-tetragon-operator` | `tetragon-operator` |

## Install

```bash
helm install tetragon oci://ghcr.io/quenchworks/charts/tetragon -n kube-system
```

Nodes need a kernel with BTF (`/sys/kernel/btf/vmlinux`), which every current
distribution ships. The agent runs **privileged as root with host PID**: it
loads eBPF programs into the kernel. The operator runs nonroot.

## Watch events

```bash
kubectl exec -n kube-system ds/tetragon-tetragon-agent -c tetragon -- tetra getevents -o compact
```

With `agent.enableK8sApi` (the default), events carry the namespace and pod:

```
🚀 process default/web /usr/bin/cat /etc/hostname
```

## Add a TracingPolicy

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata: { name: etc-reads }
spec:
  kprobes:
    - call: security_file_permission
      syscall: false
      args:
        - { index: 0, type: file }
        - { index: 1, type: int }
      selectors:
        - matchArgs:
            - { index: 0, operator: Prefix, values: ["/etc/"] }
```

`tetra tracingpolicy list` in the agent shows it loaded; matching reads then
appear in `getevents` as `read` events.

## Verify the images

```bash
cosign verify ghcr.io/quenchworks/images/tetragon \
  --certificate-identity-regexp 'https://github.com/quenchworks/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Values

| Key | Default | Description |
|---|---|---|
| `agent.enableK8sApi` | `true` | Pod enrichment and TracingPolicy CRDs |
| `agent.clusterName` | `""` | Name on every event |
| `agent.enableProcessCred` / `enableProcessNs` | `false` | Credentials and namespaces on exec events |
| `agent.metricsPort` | `2112` | Prometheus metrics; `0` turns them off |
| `agent.extraConfig` | `{}` | Raw agent options, `{flag: value}` |
| `agent.tolerations` | tolerate all | Run on every node, control plane included |
| `operator.enabled` | `true` | Install the CRDs; required for TracingPolicy |
| `imagePullSecrets` | `[]` | Pull secrets for both workloads |
