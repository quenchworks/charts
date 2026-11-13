package netpol

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/quenchworks/charts/tools/qw/internal/common"
	"github.com/quenchworks/charts/tools/qw/internal/core"
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
	core.DepBuild(chart)
	args := []string{"template", "t", d, "--set", "networkPolicy.enabled=true"}
	if core.FileExists(filepath.Join(core.ChartsRoot, d, "ci", "default-values.yaml")) {
		args = append(args, "-f", filepath.Join(d, "ci", "default-values.yaml"))
	}
	var vals map[string]any
	_ = yaml.Unmarshal([]byte(core.ReadFile(core.ChartsRoot, d, "values.yaml")), &vals)
	if _, ok := vals["tls"].(map[string]any); ok {
		if out, _, err := core.Helm(append(args, "--set", "tls.enabled=true")...); err == nil {
			return out, nil
		}
	}
	out, errs, err := core.Helm(args...)
	if err != nil {
		return "", fmt.Errorf("%s: helm template failed:\n%s", chart, errs)
	}
	return out, nil
}

func netpolGaps(chart string) ([]string, error) {
	out, err := renderNetpol(chart)
	if err != nil {
		return nil, err
	}
	ds := core.Docs(out)
	var policies []map[string]any
	for _, d := range ds {
		if d["kind"] != "NetworkPolicy" {
			continue
		}
		spec, _ := d["spec"].(map[string]any)
		types := core.List(spec["policyTypes"])
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
		labels, _ := core.Get(d, "spec", "template", "metadata", "labels").(map[string]any)
		var mine []map[string]any
		for _, p := range policies {
			sel, _ := core.Get(p, "podSelector", "matchLabels").(map[string]any)
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
			for _, r := range core.List(p["ingress"]) {
				ps := core.List(core.Get(r, "ports"))
				if len(ps) == 0 {
					openRule = true
				}
				for _, pt := range ps {
					if v := core.Get(pt, "port"); v != nil {
						admitted[fmt.Sprint(v)] = true
					}
				}
			}
		}
		if len(mine) == 0 || openRule {
			continue
		}
		for _, c := range core.List(core.Get(d, "spec", "template", "spec", "containers")) {
			for _, pt := range core.List(core.Get(c, "ports")) {
				cp := fmt.Sprint(core.Get(pt, "containerPort"))
				name := core.Str(core.Get(pt, "name"))
				if name == "" {
					name = cp
				}
				if !admitted[name] && !admitted[cp] && !allowed[name] {
					gaps[name] = true
				}
			}
		}
	}
	return common.Keys(gaps), nil
}

func Run(args []string) int {
	charts := args
	if len(charts) == 0 {
		ps, _ := filepath.Glob(filepath.Join(core.ChartsRoot, "quench", "*", "templates", "networkpolicy.yaml"))
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
		fmt.Fprintf(os.Stderr, "\n%d chart(s) open ports their NetworkPolicy drops; admit them or add them to netpolAllow (tools/qw/netpol.go) with the reason.\n", bad)
		return 1
	}
	fmt.Printf("all %d NetworkPolicies admit every container port (or document why not)\n", len(charts))
	return 0
}
