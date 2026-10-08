#!/usr/bin/env bash
# Install gate for the standalone Prometheus exporter charts. Usage: gate-exporter.sh <chart>
# A database exporter is pointed at this repository's matching database chart (release "db",
# password from that chart's Secret) and passes only when /metrics reports its up metric as 1:
# it reached the server and authenticated. node-exporter passes only when node_uname_info is
# reported. An HTTP 200 alone proves nothing.
set -euo pipefail
chart="${1:?usage: gate-exporter.sh <chart>}"
ctx="$(kubectl config current-context)"
case "$ctx" in kind-*) ;; *) echo "refusing to run against context $ctx"; exit 1 ;; esac

case "$chart" in
  redis-exporter)    db=redis;      want='^redis_up 1$' ;;
  postgres-exporter) db=postgresql; want='^pg_up 1$' ;;
  mysqld-exporter)   db=mysql;      want='^mysql_up 1$' ;;
  mongodb-exporter)  db=mongodb;    want='^mongodb_up(\{[^}]*\})? 1$' ;;
  node-exporter)     db="";         want='^node_uname_info\{' ;;
  *) echo "unknown exporter chart $chart"; exit 1 ;;
esac

if [ -n "$db" ]; then
  helm dependency build "quench/$db" >/dev/null
  # the exporter runs in its own pod, so the database's NetworkPolicy would keep it out
  helm install db "quench/$db" --set networkPolicy.enabled=false --wait --timeout 8m
fi
helm dependency build "quench/$chart" >/dev/null
helm install rtest "quench/$chart" -f "quench/$chart/ci/default-values.yaml" --wait --timeout 5m

img="$(kubectl get pods -l app.kubernetes.io/instance=rtest -o jsonpath='{.items[0].spec.containers[0].image}')"
echo "$img"
grep -q '^ghcr.io/quenchworks/images/[a-z-]*@sha256:' <<<"$img" || { echo "image not from QuenchWorks"; exit 1; }

port="$(kubectl get svc "rtest-$chart" -o jsonpath='{.spec.ports[0].port}')"
body=""
for i in $(seq 1 30); do
  body="$(kubectl get --raw "/api/v1/namespaces/default/services/rtest-$chart:$port/proxy/metrics" 2>/dev/null || true)"
  grep -qE "$want" <<<"$body" && break
  sleep 4
done
line="$(grep -E "$want" <<<"$body" | head -1 || true)"
if [ -z "$line" ]; then
  echo "no line matching $want on /metrics; what it reported:"
  grep -E '_up |_up\{|node_uname_info|^# HELP' <<<"$body" | head -20 || true
  kubectl logs -l app.kubernetes.io/instance=rtest --tail=50 || true
  exit 1
fi
echo "$line"
echo "$chart: $line: ok"
