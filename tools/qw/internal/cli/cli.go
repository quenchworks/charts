// Package cli maps qw's command names to the packages that run them.
package cli

import (
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"

	"github.com/quenchworks/charts/tools/qw/internal/audit"
	"github.com/quenchworks/charts/tools/qw/internal/checkpins"
	"github.com/quenchworks/charts/tools/qw/internal/core"
	"github.com/quenchworks/charts/tools/qw/internal/gencrds"
	"github.com/quenchworks/charts/tools/qw/internal/netpol"
	"github.com/quenchworks/charts/tools/qw/internal/passwords"
	"github.com/quenchworks/charts/tools/qw/internal/probe"
	"github.com/quenchworks/charts/tools/qw/internal/repin"
)

var commands = map[string]struct {
	run         func([]string) int
	args, about string
}{
	"check-pins":              {checkpins.Run, "[--lock path]", "every pin is a published image and every subchart is current"},
	"check-default-passwords": {func([]string) int { return passwords.Run() }, "", "no chart ships a fixed default password"},
	"check-netpol-ports":      {netpol.Run, "[chart...]", "every listening port is allowed by the chart's NetworkPolicy"},
	"repin":                   {repin.Pins, "<chart> <appVersion> <digest>", "move a chart to a new image digest, patch-bump it"},
	"repin-stacks":            {repin.Stacks, "[--audit] | <image> <sha256:...> [...]", "re-pin the stacks that bundle an image"},
	"audit":                   {audit.Run, "[--drift] [--stale]", "chart pins against the image recipes (both checks by default)"},
	"audit-dep-lag":           {audit.DepLag, "[--strict]", "charts bundling an old subchart version"},
	"gen-prometheus-crds":     {gencrds.Prometheus, "<version> [--check]", "regenerate the prometheus-operator CRDs"},
	"gen-linkerd-crds":        {gencrds.Linkerd, "<edge-version> [--check]", "regenerate the linkerd CRDs"},
	"tlsprobe":                {probe.TLSProbe, "--addr H:P (--ca F --name N | --plain) [--send S] [--expect T]... [--print]", "speak a few protocol bytes, check the reply"},
	"serve":                   {probe.Serve, "[--dir D] [--addr H:P]", "serve a directory over HTTP (release gates)"},
	"mongo-roundtrip":         {probe.MongoRoundtrip, "--uri mongodb://...", "write and read a document over the MongoDB wire protocol"},
	"rethinkdb-gate":          {probe.RethinkGate, "[--addr H:P] [--ca F] write|read|tls", "one step of the RethinkDB release gate"},
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: qw <command> [args]")
	for _, name := range slices.Sorted(maps.Keys(commands)) {
		c := commands[name]
		fmt.Fprintf(os.Stderr, "  %-24s %s\n  %-24s   %s\n", name, c.args, "", c.about)
	}
}

// Run executes one command line (without the program name) and returns its exit code.
func Run(args []string) int {
	if len(args) == 0 || args[0] == "help" || args[0] == "-h" || args[0] == "--help" {
		usage()
		return 2
	}
	c, ok := commands[args[0]]
	if !ok {
		fmt.Fprintf(os.Stderr, "qw: unknown command %q\n", args[0])
		usage()
		return 2
	}
	if wd, err := os.Getwd(); err == nil {
		core.ChartsRoot = findRoot(wd)
	}
	return c.run(args[1:])
}

// findRoot walks up to the directory holding quench/.
func findRoot(dir string) string {
	for d := dir; ; d = filepath.Dir(d) {
		if fi, err := os.Stat(filepath.Join(d, "quench")); err == nil && fi.IsDir() {
			return d
		}
		if filepath.Dir(d) == d {
			return "."
		}
	}
}
