#!/usr/bin/env bash
# Install gate for quench/netdata. Passes only when the DaemonSet pod is Ready and the agent
# reports real node data: /api/v1/charts lists system.cpu and at least one cgroup chart (a
# container on the node, read from the host's /sys through the /host mount), and the Prometheus
# endpoint returns netdata_system_cpu. An HTTP 200 alone proves nothing.
set -euo pipefail
ctx="$(kubectl config current-context)"
case "$ctx" in kind-*) ;; *) echo "refusing to run against context $ctx"; exit 1 ;; esac

helm dependency build quench/netdata >/dev/null
helm install rtest quench/netdata -f quench/netdata/ci/default-values.yaml --wait --timeout 5m
kubectl rollout status ds/rtest-netdata --timeout=3m

img="$(kubectl get pods -l app.kubernetes.io/instance=rtest -o jsonpath='{.items[0].spec.containers[0].image}')"
echo "$img"
grep -q '^ghcr.io/quenchworks/images/netdata@sha256:' <<<"$img" || { echo "image not from QuenchWorks"; exit 1; }

base="/api/v1/namespaces/default/services/rtest-netdata:19999/proxy"
charts=""
for i in $(seq 1 30); do
  charts="$(kubectl get --raw "$base/api/v1/charts" 2>/dev/null || true)"
  grep -q '"system.cpu"' <<<"$charts" && grep -qE '"cgroup_[^"]+\.cpu"' <<<"$charts" && break
  sleep 4
done
grep -q '"system.cpu"' <<<"$charts" || { echo "system.cpu missing from /api/v1/charts"; kubectl logs -l app.kubernetes.io/instance=rtest --tail=80; exit 1; }
cg="$(grep -oE '"cgroup_[^"]+\.cpu"' <<<"$charts" | head -1 || true)"
[ -n "$cg" ] || { echo "no cgroup chart: the host /sys is not being read"; grep -oE '"[a-z_]+\.[a-z_0-9]+": *\{' <<<"$charts" | cut -d. -f1 | sort | uniq -c | head -30; exit 1; }
echo "charts: system.cpu and $cg"

prom=""
for i in $(seq 1 15); do
  prom="$(kubectl get --raw "$base/api/v1/allmetrics?format=prometheus" 2>/dev/null || true)"
  grep -q '^netdata_system_cpu' <<<"$prom" && break
  sleep 4
done
line="$(grep -m1 '^netdata_system_cpu' <<<"$prom" || true)"
[ -n "$line" ] || { echo "netdata_system_cpu missing from the Prometheus endpoint"; exit 1; }
echo "$line"
echo "netdata: ok"
