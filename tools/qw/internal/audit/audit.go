package audit

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/quenchworks/charts/tools/qw/internal/common"
	"github.com/quenchworks/charts/tools/qw/internal/core"
)

var annRe = regexp.MustCompile(`image: ghcr\.io/quenchworks/images/([\w.-]+)@(sha256:[0-9a-f]{64})`)

func ownDigest(slug, vtext string) string {
	m := regexp.MustCompile(`repository: ghcr\.io/quenchworks/images/` + regexp.QuoteMeta(slug) +
		`\s*\n(?:.*\n){0,4}?\s*digest:\s*"?(sha256:[0-9a-f]{64})`).FindStringSubmatch(vtext)
	if m == nil {
		return ""
	}
	return m[1]
}

func recipeVersions(slug string) ([]string, bool, bool) {
	dir := filepath.Join(core.ChartsRoot, "..", "images", "apps", slug)
	b, err := os.ReadFile(filepath.Join(dir, "build.conf"))
	if err != nil {
		return nil, false, false
	}
	blocked := regexp.MustCompile(`(?m)^BLOCKED=1`).Match(b)
	out, _ := exec.Command("bash", "-c", `cd "`+dir+`" && source build.conf && echo "${VERSIONS[@]}"`).Output()
	return strings.Fields(string(out)), blocked, true
}

func Run(args []string) int {
	dflag, sflag := false, false
	for _, a := range args {
		dflag = dflag || a == "--drift"
		sflag = sflag || a == "--stale"
	}
	runDrift, runStale := dflag || !sflag, sflag || !dflag
	var drift, stale [][3]string
	blockedStale, n := 0, 0
	appRe := regexp.MustCompile(`(?m)^appVersion:\s*"?([^"\n]+)"?`)
	for _, slug := range core.ChartDirs() {
		ctext, vtext := core.ReadFile(core.ChartsRoot, "quench", slug, "Chart.yaml"), core.ReadFile(core.ChartsRoot, "quench", slug, "values.yaml")
		if ctext == "" || vtext == "" {
			continue
		}
		n++
		if runDrift {
			ann := map[string]string{}
			for _, m := range annRe.FindAllStringSubmatch(ctext, -1) {
				ann[m[1]] = m[2]
			}
			if a, ok := ann[slug]; ok {
				if want := ownDigest(slug, vtext); want != "" && a != want {
					drift = append(drift, [3]string{slug, a, want})
				}
			}
		}
		if runStale {
			app := appRe.FindStringSubmatch(ctext)
			vs, blocked, ok := recipeVersions(slug)
			if app != nil && ok && len(vs) > 0 && !common.Contains(vs, strings.TrimSpace(app[1])) {
				if blocked {
					blockedStale++
				} else {
					stale = append(stale, [3]string{slug, strings.TrimSpace(app[1]), strings.Join(vs, " ")})
				}
			}
		}
	}
	if runDrift {
		fmt.Printf("DRIFT  artifacthub.io/images disagrees with values.yaml: %d\n", len(drift))
		for _, d := range drift {
			fmt.Printf("  %-26s annotation=%s...  values=%s...\n", d[0], d[1][:19], d[2][:19])
		}
	}
	if runStale {
		fmt.Printf("STALE  appVersion the recipe no longer builds: %d (%d more in BLOCKED apps, expected)\n", len(stale), blockedStale)
		for _, s := range stale {
			fmt.Printf("  %-26s ships %-12s recipe builds %s\n", s[0], s[1], s[2])
		}
	}
	fmt.Printf("\nchecked %d charts\n", n)
	if len(drift)+len(stale) > 0 {
		return 1
	}
	return 0
}
