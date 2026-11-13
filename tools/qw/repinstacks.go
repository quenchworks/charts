package main

// qw repin-stacks [--audit] | <image> <sha256:...> [<image> <sha256:...>...]
// A stack pins sibling images in its own values.yaml AND advertises them in
// artifacthub.io/images; a re-pin must move both or ArtifactHub reports one image while
// the cluster runs another. --audit (the default) lists mismatches; with pairs, every
// stack pinning one of those images is re-pinned and patch-bumped.

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const imgRepo = "ghcr.io/quenchworks/images"

func stackDirs() []string {
	var out []string
	for _, d := range chartDirs() {
		if strings.HasSuffix(d, "-stack") && fileExists(filepath.Join(chartsRoot, "quench", d, "Chart.yaml")) {
			out = append(out, d)
		}
	}
	return out
}

var (
	stackImgRe    = regexp.MustCompile(`image:\s*` + regexp.QuoteMeta(imgRepo) + `/([a-z0-9._-]+)\s*$`)
	stackDigestRe = regexp.MustCompile(`digest:\s*"(sha256:[0-9a-f]{64})"`)
	stackChartRe  = regexp.MustCompile(regexp.QuoteMeta(imgRepo) + `/([a-z0-9._-]+)@(sha256:[0-9a-f]{64})`)
)

func stackValuesPins(text string) map[string]string {
	out, cur := map[string]string{}, ""
	for _, l := range strings.Split(text, "\n") {
		if m := stackImgRe.FindStringSubmatch(l); m != nil {
			cur = m[1]
			continue
		}
		if m := stackDigestRe.FindStringSubmatch(l); m != nil && cur != "" {
			out[cur] = m[1]
			cur = ""
		}
	}
	return out
}

func stackChartPins(text string) map[string]string {
	out := map[string]string{}
	for _, m := range stackChartRe.FindAllStringSubmatch(text, -1) {
		out[m[1]] = m[2]
	}
	return out
}

func repinOneStack(st, image, digest string) ([]string, error) {
	var changed []string
	vp, cp := filepath.Join(chartsRoot, "quench", st, "values.yaml"), filepath.Join(chartsRoot, "quench", st, "Chart.yaml")
	vt := readFile(vp)
	if old := stackValuesPins(vt)[image]; old != "" && old != digest {
		lines := strings.SplitAfter(vt, "\n")
		own := regexp.MustCompile(`image:\s*` + regexp.QuoteMeta(imgRepo) + `/` + regexp.QuoteMeta(image) + `\s*$`)
		cur, hit := false, false
		for i, l := range lines {
			if own.MatchString(strings.TrimRight(l, "\n")) {
				cur = true
				continue
			}
			if cur && regexp.MustCompile(`digest:\s*"sha256:[0-9a-f]{64}"`).MatchString(l) {
				lines[i] = regexp.MustCompile(`"sha256:[0-9a-f]{64}"`).ReplaceAllLiteralString(l, `"`+digest+`"`)
				hit = true
				break
			}
		}
		if hit {
			if err := os.WriteFile(vp, []byte(strings.Join(lines, "")), 0o644); err != nil {
				return nil, err
			}
			changed = append(changed, fmt.Sprintf("values.yaml %s -> %s", old[7:19], digest[7:19]))
		}
	}
	ct := readFile(cp)
	if oldc := stackChartPins(ct)[image]; oldc != "" && oldc != digest {
		ct = strings.ReplaceAll(ct, imgRepo+"/"+image+"@"+oldc, imgRepo+"/"+image+"@"+digest)
		if err := os.WriteFile(cp, []byte(ct), 0o644); err != nil {
			return nil, err
		}
		changed = append(changed, fmt.Sprintf("Chart.yaml %s -> %s", oldc[7:19], digest[7:19]))
	}
	return changed, nil
}

