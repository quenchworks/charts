#!/usr/bin/env bash
# linkerd-viz install gate. Runs the full mesh gate first (linkerd-crds, linkerd-cni, linkerd, an
# injected client/server pair in namespace app), then installs the QuenchWorks prometheus chart
# scraping every proxy's admin port and this chart against it, and passes only when:
#   - every viz pod runs a QuenchWorks image and is meshed,
#   - the namespace-metadata Job labelled linkerd-viz as the viz extension,
#   - `linkerd viz stat deploy -n app` shows a non-zero success rate for the server,
#   - `linkerd viz tap deploy/server -n app` streams at least one request.
set -euo pipefail
ctx="$(kubectl config current-context)"
case "$ctx" in kind-*) ;; *) echo "refusing to run against context $ctx"; exit 1 ;; esac

bash scripts/gate-linkerd-mesh.sh

vns=linkerd-viz
work="$(mktemp -d)"

# The linkerd CLI, pinned to the release this chart tracks. sha256 is the digest upstream's
# GitHub release publishes for the asset (no separate checksum file is attached).
cli_ver=edge-26.8.4
cli_sha=49b9c1fd51634e98b7f5d37cc5652995c787a5abbf2fde29304dfc3cf956550c
curl -sfL -o "$work/linkerd" "https://github.com/linkerd/linkerd2/releases/download/${cli_ver}/linkerd2-cli-${cli_ver}-linux-amd64"
echo "${cli_sha}  $work/linkerd" | sha256sum -c -
chmod +x "$work/linkerd"
l5d="$work/linkerd"

# Prometheus (QuenchWorks chart), unmeshed, scraping proxy admin ports with the labels
# metrics-api queries by: namespace, pod, and the workload labels the injector sets.
cat > "$work/prom.yaml" <<'EOF'
persistence: { enabled: false }
networkPolicy: { enabled: false }
podDisruptionBudget: { enabled: false }
serviceAccount: { automountServiceAccountToken: true }
rbac:
  create: true
  clusterScoped: true
  clusterRules:
    - { apiGroups: [""], resources: [pods], verbs: [get, list, watch] }
config:
  prometheusYaml: |
    global:
      scrape_interval: 10s
      evaluation_interval: 10s
    scrape_configs:
      - job_name: linkerd-proxy
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_phase]
            regex: Pending|Running
            action: keep
          - source_labels: [__meta_kubernetes_pod_container_name, __meta_kubernetes_pod_container_port_name]
            regex: linkerd-proxy;linkerd-admin
            action: keep
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          # linkerd.io/proxy-deployment=x -> deployment=x (and replicaset, statefulset, ...)
          - action: labelmap
            regex: __meta_kubernetes_pod_label_linkerd_io_proxy_(.+)
          - action: labelmap
            regex: __meta_kubernetes_pod_label_linkerd_io_(.+)
EOF
helm dependency build quench/prometheus >/dev/null
helm install prom quench/prometheus -n monitoring --create-namespace -f "$work/prom.yaml" --wait --timeout 5m
prom=http://prom-prometheus.monitoring.svc.cluster.local:9090

helm dependency build quench/linkerd-viz >/dev/null
helm install linkerd-viz quench/linkerd-viz -n "$vns" --create-namespace --set prometheusUrl="$prom" --wait --timeout 10m

imgs="$(kubectl get pods -n "$vns" -o jsonpath='{range .items[*]}{range .spec.initContainers[*]}{.image}{"\n"}{end}{range .spec.containers[*]}{.image}{"\n"}{end}{end}')"
imgs="$(sort -u <<<"$imgs")"
echo "$imgs"
if grep -v '^ghcr.io/quenchworks/images/[a-z-]*\(:[0-9.]*\)\?@sha256:' <<<"$imgs"; then echo "image not from QuenchWorks"; exit 1; fi

# 1. viz pods meshed
for c in metrics-api tap tap-injector; do
  names="$(kubectl -n "$vns" get pods -l component=$c -o jsonpath='{range .items[0].spec.initContainers[*]}{.name}{" "}{end}{range .items[0].spec.containers[*]}{.name}{" "}{end}')"
  echo "$c: $names"
  grep -qw linkerd-proxy <<<"$names" || { echo "$c is not meshed"; exit 1; }
done

# 2. namespace-metadata Job labelled the namespace
lbl="$(kubectl get namespace "$vns" -o jsonpath='{.metadata.labels.linkerd\.io/extension}')"
echo "namespace label linkerd.io/extension=$lbl"
[ "$lbl" = viz ] || { echo "namespace-metadata did not label $vns"; exit 1; }

# 3. the tap injector serves before the app pods are recreated (its failurePolicy is Ignore)
for i in $(seq 1 60); do
  [ -n "$(kubectl -n "$vns" get endpointslices -l kubernetes.io/service-name=tap-injector -o jsonpath='{.items[*].endpoints[?(@.conditions.ready==true)].addresses[0]}')" ] && break
  sleep 2
done
test -n "$(kubectl -n "$vns" get endpointslices -l kubernetes.io/service-name=tap-injector -o jsonpath='{.items[*].endpoints[?(@.conditions.ready==true)].addresses[0]}')"

# The mesh gate's pods predate viz: recreate the server so the tap injector marks it, and add a
# steady meshed load.
kubectl -n app rollout restart deployment/server
kubectl -n app create deployment load --image=ghcr.io/quenchworks/images/busybox:1.38.0 -- \
  sh -c 'while true; do wget -qO /dev/null -T 2 http://server.app.svc.cluster.local/ || true; sleep 0.5; done'
kubectl -n app rollout status deployment/server --timeout=300s
kubectl -n app rollout status deployment/load --timeout=300s
server="$(kubectl -n app get pods -l app=server --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')"
env="$(kubectl -n app get pod "$server" -o jsonpath='{.spec.initContainers[*].env[*].name} {.spec.containers[*].env[*].name}')"
grep -qw LINKERD2_PROXY_TAP_SVC_NAME <<<"$env" || { echo "tap injector did not mark $server"; exit 1; }
echo "tap injector marked $server"

# 4. stat: a non-zero success rate for the server, from Prometheus through metrics-api
ok=""
for i in $(seq 1 30); do
  out="$("$l5d" viz stat deploy -n app 2>&1 || true)"
  sr="$(awk '$1=="server"{print $3}' <<<"$out")"
  if [ -n "$sr" ] && [ "$sr" != "-" ] && awk -v s="${sr%\%}" 'BEGIN{exit !(s+0 > 0)}'; then ok=1; break; fi
  sleep 10
done
echo "$out"
[ -n "$ok" ] || { echo "linkerd viz stat shows no success rate for server"; exit 1; }

# 5. tap streams requests
"$l5d" viz tap deploy/server -n app > "$work/tap.txt" 2>&1 &
tpid=$!
for i in $(seq 1 30); do
  grep -q 'req id=' "$work/tap.txt" && break
  sleep 2
done
kill "$tpid" 2>/dev/null || true
head -5 "$work/tap.txt"
grep -q 'req id=' "$work/tap.txt" || { echo "linkerd viz tap streamed no request"; cat "$work/tap.txt"; exit 1; }

echo "linkerd-viz: viz pods meshed on QuenchWorks images, namespace labelled, stat success rate $sr for server, tap streaming: ok"
