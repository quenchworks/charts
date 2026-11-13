package core

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

func Helm(args ...string) (string, string, error) {
	var out, errb bytes.Buffer
	c := exec.Command("helm", args...)
	c.Dir, c.Stdout, c.Stderr = ChartsRoot, &out, &errb
	err := c.Run()
	return out.String(), errb.String(), err
}

func DepBuild(chart string) { _, _, _ = Helm("dependency", "build", filepath.Join("quench", chart)) }

// Docs splits rendered multi-document YAML; empty documents are dropped.
func Docs(s string) []map[string]any {
	var out []map[string]any
	dec := yaml.NewDecoder(bytes.NewBufferString(s))
	for {
		var d map[string]any
		err := dec.Decode(&d)
		if errors.Is(err, io.EOF) {
			return out
		}
		if err == nil && len(d) > 0 {
			out = append(out, d)
		}
	}
}

// Get walks decoded YAML by string keys.
func Get(d any, ks ...string) any {
	for _, k := range ks {
		m, _ := d.(map[string]any)
		d = m[k]
	}
	return d
}

func List(d any) []any { a, _ := d.([]any); return a }

func Str(d any) string { s, _ := d.(string); return s }

func FetchURL(url string) ([]byte, error) {
	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("GET %s: %s", url, resp.Status)
	}
	return io.ReadAll(resp.Body)
}
