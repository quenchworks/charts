package main

// qw check-pins fails when a chart pins an image digest the catalog no longer publishes,
// or bundles a quench subchart older than the current chart. A rebuilt image's old digest
// still resolves in GHCR, so a stale pin installs cleanly and ships the CVEs the rebuild
// fixed: 45 pins across 37 charts went stale that way before 2026-09-20. The invariant is
// deliberately weak: every pinned digest must be in catalog.lock.yaml.

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

var (
	pinRe    = regexp.MustCompile(`(?:digest|tag):\s*"?(?:[^"@\s]*@)?(sha256:[0-9a-f]{64})"?`)
	repoRe   = regexp.MustCompile(`(?:repository|image):\s*"?ghcr\.io/quenchworks/images/([A-Za-z0-9._-]+)"?\s*$`)
	inlineRe = regexp.MustCompile(`ghcr\.io/quenchworks/images/([A-Za-z0-9._-]+)(?::[^@\s"]+)?@(sha256:[0-9a-f]{64})`)
)

type pin struct{ image, digest string }

// valuesPins: a digest belongs to the repository line above it.
func valuesPins(text string) []pin {
	var out []pin
	owner := ""
	for _, l := range strings.Split(text, "\n") {
		if m := repoRe.FindStringSubmatch(l); m != nil {
			owner = m[1]
			continue
		}
		if d := pinRe.FindStringSubmatch(l); d != nil && owner != "" {
			out = append(out, pin{owner, d[1]})
			owner = ""
		}
	}
	return out
}

func inlinePins(text string) []pin {
	var out []pin
	for _, m := range inlineRe.FindAllStringSubmatch(text, -1) {
		out = append(out, pin{m[1], m[2]})
	}
	return out
}

type lockFile struct {
	Apps map[string]struct {
		Versions []struct {
			Version string `yaml:"version"`
			Digest  string `yaml:"digest"`
		} `yaml:"versions"`
	} `yaml:"apps"`
}

type chartMeta struct {
	Version      any `yaml:"version"`
	Dependencies []struct {
		Name       string `yaml:"name"`
		Version    any    `yaml:"version"`
		Repository string `yaml:"repository"`
	} `yaml:"dependencies"`
}

func cmdCheckPins(args []string) int {
	lockPath := filepath.Join(chartsRoot, "..", "images", "catalog.lock.yaml")
	for i := 0; i < len(args); i++ {
		if args[i] == "--lock" && i+1 < len(args) {
			i++
			lockPath = args[i]
		}
	}
	b, err := os.ReadFile(lockPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "lock not found: %s\n", lockPath)
		return 2
	}
	var lock lockFile
	if err := yaml.Unmarshal(b, &lock); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 2
	}
	published := map[string]bool{}
	shipped := map[string][]string{}
	for name, app := range lock.Apps {
		for _, v := range app.Versions {
			published[v.Digest] = true
			shipped[name] = append(shipped[name], v.Version)
		}
	}
	total := 0
	var stale [][3]string
	charts := map[string]chartMeta{}
	for _, c := range chartDirs() {
		found := map[pin]bool{}
		if v := readFile(chartsRoot, "quench", c, "values.yaml"); v != "" {
			for _, p := range append(valuesPins(v), inlinePins(v)...) {
				found[p] = true
			}
		}
		if meta := readFile(chartsRoot, "quench", c, "Chart.yaml"); meta != "" {
			for _, p := range inlinePins(meta) {
				found[p] = true
			}
			var cm chartMeta
			if yaml.Unmarshal([]byte(meta), &cm) == nil {
				charts[c] = cm
			}
		}
		ps := make([]pin, 0, len(found))
		for p := range found {
			ps = append(ps, p)
		}
		sort.Slice(ps, func(i, j int) bool {
			if ps[i].image != ps[j].image {
				return ps[i].image < ps[j].image
			}
			return ps[i].digest < ps[j].digest
		})
		for _, p := range ps {
			total++
			if !published[p.digest] {
				stale = append(stale, [3]string{c, p.image, p.digest})
			}
		}
	}
	lagging := 0
	for _, name := range keys(charts) {
		for _, d := range charts[name].Dependencies {
			sub, ok := charts[d.Name]
			if d.Name == "quench-common" || !ok || strings.TrimRight(d.Repository, "/") != "oci://ghcr.io/quenchworks/charts" {
				continue
			}
			if have, want := fmt.Sprint(d.Version), fmt.Sprint(sub.Version); have != want {
				fmt.Printf("  %s bundles %s %s, current is %s\n", name, d.Name, have, want)
				lagging++
			}
		}
	}
	if lagging > 0 {
		fmt.Printf("\n%d subchart dependencies lag; bump them and re-release.\n\n", lagging)
	}
	if len(stale) == 0 {
		fmt.Printf("all %d pins are published in the catalog\n", total)
		if lagging > 0 {
			return 1
		}
		return 0
	}
	fmt.Printf("%d of %d pins are NOT in the catalog lock:\n\n", len(stale), total)
	for _, s := range stale {
		have := strings.Join(shipped[s[1]], ", ")
		if have == "" {
			have = "image not in the catalog at all"
		}
		fmt.Printf("  %s/%s\n    pinned  %s\n    catalog %s\n", s[0], s[1], s[2], have)
	}
	fmt.Println("\nRe-pin with `qw repin` (primary image) or by hand (siblings).")
	return 1
}
