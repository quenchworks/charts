package repin

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/quenchworks/charts/tools/qw/internal/common"
	"github.com/quenchworks/charts/tools/qw/internal/core"
	"gopkg.in/yaml.v3"
)

type depMeta struct {
	Version      string `yaml:"version"`
	Dependencies []struct {
		Name       string `yaml:"name"`
		Version    string `yaml:"version"`
		Repository string `yaml:"repository"`
	} `yaml:"dependencies"`
}

// headVersion is the chart version committed at HEAD, so a chart this working tree already
// bumped (by repin or repin-stacks) is not bumped twice.
func headVersion(chart string) string {
	out, err := exec.Command("git", "-C", core.ChartsRoot, "show", "HEAD:quench/"+chart+"/Chart.yaml").Output()
	if err != nil {
		return ""
	}
	var m depMeta
	yaml.Unmarshal(out, &m)
	return m.Version
}

// Deps moves every quench subchart dependency to the subchart's version in this working tree
// (the lag check-pins reports) and patch-bumps each parent once. One wave per call: a parent
// bumped here makes its own parents lag, and they move in the next wave, after it releases.
func Deps(args []string) int {
	publishedOnly := len(args) == 1 && args[0] == "--published-only"
	if len(args) > 0 && !publishedOnly {
		fmt.Println("usage: qw bump-deps [--published-only]")
		return 2
	}
	// --published-only (CI): never point a parent at a subchart version GHCR does not serve yet, or its release fails
	published := func(name, ver string) bool {
		_, _, err := core.Helm("show", "chart", "oci://ghcr.io/quenchworks/charts/"+name, "--version", ver)
		return err == nil
	}
	metas := map[string]depMeta{}
	for _, c := range core.ChartDirs() {
		var m depMeta
		if yaml.Unmarshal([]byte(core.ReadFile(core.ChartsRoot, "quench", c, "Chart.yaml")), &m) == nil {
			metas[c] = m
		}
	}
	names := make([]string, 0, len(metas))
	for c := range metas {
		names = append(names, c)
	}
	sort.Strings(names)
	moved := 0
	for _, c := range names {
		var notes []string
		cp := filepath.Join(core.ChartsRoot, "quench", c, "Chart.yaml")
		t := core.ReadFile(cp)
		for _, d := range metas[c].Dependencies {
			sub, ok := metas[d.Name]
			if d.Name == "quench-common" || !ok || strings.TrimRight(d.Repository, "/") != "oci://ghcr.io/quenchworks/charts" || d.Version == sub.Version {
				continue
			}
			if publishedOnly && !published(d.Name, sub.Version) {
				fmt.Printf("wait %s: %s %s is not on GHCR yet\n", c, d.Name, sub.Version)
				continue
			}
			re := regexp.MustCompile(`(- name: ` + regexp.QuoteMeta(d.Name) + `\n(?:    .*\n)*?    version: )"?` + regexp.QuoteMeta(d.Version) + `"?`)
			if !re.MatchString(t) {
				fmt.Printf("!! %s: cannot find dependency %s %s in Chart.yaml\n", c, d.Name, d.Version)
				return 1
			}
			m := re.FindStringSubmatchIndex(t)
			t = t[:m[0]] + t[m[2]:m[3]] + sub.Version + t[m[1]:]
			notes = append(notes, fmt.Sprintf("%s subchart %s -> %s", d.Name, d.Version, sub.Version))
		}
		if len(notes) == 0 {
			continue
		}
		if cur := metas[c].Version; cur == headVersion(c) {
			t = common.ReplaceFirst(regexp.MustCompile(`(?m)^version:\s*\S+`), t, "version: "+bumpPatch(cur))
			block := "  artifacthub.io/changes: |\n    - kind: changed\n      description: \"Bumped the " + strings.Join(notes, ", ") + ".\"\n"
			if strings.Contains(t, "artifacthub.io/changes:") {
				t = common.ReplaceFirst(regexp.MustCompile(`  artifacthub\.io/changes: \|\n(?:    .*\n)+`), t, block)
			} else {
				t = strings.Replace(t, "  artifacthub.io/images:", block+"  artifacthub.io/images:", 1)
			}
		}
		if err := os.WriteFile(cp, []byte(t), 0o644); err != nil {
			fmt.Println("!!", err)
			return 1
		}
		fmt.Printf("ok %s: %s\n", c, strings.Join(notes, ", "))
		moved++
	}
	fmt.Printf("%d chart(s) moved onto their current subcharts\n", moved)
	return 0
}