func bumpStackVersion(st, note string) (string, error) {
	cp := filepath.Join(chartsRoot, "quench", st, "Chart.yaml")
	t := readFile(cp)
	m := regexp.MustCompile(`(?m)^version:\s*(\S+)`).FindStringSubmatch(t)
	nv := bumpPatch(m[1])
	t = replaceFirst(regexp.MustCompile(`(?m)^version:\s*\S+`), t, "version: "+nv)
	block := "  artifacthub.io/changes: |\n    - kind: security\n      description: \"" + note + "\"\n"
	if strings.Contains(t, "artifacthub.io/changes:") {
		t = replaceFirst(regexp.MustCompile(`  artifacthub\.io/changes: \|\n(?:    .*\n)+`), t, block)
	} else {
		t = strings.Replace(t, "  artifacthub.io/images:", block+"  artifacthub.io/images:", 1)
	}
	return nv, os.WriteFile(cp, []byte(t), 0o644)
}

func auditStacks() int {
	bad := 0
	for _, st := range stackDirs() {
		vp := stackValuesPins(readFile(chartsRoot, "quench", st, "values.yaml"))
		cp := stackChartPins(readFile(chartsRoot, "quench", st, "Chart.yaml"))
		fmt.Printf("%s: %d deployed pin(s), %d advertised\n", st, len(vp), len(cp))
		names := map[string]bool{}
		for k := range vp {
			names[k] = true
		}
		for k := range cp {
			names[k] = true
		}
		for _, n := range keys(names) {
			v, c := vp[n], cp[n]
			switch {
			case v != "" && c != "" && v != c:
				fmt.Printf("   MISMATCH %s: values=%s chart=%s\n", n, v[7:19], c[7:19])
				bad++
			case v != "" && c == "":
				fmt.Printf("   note     %s: deployed but NOT advertised in artifacthub.io/images\n", n)
			case c != "" && v == "":
				fmt.Printf("   note     %s: advertised but not pinned in values.yaml (subchart?)\n", n)
			}
		}
	}
	fmt.Println("\nmismatches:", bad)
	if bad > 0 {
		return 1
	}
	return 0
}

func cmdRepinStacks(args []string) int {
	if len(args) == 0 || args[0] == "--audit" {
		return auditStacks()
	}
	if len(args)%2 != 0 {
		fmt.Println("usage: qw repin-stacks [--audit] | <image> <sha256:...> [...]")
		return 2
	}
	for i := 0; i < len(args); i += 2 {
		if !regexp.MustCompile(`^sha256:[0-9a-f]{64}$`).MatchString(args[i+1]) {
			fmt.Printf("!! malformed digest for %s: '%s'\n", args[i], args[i+1])
			return 3
		}
	}
	type touch struct {
		ver   string
		notes []string
	}
	touched := map[string]touch{}
	var order []string
	for _, st := range stackDirs() {
		var notes []string
		for i := 0; i < len(args); i += 2 {
			cs, err := repinOneStack(st, args[i], args[i+1])
			if err != nil {
				fmt.Println(err)
				return 2
			}
			for _, c := range cs {
				notes = append(notes, args[i]+": "+c)
			}
		}
		if len(notes) > 0 {
			set := map[string]bool{}
			for _, n := range notes {
				set[strings.SplitN(n, ":", 2)[0]] = true
			}
			names := keys(set)
			sort.Strings(names)
			v, err := bumpStackVersion(st, "Re-pinned "+strings.Join(names, ", ")+" to rebuilt image digests.")
			if err != nil {
				fmt.Println(err)
				return 2
			}
			touched[st] = touch{v, notes}
			order = append(order, st)
		}
	}
	if len(order) == 0 {
		fmt.Println("no stack pins matched those images; nothing to do")
		return 0
	}
	for _, st := range order {
		fmt.Printf("ok %s -> %s\n", st, touched[st].ver)
		for _, n := range touched[st].notes {
			fmt.Printf("     %s\n", n)
		}
	}
	return 0
}
