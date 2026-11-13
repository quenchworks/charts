// qw is the QuenchWorks charts tooling: catalog pin checks and re-pins, chart audits,
// CRD generators, and the protocol probes the release gates use. Run it through the
// Makefile next to this file, or as `go -C tools/qw run . <command>`.
package main

import (
	"os"

	"github.com/quenchworks/charts/tools/qw/internal/cli"
)

func main() { os.Exit(cli.Run(os.Args[1:])) }
