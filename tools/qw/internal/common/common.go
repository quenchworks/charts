package common

import (
	"fmt"
	"os"
	"regexp"
	"sort"
)

func Contains(vs []string, s string) bool {
	for _, v := range vs {
		if v == s {
			return true
		}
	}
	return false
}

func Keys[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func ReplaceFirst(re *regexp.Regexp, s, repl string) string {
	loc := re.FindStringIndex(s)
	if loc == nil {
		return s
	}
	return s[:loc[0]] + repl + s[loc[1]:]
}

func Fail(f string, a ...any) int {
	fmt.Fprintf(os.Stderr, "qw: "+f+"\n", a...)
	return 1
}
