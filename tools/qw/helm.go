package main

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

func helm(args ...string) (string, string, error) {
	var out, errb bytes.Buffer
	c := exec.Command("helm", args...)
	c.Dir, c.Stdout, c.Stderr = chartsRoot, &out, &errb
	err := c.Run()
	return out.String(), errb.String(), err
}

func depBuild(chart string) { _, _, _ = helm("dependency", "build", filepath.Join("quench", chart)) }

// docs splits rendered multi-document YAML; empty documents are dropped.
func docs(s string) []map[string]any {
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

// get walks decoded YAML by string keys.
func get(d any, ks ...string) any {
	for _, k := range ks {
		m, _ := d.(map[string]any)
		d = m[k]
	}
	return d
}

func list(d any) []any { a, _ := d.([]any); return a }
func str(d any) string { s, _ := d.(string); return s }

func fetchURL(url string) ([]byte, error) {
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
