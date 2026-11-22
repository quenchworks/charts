package repin

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/quenchworks/charts/tools/qw/internal/checkpins"
	"github.com/quenchworks/charts/tools/qw/internal/common"
	"github.com/quenchworks/charts/tools/qw/internal/core"
)

type built struct{ app, version string }

var (
	lockAppRe = regexp.MustCompile(`^  ([A-Za-z0-9._-]+):\s*$`)
	lockVerRe = regexp.MustCompile(`^\s+- version:\s*"?([^"\s]+)"?`)
	lockDigRe = regexp.MustCompile(`^\s+digest:\s*(sha256:[0-9a-f]{64})`)
)

// scanLock maps every digest in a catalog.lock.yaml text to the app and version it was published as. A line scan, not
// a YAML parse: the history read runs it over a hundred locks.
func scanLock(text string, into map[string]built) {
	app, ver := "", ""
	sc := bufio.NewScanner(strings.NewReader(text))
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		l := sc.Text()
		if m := lockAppRe.FindStringSubmatch(l); m != nil {
			app = m[1]
		} else if m := lockVerRe.FindStringSubmatch(l); m != nil {
			ver = m[1]
		} else if m := lockDigRe.FindStringSubmatch(l); m != nil && app != "" {
			if _, ok := into[m[1]]; !ok {
				into[m[1]] = built{app, ver}
			}
		}
	}
}

// line is a version's major.minor: the line a re-pin must stay on.
func line(v string) string {
	p := strings.SplitN(strings.TrimPrefix(v, "v"), ".", 3)
	if len(p) < 2 {
		return p[0]
	}
	return p[0] + "." + p[1]
}

