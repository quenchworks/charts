package main

// qw repin <chart> <appVersion> <sha256:...> [--kind K] [--desc D] [--skip-verify] re-pins a
// chart's primary image: swaps the FIRST digest in values.yaml (and the same digest in
// Chart.yaml), sets the image tag beside it and appVersion, bumps the chart patch version
// and writes the ArtifactHub change note. It refuses a malformed digest, one the registry
// does not have (a hand-typed digest), and a swap that leaves the artifacthub.io/images
// annotation on another digest. Multi-image charts are the caller's to disambiguate.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var digestRe = regexp.MustCompile(`sha256:[0-9a-f]{64}`)

func bumpPatch(v string) string {
	p := strings.Split(strings.TrimSpace(v), ".")
	n, _ := strconv.Atoi(p[len(p)-1])
	p[len(p)-1] = strconv.Itoa(n + 1)
	return strings.Join(p, ".")
}

func cmdRepin(argv []string) int {
	var args []string
	opts := map[string]string{}
	skip := false
	for i := 0; i < len(argv); i++ {
		a := argv[i]
		switch {
		case a == "--skip-verify":
			skip = true
		case strings.HasPrefix(a, "--") && i+1 < len(argv):
			opts[strings.TrimPrefix(a, "--")] = argv[i+1]
			i++
		default:
			args = append(args, a)
		}
	}
	if len(args) < 3 {
		fmt.Println("usage: qw repin <chart> <appVersion> <sha256:...> [--kind K] [--desc D] [--skip-verify]")
		return 2
	}
	chart, appver, digest := args[0], args[1], args[2]
	if !regexp.MustCompile(`^sha256:[0-9a-f]{64}$`).MatchString(digest) {
		fmt.Printf("!! refusing a malformed digest: %s\n", "'"+digest+"'")
		return 3
	}
	cdir := filepath.Join(chartsRoot, "quench", chart)
	if !skip {
		out, err := exec.Command("docker", "buildx", "imagetools", "inspect",
			"ghcr.io/quenchworks/images/"+chart+"@"+digest, "--format", "{{.Manifest.Digest}}").CombinedOutput()
		if err != nil {
			names := regexp.MustCompile(`ghcr\.io/quenchworks/images/([\w.-]+)`).FindAllStringSubmatch(readFile(cdir, "values.yaml"), -1)
			mine := false
			for _, n := range names {
				mine = mine || n[1] == chart
			}
			if mine {
				last := "no output"
				if ls := strings.Split(strings.TrimSpace(string(out)), "\n"); ls[len(ls)-1] != "" {
					last = ls[len(ls)-1]
				}
				fmt.Printf("!! %s: the registry does not have %s...\n   %s\n", chart, digest[:19], last)
				fmt.Println("   Pass the digest from `docker buildx imagetools inspect ... --format '{{.Manifest.Digest}}'`,")
				fmt.Println("   never a hand-typed one. Use --skip-verify only when offline.")
				return 3
			}
			fmt.Printf("note: could not verify %s... against images/%s (multi-image chart; verify the owning repository yourself)\n", digest[:19], chart)
		}
	}
	cy, vy := filepath.Join(cdir, "Chart.yaml"), filepath.Join(cdir, "values.yaml")
	if !fileExists(cy) {
		fmt.Printf("!! no such chart: %s\n", chart)
		return 3
	}
	ctext, vtext := readFile(cy), readFile(vy)
	old := digestRe.FindString(vtext)
	if old == "" {
		fmt.Printf("!! %s: no digest found in values.yaml\n", chart)
		return 3
	}
	oldver := regexp.MustCompile(`(?m)^version:\s*(\S+)`).FindStringSubmatch(ctext)[1]
	oldapp := regexp.MustCompile(`(?m)^appVersion:\s*"?([^"\n]+)"?`).FindStringSubmatch(ctext)[1]
	newver := bumpPatch(oldver)
	vtext = strings.ReplaceAll(vtext, old, digest)
	ctext = strings.ReplaceAll(ctext, old, digest)
	// the tag beside our image's digest follows the app version
	lines := strings.Split(vtext, "\n")
	tagRe := regexp.MustCompile(`^(\s*)tag:\s*("?)([^"\n]*)("?)\s*$`)
	for i, l := range lines {
		if !strings.Contains(l, digest) {
			continue
		}
		if !strings.Contains(strings.Join(lines[max(0, i-8):i+1], "\n"), "ghcr.io/quenchworks/images") {
			break
		}
		for j := i - 1; j > max(-1, i-8); j-- {
			if m := tagRe.FindStringSubmatch(lines[j]); m != nil {
				lines[j] = m[1] + `tag: "` + appver + `"`
				break
			}
			if regexp.MustCompile(`^\s*image:\s*$`).MatchString(lines[j]) {
				break
			}
		}
		break
	}
	vtext = strings.Join(lines, "\n")
	ctext = replaceFirst(regexp.MustCompile(`(?m)^version:\s*\S+`), ctext, "version: "+newver)
	ctext = replaceFirst(regexp.MustCompile(`(?m)^appVersion:\s*"?[^"\n]+"?`), ctext, `appVersion: "`+appver+`"`)
	kind := opts["kind"]
	if kind == "" {
		kind = "changed"
	}
	desc := opts["desc"]
	if desc == "" {
		if appver != oldapp {
			desc = fmt.Sprintf("Updated %s to %s and re-pinned the image to its new rebuilt digest.", chart, appver)
		} else {
			desc = fmt.Sprintf("Re-pinned %s to a rebuilt image digest (no application version change).", chart)
		}
	}
	block := "  artifacthub.io/changes: |\n    - kind: " + kind + "\n      description: \"" + desc + "\"\n"
	if strings.Contains(ctext, "artifacthub.io/changes:") {
		ctext = replaceFirst(regexp.MustCompile(`  artifacthub\.io/changes: \|\n(?:    .*\n)+`), ctext, block)
	} else {
		ctext = strings.Replace(ctext, "  artifacthub.io/images:", block+"  artifacthub.io/images:", 1)
	}
	if old != digest && (strings.Contains(ctext, old) || strings.Contains(vtext, old)) {
		fmt.Printf("!! %s: a stale digest survived the rewrite\n", chart)
		return 3
	}
	ann := regexp.MustCompile(`image: ghcr\.io/quenchworks/images/` + regexp.QuoteMeta(chart) + `@(sha256:[0-9a-f]{64})`).FindStringSubmatch(ctext)
	if ann != nil && ann[1] != digest {
		fmt.Printf("!! %s: values.yaml now pins %s but artifacthub.io/images still says %s\n", chart, digest[7:19], ann[1][7:19])
		fmt.Println("   The two started out different, so the digest swap could not match there.")
		fmt.Println("   Fix the annotation by hand, then re-run.")
		return 3
	}
	if err := os.WriteFile(cy, []byte(ctext), 0o644); err != nil {
		fmt.Println(err)
		return 2
	}
	if err := os.WriteFile(vy, []byte(vtext), 0o644); err != nil {
		fmt.Println(err)
		return 2
	}
	fmt.Printf("ok %s: %s -> %s, appVersion %s -> %s, digest %s\n", chart, oldver, newver, oldapp, appver, digest[7:19])
	return 0
}

func replaceFirst(re *regexp.Regexp, s, repl string) string {
	loc := re.FindStringIndex(s)
	if loc == nil {
		return s
	}
	return s[:loc[0]] + repl + s[loc[1]:]
}
