#!/usr/bin/env python3
"""Every container port a chart opens must be admitted by its NetworkPolicy.

Renders each chart that has a NetworkPolicy with its ci values, networkPolicy.enabled and,
where the chart has a tls block, tls.enabled. Then compares the named container ports of its
workloads with the ports the policy's ingress rules admit. A port missing from the policy is
silently dropped on any cluster whose CNI enforces policies, and no kind gate sees it: kind's
default CNI does not enforce NetworkPolicy, and port-forward bypasses it. 24 charts shipped
their TLS port that way until 2026-11-11.

ALLOW lists ports a chart closes on purpose. Probe-only ports are safe to leave closed: the
kubelet's probes are not subject to NetworkPolicy.

    python3 scripts/check-netpol-ports.py [chart ...]
"""
import glob, os, subprocess, sys, yaml

ALLOW = {
    # probe/health endpoints, used only by the kubelet
    "apisix-ingress-controller": {"probe"},
    "argocd": {"probe"},
    "coredns": {"health", "ready"},
    "envoy-gateway": {"health"},
    "jaeger": {"health"},
    "nginx-gateway-fabric": {"health"},
    "questdb": {"health"},
    "trust-manager": {"readiness"},
    # admin, debug and diagnostics surfaces kept private on purpose
    "apisix": {"control"},
    "emissary": {"admin"},
    "ferretdb": {"debug"},
    "postgrest": {"admin"},
    "kuma": {"diagnostics"},
    "teleport": {"diag"},
    # with tls.enabled the API is HTTPS-only through the TLS sidecar
    "elasticsearch": {"http"},
}
# NOT YET REVIEWED (2026-11-11): closed today, each needs a decision (metrics scraping, a second
# API, an internal RPC port). Review, then move to ALLOW with a reason or admit the port.
UNREVIEWED = {
    "apisix-ingress-controller": {"adc-status"},
    "argocd": {"webhook"},
    "fulcio": {"grpc"},
    "headscale": {"metrics"},
    "kuma": {"http"},
    "nats": {"monitor"},
    "postgres-documentdb": {"metrics"},
    "teleport": {"auth"},
}


def ports(chart):
    d = f"quench/{chart}"
    subprocess.run(["helm", "dependency", "build", d], capture_output=True)
    args = ["helm", "template", "t", d, "--set", "networkPolicy.enabled=true"]
    if os.path.exists(f"{d}/ci/default-values.yaml"):
        args += ["-f", f"{d}/ci/default-values.yaml"]
    values = yaml.safe_load(open(f"{d}/values.yaml")) or {}
    if isinstance(values.get("tls"), dict):
        r = subprocess.run(args + ["--set", "tls.enabled=true"], capture_output=True, text=True)
        if r.returncode == 0:
            return r.stdout
        # some modes refuse TLS (dev, sentinel): check the plaintext render instead
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"{chart}: helm template failed:\n{r.stderr}")
    return r.stdout


def gaps(chart):
    cports, admitted, open_all, has_np = set(), set(), False, False
    for doc in yaml.safe_load_all(ports(chart)):
        if not doc:
            continue
        kind = doc.get("kind")
        if kind in ("Deployment", "StatefulSet", "DaemonSet"):
            for c in doc["spec"]["template"]["spec"].get("containers", []):
                for p in c.get("ports") or []:
                    cports.add((p.get("name") or str(p["containerPort"]), p["containerPort"]))
        elif kind == "NetworkPolicy" and "Ingress" in doc["spec"].get("policyTypes", ["Ingress"]):
            has_np = True
            for rule in doc["spec"].get("ingress") or []:
                if not rule.get("ports"):
                    open_all = True
                for p in rule.get("ports") or []:
                    admitted.add(p.get("port"))
    if not has_np or open_all:
        return []
    allowed = ALLOW.get(chart, set()) | UNREVIEWED.get(chart, set())
    return sorted(n for n, num in cports if n not in admitted and num not in admitted and n not in allowed)


def main():
    charts = sys.argv[1:] or sorted(
        os.path.basename(os.path.dirname(os.path.dirname(p)))
        for p in glob.glob("quench/*/templates/networkpolicy.yaml"))
    bad = {c: g for c in charts if (g := gaps(c))}
    for c, g in bad.items():
        print(f"  {c}: container port(s) {', '.join(g)} not admitted by its NetworkPolicy")
    if bad:
        sys.exit(f"\n{len(bad)} chart(s) open ports their NetworkPolicy drops; admit them or add "
                 "them to ALLOW with the reason.")
    print(f"all {len(charts)} NetworkPolicies admit every container port (or document why not)")


if __name__ == "__main__":
    main()