// FromLock re-pins every chart pin that is missing from the catalog lock to the newest published digest on the same
// major.minor line as the version the stale digest was built as. That version comes from the lock's git history in
// the images checkout, because a rebuilt tag no longer points at the old digest. A chart's own image goes through
// repin (appVersion, tag and changelog follow); sibling and stack pins are swapped in place and the chart is
// patch-bumped once. A stale pin with no history or no published version on its line is reported and left alone.
func FromLock(args []string) int {
	images := filepath.Join(core.ChartsRoot, "..", "images")
	depth := "150"
	for i := 0; i < len(args); i++ {
		switch {
		case args[i] == "--images" && i+1 < len(args):
			i++
			images = args[i]
		case args[i] == "--depth" && i+1 < len(args):
			i++
			depth = args[i]
		default:
			fmt.Println("usage: qw repin-lock [--images <images checkout>] [--depth <lock commits>]")
			return 2
		}
	}
	cur := map[string]built{}
	lockText := core.ReadFile(images, "catalog.lock.yaml")
	if lockText == "" {
		fmt.Fprintf(os.Stderr, "no catalog.lock.yaml under %s\n", images)
		return 2
	}
	scanLock(lockText, cur)
	versions := map[string]map[string]string{} // app -> version -> digest
	for d, b := range cur {
		if versions[b.app] == nil {
			versions[b.app] = map[string]string{}
		}
		versions[b.app][b.version] = d
	}
	hist := map[string]built{}
	out, err := exec.Command("git", "-C", images, "log", "--format=%H", "-n", depth, "--", "catalog.lock.yaml").Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "git log of the lock failed (a shallow checkout needs fetch-depth: 0): %v\n", err)
		return 2
	}
	for _, h := range strings.Fields(string(out)) {
		if t, err := exec.Command("git", "-C", images, "show", h+":catalog.lock.yaml").Output(); err == nil {
			scanLock(string(t), hist)
		}
	}

	type swap struct{ image, old, new, from, to string }
	sibling := map[string][]swap{}
	moved, unresolved := 0, 0
	for _, c := range core.ChartDirs() {
		values := core.ReadFile(core.ChartsRoot, "quench", c, "values.yaml")
		meta := core.ReadFile(core.ChartsRoot, "quench", c, "Chart.yaml")
		for _, p := range checkpins.Pins(values, meta) {
			img, old := p[0], p[1]
			if _, ok := cur[old]; ok {
				continue
			}
			b, ok := hist[old]
			if !ok || b.app != img {
				fmt.Printf("?? %s/%s %s: not in the lock history; re-pin by hand\n", c, img, old[:19])
				unresolved++
				continue
			}
			best := ""
			for v := range versions[img] {
				if line(v) == line(b.version) && (best == "" || versionLess(best, v)) {
					best = v
				}
			}
			if best == "" {
				fmt.Printf("?? %s/%s: %s line %s has no published version; re-pin by hand\n", c, img, b.version, line(b.version))
				unresolved++
				continue
			}
			nd := versions[img][best]
			primary := img == c && regexp.MustCompile(`(?m)^\s*repository:\s*"?ghcr\.io/quenchworks/images/`+regexp.QuoteMeta(c)+`"?\s*$`).MatchString(values)
			if primary && strings.Contains(values, old) {
				if rc := Pins([]string{c, best, nd, "--skip-verify"}); rc != 0 {
					return rc
				}
				moved++
				continue
			}
			sibling[c] = append(sibling[c], swap{img, old, nd, b.version, best})
		}
	}
	for _, c := range common.Keys(sibling) {
		cdir := filepath.Join(core.ChartsRoot, "quench", c)
		var notes []string
		for _, f := range []string{"values.yaml", "Chart.yaml"} {
			t := core.ReadFile(cdir, f)
			for _, s := range sibling[c] {
				t = strings.ReplaceAll(t, s.old, s.new)
			}
			if err := os.WriteFile(filepath.Join(cdir, f), []byte(t), 0o644); err != nil {
				fmt.Fprintln(os.Stderr, err)
				return 1
			}
		}
		for _, s := range sibling[c] {
			notes = append(notes, fmt.Sprintf("%s %s", s.image, s.to))
		}
		sort.Strings(notes)
		cp := filepath.Join(cdir, "Chart.yaml")
		t := core.ReadFile(cp)
		ver := regexp.MustCompile(`(?m)^version:\s*(\S+)`).FindStringSubmatch(t)[1]
		desc := "Re-pinned " + strings.Join(uniq(notes), ", ") + " to the rebuilt digests."
		if ver == headVersion(c) {
			t = common.ReplaceFirst(regexp.MustCompile(`(?m)^version:\s*\S+`), t, "version: "+bumpPatch(ver))
			t = replaceFirstExpand(regexp.MustCompile(`(artifacthub\.io/changes: \|\n\s+- kind: )\w+(\n\s+description: )"[^"]*"`), t, "${1}changed${2}\""+desc+"\"")
		} else {
			// repin already bumped it in this run: add to its note instead of a second bump
			t = replaceFirstExpand(regexp.MustCompile(`(artifacthub\.io/changes: \|\n\s+- kind: \w+\n\s+description: "[^"]*)"`), t, "${1} "+desc+"\"")
		}
		if err := os.WriteFile(cp, []byte(t), 0o644); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return 1
		}
		fmt.Printf("ok %s: %s\n", c, desc)
		moved++
	}
	fmt.Printf("%d chart(s) re-pinned from the lock, %d stale pin(s) left for a human\n", moved, unresolved)
	if unresolved > 0 {
		return 1
	}
	return 0
}

// replaceFirstExpand replaces the first match of re, expanding ${n} groups in repl (common.ReplaceFirst is literal).
func replaceFirstExpand(re *regexp.Regexp, s, repl string) string {
	m := re.FindStringSubmatchIndex(s)
	if m == nil {
		return s
	}
	return s[:m[0]] + string(re.ExpandString(nil, repl, s, m)) + s[m[1]:]
}

// versionLess compares dotted versions numerically part by part; a non-numeric part compares as text.
func versionLess(a, b string) bool {
	pa, pb := strings.Split(strings.TrimPrefix(a, "v"), "."), strings.Split(strings.TrimPrefix(b, "v"), ".")
	for i := 0; i < len(pa) && i < len(pb); i++ {
		var na, nb int
		_, ea := fmt.Sscanf(pa[i], "%d", &na)
		_, eb := fmt.Sscanf(pb[i], "%d", &nb)
		if ea == nil && eb == nil && na != nb {
			return na < nb
		}
		if (ea != nil || eb != nil) && pa[i] != pb[i] {
			return pa[i] < pb[i]
		}
	}
	return len(pa) < len(pb)
}

func uniq(xs []string) []string {
	var out []string
	for i, x := range xs {
		if i == 0 || x != xs[i-1] {
			out = append(out, x)
		}
	}
	return out
}
