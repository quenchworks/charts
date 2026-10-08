#!/usr/bin/env bash
# Istio ambient install gate, shared by the istio-cni and ztunnel release workflows.
# Installs istiod (ambient on), istio-cni and ztunnel from this checkout into the current kind
# cluster, meshes a namespace, and passes only when a client's request to a server succeeds AND
# ztunnel logs that connection over HBONE with SPIFFE identities on both ends (mutual TLS).
set -euo pipefail
ctx="$(kubectl config current-context)"
case "$ctx" in kind-*) ;; *) echo "refusing to run against context $ctx"; exit 1 ;; esac

ns=istio-system
ver() { awk -F'"' '/^appVersion:/ {print $2; exit}' "quench/$1/Chart.yaml"; }
# one Istio version across the three charts, never mixed inside one gate
v="$(ver istiod)"
for c in istio-cni ztunnel; do
  [ "$(ver "$c")" = "$v" ] || { echo "$c is $(ver "$c"), istiod is $v: the three charts must match"; exit 1; }
done
echo "Istio $v"
for c in istiod istio-cni ztunnel; do helm dependency build "quench/$c" >/dev/null; done

helm install istiod quench/istiod -n "$ns" --create-namespace --set fullnameOverride=istiod \
  --set 'extraEnvVars[0].name=PILOT_ENABLE_AMBIENT' --set-string 'extraEnvVars[0].value=true' \
  --set 'extraEnvVars[1].name=CA_TRUSTED_NODE_ACCOUNTS' --set "extraEnvVars[1].value=$ns/ztunnel" \
  --wait --timeout 5m
helm install istio-cni quench/istio-cni -n "$ns" -f quench/istio-cni/ci/default-values.yaml --wait --timeout 5m
helm install ztunnel quench/ztunnel -n "$ns" -f quench/ztunnel/ci/default-values.yaml --wait --timeout 5m

imgs="$(kubectl -n "$ns" get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u)"
echo "$imgs"
if grep -v '^ghcr.io/quenchworks/images/[a-z-]*@sha256:' <<<"$imgs"; then echo "image not from QuenchWorks"; exit 1; fi

kubectl create namespace amb
kubectl label namespace amb istio.io/dataplane-mode=ambient
kubectl -n amb run server --image=ghcr.io/quenchworks/images/nginx:1.28.3 --port=8080
kubectl -n amb expose pod server --port=80 --target-port=8080
kubectl -n amb run client --image=ghcr.io/quenchworks/images/busybox:1.38.0 --command -- sleep 3600
kubectl -n amb wait --for=condition=Ready pod/server pod/client --timeout=180s
# istio-cni enrolled both pods into ztunnel
for p in server client; do
  r="$(kubectl -n amb get pod "$p" -o jsonpath='{.metadata.annotations.ambient\.istio\.io/redirection}')"
  echo "$p redirection: $r"
  [ "$r" = enabled ] || { echo "$p was not enrolled in ambient"; exit 1; }
done

ok=""
for i in $(seq 1 20); do
  body="$(kubectl -n amb exec client -- wget -qO- -T 5 http://server.amb.svc.cluster.local/ 2>&1 || true)"
  grep -qi nginx <<<"$body" && { ok=1; break; }
  sleep 3
done
[ -n "$ok" ] || { echo "client could not reach server: $body"; exit 1; }
echo "request answered"

# The connection must show up in ztunnel's access log over HBONE with both identities.
id="spiffe://cluster.local/ns/amb/sa/default"
line=""
for i in $(seq 1 20); do
  logs="$(kubectl -n "$ns" logs ds/ztunnel --tail=-1 2>&1 || true)"
  line="$(grep 'connection complete' <<<"$logs" | grep -F "src.identity=\"$id\"" | grep -F "dst.identity=\"$id\"" | grep -F 'dst.hbone_addr=' | head -1 || true)"
  [ -n "$line" ] && break
  sleep 3
done
grep 'connection complete' <<<"$logs" | tail -4 || true
[ -n "$line" ] || { echo "ztunnel logged no HBONE connection with SPIFFE identities on both ends"; exit 1; }
echo "$line"
echo "Istio ambient: istiod, istio-cni and ztunnel $v, request carried over HBONE mTLS ($id on both ends): ok"
