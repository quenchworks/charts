package main

// qw check-netpol-ports: a container port the chart's NetworkPolicy does not admit is
// dropped on every cluster whose CNI enforces policies, and kind's does not, so no release
// gate sees it (24 charts lost their TLS port that way). Every closed port is either
// admitted or listed in netpolAllow with the reason.

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

var netpolAllow = map[string][]string{
	"argocd":                    {"probe"},
	"coredns":                   {"health", "ready"},
	"envoy-gateway":             {"health"},
	"jaeger":                    {"health"},
	"nginx-gateway-fabric":      {"health"},
	"questdb":                   {"health"},
	"trust-manager":             {"readiness"},
	"apisix":                    {"control"},
	"emissary":                  {"admin"},
	"ferretdb":                  {"debug"},
	"postgrest":                 {"admin"},
	"elasticsearch":             {"http"},
	"teleport":                  {"diag", "auth"},        // agents join through web/tunnel; tctl reaches auth in-pod
	"apisix-ingress-controller": {"probe", "adc-status"}, // adc status, read inside the pod
	"fulcio":                    {"grpc"},                // clients use the HTTP API
	"kuma":                      {"diagnostics", "http"}, // the control-plane API is reached through port-forward
	"headscale":                 {"metrics"},
	"nats":                      {"monitor"},
	"postgres-documentdb":       {"metrics"},
}

// renderNetpol renders with policies on, with TLS when the chart has a tls block and
// renders with it (TLS ports are the ones that went missing).
func renderNetpol(chart string) (string, error) {
	d := filepath.Join("quench", chart)
	depBuild(chart)
	args := []string{"template", "t", d, "--set", "networkPolicy.enabled=true"}
	if fileExists(filepath.Join(chartsRoot, d, "ci", "default-values.yaml")) {
		args = append(args, "-f", filepath.Join(d, "ci", "default-values.yaml"))
	}
	var vals map[string]any
	_ = yaml.Unmarshal([]byte(readFile(chartsRoot, d, "values.yaml")), &vals)
	if _, ok := vals["tls"].(map[string]any); ok {
		if out, _, err := helm(append(args, "--set", "tls.enabled=true")...); err == nil {
			return out, nil
		}
	}
	out, errs, err := helm(args...)
	if err != nil {
		return "", fmt.Errorf("%s: helm template failed:\n%s", chart, errs)
	}
	return out, nil
}

func fileExists(p string) bool { _, err := os.Stat(p); return err == nil }

func netpolGaps(chart string) ([]string, error) {
	out, err := renderNetpol(chart)
	if err != nil {
		return nil, err
	}
	ds := docs(out)
	var policies []map[string]any
	for _, d := range ds {
		if d["kind"] != "NetworkPolicy" {
			continue
		}
		spec, _ := d["spec"].(map[string]any)
		types := list(spec["policyTypes"])
		if spec["policyTypes"] == nil {
			types = []any{"Ingress"}
		}
		for _, t := range types {
			if t == "Ingress" {
				policies = append(policies, spec)
				break
			}
		}
	}
	allowed := map[string]bool{}
	for _, a := range netpolAllow[chart] {
		allowed[a] = true
	}
	gaps := map[string]bool{}
	for _, d := range ds {
		switch d["kind"] {
		case "Deployment", "StatefulSet", "DaemonSet":
		default:
			continue
		}
		labels, _ := get(d, "spec", "template", "metadata", "labels").(map[string]any)
		var mine []map[string]any
		for _, p := range policies {
			sel, _ := get(p, "podSelector", "matchLabels").(map[string]any)
			match := true
			for k, v := range sel {
				if labels[k] != v {
					match = false
				}
			}
			if match {
				mine = append(mine, p)
			}
		}
		openRule := false // a rule with no ports admits every port
		admitted := map[string]bool{}
		for _, p := range mine {
			for _, r := range list(p["ingress"]) {
				ps := list(get(r, "ports"))
				if len(ps) == 0 {
					openRule = true
				}
				for _, pt := range ps {
					if v := get(pt, "port"); v != nil {
						admitted[fmt.Sprint(v)] = true
					}
				}
			}
		}
		if len(mine) == 0 || openRule {
			continue
		}
		for _, c := range list(get(d, "spec", "template", "spec", "containers")) {
			for _, pt := range list(get(c, "ports")) {
				cp := fmt.Sprint(get(pt, "containerPort"))
				name := str(get(pt, "name"))
				if name == "" {
					name = cp
				}
				if !admitted[name] && !admitted[cp] && !allowed[name] {
					gaps[name] = true
				}
			}
		}
	}
	return keys(gaps), nil
}

func cmdNetpolPorts(args []string) int {
	charts := args
	if len(charts) == 0 {
		ps, _ := filepath.Glob(filepath.Join(chartsRoot, "quench", "*", "templates", "networkpolicy.yaml"))
		for _, p := range ps {
			charts = append(charts, filepath.Base(filepath.Dir(filepath.Dir(p))))
		}
		sort.Strings(charts)
	}
	bad := 0
	for _, c := range charts {
		g, err := netpolGaps(c)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		if len(g) > 0 {
			fmt.Printf("  %s: container port(s) %s not admitted by its NetworkPolicy\n", c, strings.Join(g, ", "))
			bad++
		}
	}
	if bad > 0 {
		fmt.Fprintf(os.Stderr, "\n%d chart(s) open ports their NetworkPolicy drops; admit them or add them to ALLOW with the reason.\n", bad)
		return 1
	}
	fmt.Printf("all %d NetworkPolicies admit every container port (or document why not)\n", len(charts))
	return 0
}
