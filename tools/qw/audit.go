package main

// qw audit [--drift] [--stale] finds charts that lint, install and release green while
// being wrong about their image (both found by hand on 2026-09-17):
//   DRIFT  artifacthub.io/images pins one digest and values.yaml another, so ArtifactHub's
//          CVE report describes an image nobody runs (5 of 166 charts had drifted).
//   STALE  appVersion is a version the recipe no longer builds, so nothing rebuilds the
//          pinned image. Expected for BLOCKED apps, reported apart.
// Sibling images live in subcharts' own values and are skipped.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
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
	dir := filepath.Join(chartsRoot, "..", "images", "apps", slug)
	b, err := os.ReadFile(filepath.Join(dir, "build.conf"))
	if err != nil {
		return nil, false, false
	}
	blocked := regexp.MustCompile(`(?m)^BLOCKED=1`).Match(b)
	out, _ := exec.Command("bash", "-c", `cd "`+dir+`" && source build.conf && echo "${VERSIONS[@]}"`).Output()
	return strings.Fields(string(out)), blocked, true
}

func cmdAudit(args []string) int {
	dflag, sflag := false, false
	for _, a := range args {
		dflag = dflag || a == "--drift"
		sflag = sflag || a == "--stale"
	}
	runDrift, runStale := dflag || !sflag, sflag || !dflag
	var drift, stale [][3]string
	blockedStale, n := 0, 0
	appRe := regexp.MustCompile(`(?m)^appVersion:\s*"?([^"\n]+)"?`)
	for _, slug := range chartDirs() {
		ctext, vtext := readFile(chartsRoot, "quench", slug, "Chart.yaml"), readFile(chartsRoot, "quench", slug, "values.yaml")
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
			if app != nil && ok && len(vs) > 0 && !contains(vs, strings.TrimSpace(app[1])) {
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

func contains(vs []string, s string) bool {
	for _, v := range vs {
		if v == s {
			return true
		}
	}
	return false
}
