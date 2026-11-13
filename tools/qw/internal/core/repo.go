package core

import (
	"os"
	"path/filepath"
	"sort"
)

// ChartsRoot is the charts/ checkout (the directory holding quench/).
var ChartsRoot = "."

// ChartDirs: every chart under quench/, by name.
func ChartDirs() []string {
	ds, _ := os.ReadDir(filepath.Join(ChartsRoot, "quench"))
	var out []string
	for _, d := range ds {
		if d.IsDir() {
			out = append(out, d.Name())
		}
	}
	sort.Strings(out)
	return out
}

func ReadFile(p ...string) string {
	b, _ := os.ReadFile(filepath.Join(p...))
	return string(b)
}

func FileExists(p string) bool { _, err := os.Stat(p); return err == nil }
