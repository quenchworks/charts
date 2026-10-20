#!/usr/bin/env bash
# Install gate for quench/gravitee-apim. Passes only on a real API flow: the default admin
# logs in to the management API (through the console's nginx, which proxies /management),
# creates a v4 HTTP proxy API pointing at an in-cluster echo backend, publishes a keyless
# plan, starts and deploys the API, and the gateway then returns the backend's own reply.
set -euo pipefail
ctx="$(kubectl config current-context)"
case "$ctx" in kind-*) ;; *) echo "refusing to run against context $ctx"; exit 1 ;; esac

C=quench/gravitee-apim
REL=rtest
NS=apim
PW=ci-admin-Passw0rd   # admin.password in ci/default-values.yaml
WORD="quench-gravitee-echo-$RANDOM"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n "$NS" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: { name: echo }
spec:
  replicas: 1
  selector: { matchLabels: { app: echo } }
  template:
    metadata: { labels: { app: echo } }
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo:1.0.0
          args: ["-text=$WORD", "-listen=:8080"]
          ports: [ { containerPort: 8080 } ]
---
apiVersion: v1
kind: Service
metadata: { name: echo }
spec:
  selector: { app: echo }
  ports: [ { port: 80, targetPort: 8080 } ]
EOF

helm dependency build "$C" >/dev/null
helm install "$REL" "$C" -n "$NS" -f "$C/ci/default-values.yaml" --wait --timeout 15m
kubectl rollout status -n "$NS" deploy/echo --timeout=3m

for d in gateway api console; do
  img="$(kubectl get deploy -n "$NS" "$REL-gravitee-apim-$d" -o jsonpath='{.spec.template.spec.containers[0].image}')"
  echo "$d: $img"
  grep -q "^ghcr.io/quenchworks/images/gravitee-$( [ $d = api ] && echo management-api || echo $d )@sha256:" <<<"$img" \
    || { echo "$d image is not the QuenchWorks one"; exit 1; }
done
uid="$(kubectl get pod -n "$NS" -l app.kubernetes.io/component=gateway -o jsonpath='{.items[0].spec.securityContext.runAsUser}')"
test "$uid" = "1001"

kubectl port-forward -n "$NS" "svc/$REL-gravitee-apim-console" 28080:8080 >/tmp/pf-apim-console.log 2>&1 &
pf1=$!
kubectl port-forward -n "$NS" "svc/$REL-gravitee-apim-gateway" 28082:8082 >/tmp/pf-apim-gateway.log 2>&1 &
pf2=$!
trap 'kill $pf1 $pf2 2>/dev/null || true' EXIT
sleep 5
# a busy local port makes port-forward exit while something else answers on it
kill -0 $pf1 && kill -0 $pf2 || { echo "port-forward did not start"; cat /tmp/pf-apim-*.log; exit 1; }

UI=http://127.0.0.1:28080
M="$UI/management/v2/environments/DEFAULT"
grep -q '"baseURL"' <<<"$(curl -fsS "$UI/constants.json")" || { echo "console constants.json missing"; exit 1; }

out="$(curl -fsS -u "admin:$PW" -X POST "$UI/management/organizations/DEFAULT/user/login")"
tok="$(jq -r .token <<<"$out")"
[ -n "$tok" ] && [ "$tok" != null ] || { echo "admin login failed: $out"; exit 1; }
echo "admin login ok (through the console proxy)"
H=(-H "Authorization: Bearer $tok" -H "Content-Type: application/json")
# the stock demo users must not exist: only admin is configured
code="$(curl -s -o /dev/null -w '%{http_code}' -u user:password -X POST "$UI/management/organizations/DEFAULT/user/login")"
[ "$code" = 401 ] || { echo "demo user 'user' can log in ($code)"; exit 1; }

api="$(curl -fsS "${H[@]}" -X POST "$M/apis" -d @- <<EOF
{
  "name": "quench-echo", "apiVersion": "1.0", "definitionVersion": "V4", "type": "PROXY",
  "description": "install gate",
  "listeners": [ { "type": "HTTP", "paths": [ { "path": "/quench-echo" } ],
                   "entrypoints": [ { "type": "http-proxy" } ] } ],
  "endpointGroups": [ { "name": "default", "type": "http-proxy",
                        "endpoints": [ { "name": "echo", "type": "http-proxy", "weight": 1, "inheritConfiguration": false,
                                         "configuration": { "target": "http://echo.$NS.svc:80" } } ] } ]
}
EOF
)"
id="$(jq -r .id <<<"$api")"
[ -n "$id" ] && [ "$id" != null ] || { echo "API create failed: $api"; exit 1; }
echo "created API $id"

plan="$(curl -fsS "${H[@]}" -X POST "$M/apis/$id/plans" \
  -d '{"name":"open","definitionVersion":"V4","mode":"STANDARD","security":{"type":"KEY_LESS"},"validation":"AUTO"}')"
pid="$(jq -r .id <<<"$plan")"
[ -n "$pid" ] && [ "$pid" != null ] || { echo "plan create failed: $plan"; exit 1; }
curl -fsS "${H[@]}" -X POST "$M/apis/$id/plans/$pid/_publish" >/dev/null
curl -fsS "${H[@]}" -X POST "$M/apis/$id/_start" >/dev/null
curl -fsS "${H[@]}" -X POST "$M/apis/$id/deployments" -d '{"deploymentLabel":"install gate"}' >/dev/null
echo "plan $pid published; API started and deployed"

body=""
for i in $(seq 1 40); do
  body="$(curl -sS --max-time 5 http://127.0.0.1:28082/quench-echo/ 2>/dev/null || true)"
  grep -q "$WORD" <<<"$body" && break
  sleep 3
done
echo "gateway reply: $body"
grep -q "$WORD" <<<"$body" || { echo "the gateway never proxied to the backend"; kubectl logs -n "$NS" -l app.kubernetes.io/component=gateway --tail=80; exit 1; }
echo "gate passed: login, create, plan, start, deploy, and the gateway returned the backend reply"
