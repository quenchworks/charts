#!/usr/bin/env bash
# Linkerd install gate, shared by the linkerd and linkerd-cni release workflows.
# Installs linkerd-crds, linkerd-cni and linkerd (cniEnabled, freshly generated certificates)
# from this checkout into the current kind cluster, and passes only when:
#   - every control-plane proxy holds its identity certificate,
#   - an injected pod has no linkerd-init container,
#   - an injected client reaches an injected server with tls="true" on its proxy's outbound
#     metrics, naming the server's mesh identity,
#   - the policy server answers.
set -euo pipefail
ctx="$(kubectl config current-context)"
case "$ctx" in kind-*) ;; *) echo "refusing to run against context $ctx"; exit 1 ;; esac
ns=linkerd
td=cluster.local
work="$(mktemp -d)"

for c in linkerd-crds linkerd-cni linkerd; do helm dependency build "quench/$c" >/dev/null; done
helm install linkerd-crds quench/linkerd-crds -n "$ns" --create-namespace --wait --timeout 5m
helm install linkerd-cni quench/linkerd-cni -n linkerd-cni --create-namespace -f quench/linkerd-cni/ci/default-values.yaml --wait --timeout 5m

# trust anchor + issuer, the way the README tells users to make them
openssl req -new -x509 -nodes -days 30 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout "$work/ca.key" -out "$work/ca.crt" -subj "/CN=root.linkerd.$td" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"
openssl req -new -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout "$work/issuer.key" -out "$work/issuer.csr" -subj "/CN=identity.$ns.$td"
printf 'basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n' > "$work/ext"
openssl x509 -req -in "$work/issuer.csr" -CA "$work/ca.crt" -CAkey "$work/ca.key" -CAcreateserial \
  -days 30 -extfile "$work/ext" -out "$work/issuer.crt"
kubectl -n "$ns" create secret generic linkerd-identity-issuer \
  --from-file=crt.pem="$work/issuer.crt" --from-file=key.pem="$work/issuer.key"

helm install linkerd quench/linkerd -n "$ns" --set-file identity.trustAnchorsPEM="$work/ca.crt" \
  --set identity.existingSecret=linkerd-identity-issuer --wait --timeout 10m

imgs="$(kubectl get pods -n "$ns" -o jsonpath='{range .items[*]}{range .spec.initContainers[*]}{.image}{"\n"}{end}{range .spec.containers[*]}{.image}{"\n"}{end}{end}'; kubectl get pods -n linkerd-cni -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}')"
imgs="$(sort -u <<<"$imgs")"
echo "$imgs"
if grep -v '^ghcr.io/quenchworks/images/[a-z-]*\(:[0-9.]*\)\?@sha256:' <<<"$imgs"; then echo "image not from QuenchWorks"; exit 1; fi

# 1. every control-plane proxy was certified under its own ServiceAccount
for c in destination identity proxy-injector; do
  pod="$(kubectl -n "$ns" get pods -l linkerd.io/control-plane-component=$c -o jsonpath='{.items[0].metadata.name}')"
  logs="$(kubectl -n "$ns" logs "$pod" -c linkerd-proxy 2>&1 || true)"
  line="$(grep 'Certified identity' <<<"$logs" | head -1 || true)"
  echo "$c: $line"
  grep -qF "linkerd-$c.$ns.serviceaccount.identity.$ns.$td" <<<"$line" || { echo "$c proxy has no identity"; exit 1; }
done

# 2. the policy server answers
ready="$(kubectl get --raw "/api/v1/namespaces/$ns/pods/$(kubectl -n "$ns" get pods -l linkerd.io/control-plane-component=destination -o jsonpath='{.items[0].metadata.name}'):9990/proxy/ready" 2>&1 || true)"
echo "policy /ready: $ready"
grep -qi 'ready' <<<"$ready" || { echo "policy server did not answer /ready"; exit 1; }

# 3. the injector serves before the first meshed pod (its failurePolicy is Ignore)
for i in $(seq 1 60); do
  [ -n "$(kubectl -n "$ns" get endpointslices -l kubernetes.io/service-name=linkerd-proxy-injector -o jsonpath='{.items[*].endpoints[?(@.conditions.ready==true)].addresses[0]}')" ] && break
  sleep 2
done
test -n "$(kubectl -n "$ns" get endpointslices -l kubernetes.io/service-name=linkerd-proxy-injector -o jsonpath='{.items[*].endpoints[?(@.conditions.ready==true)].addresses[0]}')"

kubectl create namespace app
kubectl annotate namespace app linkerd.io/inject=enabled
kubectl -n app create deployment server --image=ghcr.io/quenchworks/images/nginx:1.28.3 --port=8080
kubectl -n app expose deployment server --port=80 --target-port=8080
kubectl -n app create deployment client --image=ghcr.io/quenchworks/images/busybox:1.38.0 -- sleep 3600
kubectl -n app rollout status deployment/server --timeout=300s
kubectl -n app rollout status deployment/client --timeout=300s
client="$(kubectl -n app get pods -l app=client -o jsonpath='{.items[0].metadata.name}')"

# 4. injected, by CNI: a proxy, no linkerd-init
inits="$(kubectl -n app get pod "$client" -o jsonpath='{range .spec.initContainers[*]}{.name}{" "}{end}')"
ctrs="$(kubectl -n app get pod "$client" -o jsonpath='{range .spec.containers[*]}{.name}{" "}{end}')"
echo "client init containers: $inits / containers: $ctrs"
grep -qw linkerd-proxy <<<"$inits $ctrs" || { echo "client was not injected"; exit 1; }
if grep -qw linkerd-init <<<"$inits"; then echo "client has linkerd-init; CNI mode expected none"; exit 1; fi

# 5. a meshed request, over mutual TLS
ok=""
for i in $(seq 1 20); do
  body="$(kubectl -n app exec "$client" -c busybox -- wget -qO- -T 5 http://server.app.svc.cluster.local/ 2>&1 || true)"
  grep -qi nginx <<<"$body" && { ok=1; break; }
  sleep 3
done
[ -n "$ok" ] || { echo "client could not reach server: $body"; exit 1; }
echo "request answered"
sid="default.app.serviceaccount.identity.$ns.$td"
metrics="$(kubectl get --raw "/api/v1/namespaces/app/pods/$client:4191/proxy/metrics")"
hits="$(grep 'direction="outbound"' <<<"$metrics" | grep 'tls="true"' | grep -F "$sid" || true)"
if [ -z "$hits" ]; then
  echo "no outbound metric with tls=\"true\" and server identity $sid; outbound lines:"
  grep 'direction="outbound"' <<<"$metrics" | head -20 || true
  exit 1
fi
sed -n 1,5p <<<"$hits"
echo "Linkerd: control plane certified, injected without linkerd-init (CNI), meshed request over mTLS to $sid, policy server ready: ok"
