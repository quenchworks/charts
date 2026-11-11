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
    # with tls.enabled the API is HTTPS-only through the TLS sidecar
    "elasticsearch": {"http"},
    # reviewed 2026-11-11: none of these is exposed by the chart's Service at default values
    "teleport": {"diag", "auth"},           # agents join through web/tunnel; tctl reaches auth in-pod
    "apisix-ingress-controller": {"probe", "adc-status"},  # adc status, read inside the pod
    "fulcio": {"grpc"},                     # clients use the HTTP API
    "kuma": {"diagnostics", "http"},        # the control-plane API is reached through port-forward
    # metrics/monitor endpoints stay private: a scraper in another namespace needs its own policy
    "headscale": {"metrics"},
    "nats": {"monitor"},
    "postgres-documentdb": {"metrics"},
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
    docs = [d for d in yaml.safe_load_all(ports(chart)) if d]
    policies = [d["spec"] for d in docs if d.get("kind") == "NetworkPolicy"
                and "Ingress" in d["spec"].get("policyTypes", ["Ingress"])]
    allowed = ALLOW.get(chart, set())
    gaps = set()
    for d in docs:
        if d.get("kind") not in ("Deployment", "StatefulSet", "DaemonSet"):
            continue
        labels = d["spec"]["template"]["metadata"].get("labels") or {}
        # only the policies that select this workload's pods restrict it
        mine = [p for p in policies
                if all(labels.get(k) == v for k, v in (p.get("podSelector", {}).get("matchLabels") or {}).items())]
        if not mine or any(not r.get("ports") for p in mine for r in p.get("ingress") or []):
            continue
        admitted = {pt.get("port") for p in mine for r in p.get("ingress") or [] for pt in r.get("ports") or []}
        for c in d["spec"]["template"]["spec"].get("containers", []):
            for pt in c.get("ports") or []:
                name = pt.get("name") or str(pt["containerPort"])
                if name not in admitted and pt["containerPort"] not in admitted and name not in allowed:
                    gaps.add(name)
    return sorted(gaps)


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
