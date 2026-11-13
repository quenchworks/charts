package audit

import (
	"fmt"
	"regexp"

	"github.com/quenchworks/charts/tools/qw/internal/checkpins"
	"github.com/quenchworks/charts/tools/qw/internal/core"
	"gopkg.in/yaml.v3"
)

func DepLag(args []string) int {
	strict := false
	for _, a := range args {
		strict = strict || a == "--strict"
	}
	verRe := regexp.MustCompile(`(?m)^version:\s*(\S+)`)
	chartVersion := func(slug string) string {
		if m := verRe.FindStringSubmatch(core.ReadFile(core.ChartsRoot, "quench", slug, "Chart.yaml")); m != nil {
			return m[1]
		}
		return ""
	}
	type lag struct{ parent, dep, pinned, actual string }
	var lagging []lag
	for _, d := range core.ChartDirs() {
		text := core.ReadFile(core.ChartsRoot, "quench", d, "Chart.yaml")
		if text == "" {
			continue
		}
		var doc checkpins.ChartMeta
		_ = yaml.Unmarshal([]byte(text), &doc)
		for _, dep := range doc.Dependencies {
			if actual := chartVersion(dep.Name); actual != "" && fmt.Sprint(dep.Version) != actual {
				lagging = append(lagging, lag{d, dep.Name, fmt.Sprint(dep.Version), actual})
			}
		}
	}
	if len(lagging) == 0 {
		fmt.Println("no lagging subchart pins")
		return 0
	}
	fmt.Printf("%d lagging subchart pin(s):\n", len(lagging))
	for _, l := range lagging {
		fmt.Printf("  %-24s %-18s pinned %-9s actual %s\n", l.parent, l.dep, l.pinned, l.actual)
	}
	fmt.Print("\nA lagging pin means this parent deploys an OLD subchart, which pins an OLD\n" +
		"image digest. Before bumping: check the target version is published, re-audit\n" +
		"for cascades afterwards, lint the parent (a minor bump can break its values),\n" +
		"and confirm the newest version is actually COMPATIBLE.\n")
	if strict {
		return 1
	}
	return 0
}
