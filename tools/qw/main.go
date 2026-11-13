// qw is the QuenchWorks charts tooling: catalog pin checks and re-pins.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

// chartsRoot is the charts/ checkout (the directory holding quench/).
var chartsRoot = "."

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: qw check-pins [--lock path] | check-default-passwords | check-netpol-ports [chart...] | repin <chart> <appVersion> <digest> | tlsprobe --addr host:port --ca ca.crt --name server ...")
		os.Exit(2)
	}
	if wd, err := os.Getwd(); err == nil {
		for d := wd; ; d = filepath.Dir(d) {
			if fi, err := os.Stat(filepath.Join(d, "quench")); err == nil && fi.IsDir() {
				chartsRoot = d
				break
			}
			if filepath.Dir(d) == d {
				break
			}
		}
	}
	switch os.Args[1] {
	case "check-pins":
		os.Exit(cmdCheckPins(os.Args[2:]))
	case "gen-prometheus-crds":
		os.Exit(cmdGenPromCRDs(os.Args[2:]))
	case "gen-linkerd-crds":
		os.Exit(cmdGenLinkerdCRDs(os.Args[2:]))
	case "audit-dep-lag":
		os.Exit(cmdDepLag(os.Args[2:]))
	case "repin-stacks":
		os.Exit(cmdRepinStacks(os.Args[2:]))
	case "audit":
		os.Exit(cmdAudit(os.Args[2:]))
	case "repin":
		os.Exit(cmdRepin(os.Args[2:]))
	case "check-default-passwords":
		os.Exit(cmdDefaultPasswords())
	case "check-netpol-ports":
		os.Exit(cmdNetpolPorts(os.Args[2:]))
	case "tlsprobe":
		os.Exit(cmdTLSProbe(os.Args[2:]))
	case "serve":
		os.Exit(cmdServe(os.Args[2:]))
	case "mongo-roundtrip":
		os.Exit(cmdMongoRoundtrip(os.Args[2:]))
	case "rethinkdb-gate":
		os.Exit(cmdRethinkGate(os.Args[2:]))
	default:
		fmt.Fprintf(os.Stderr, "qw: unknown command %q\n", os.Args[1])
		os.Exit(2)
	}
}

// chartDirs: every chart under quench/, by name.
func chartDirs() []string {
	ds, _ := os.ReadDir(filepath.Join(chartsRoot, "quench"))
	var out []string
	for _, d := range ds {
		if d.IsDir() {
			out = append(out, d.Name())
		}
	}
	sort.Strings(out)
	return out
}

func readFile(p ...string) string {
	b, _ := os.ReadFile(filepath.Join(p...))
	return string(b)
}

func keys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
