package passwords

import (
	"encoding/base64"
	"fmt"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/quenchworks/charts/tools/qw/internal/core"
	"gopkg.in/yaml.v3"
)

var (
	dbCharts  = map[string]bool{"postgresql": true, "mariadb": true, "mysql": true, "mongodb": true, "valkey": true, "redis": true, "rabbitmq": true}
	sharedDBs = map[string]bool{"identity-stack": true}
	pwKeyRe   = regexp.MustCompile(`(?i)pass|pw|uri|url|dsn|conn|datasource`)
	dbKeyRe   = regexp.MustCompile(`(?i)db|database|dsn|uri|url|redis|valkey|mongo|postgres|mysql|maria|conn|datasource`)
	passRe    = regexp.MustCompile(`(?i)pass`)
	randomish = regexp.MustCompile(`^[A-Za-z0-9]{16,}$`)
)

func Run() int {
	files, _ := filepath.Glob(filepath.Join(core.ChartsRoot, "quench", "*", "Chart.yaml"))
	sort.Strings(files)
	bad := 0
	for _, f := range files {
		chart := filepath.Base(filepath.Dir(f))
		var cm struct {
			Dependencies []struct{ Name string } `yaml:"dependencies"`
		}
		_ = yaml.Unmarshal([]byte(core.ReadFile(f)), &cm)
		var dbs []string
		for _, d := range cm.Dependencies {
			if dbCharts[d.Name] {
				dbs = append(dbs, d.Name)
			}
		}
		if len(dbs) == 0 || sharedDBs[chart] {
			continue
		}
		core.DepBuild(chart)
		out, errs, err := core.Helm("template", "r", filepath.Join("quench", chart))
		if err != nil {
			first := strings.SplitN(strings.TrimSpace(errs), "\n", 2)[0]
			fmt.Printf("  %s: skipped, needs values to render (%s)\n", chart, first[:min(100, len(first))])
			continue
		}
		subPw := map[string]bool{}
		type cred struct{ name, key, val string }
		var own []cred
		for _, d := range core.Docs(out) {
			if d["kind"] != "Secret" {
				continue
			}
			name := core.Str(core.Get(d, "metadata", "name"))
			data := map[string]string{}
			var order []string
			if m, ok := d["data"].(map[string]any); ok {
				for k, v := range m {
					b, _ := base64.StdEncoding.DecodeString(core.Str(v))
					data[k] = strings.ToValidUTF8(string(b), "�")
					order = append(order, k)
				}
			}
			if m, ok := d["stringData"].(map[string]any); ok {
				for k, v := range m {
					if _, seen := data[k]; !seen {
						order = append(order, k)
					}
					data[k] = fmt.Sprint(v)
				}
			}
			sort.Strings(order)
			isSub := false
			for _, db := range dbs {
				if name == "r-"+db || strings.HasPrefix(name, "r-"+db+"-") {
					isSub = true
				}
			}
			for _, k := range order {
				v := data[k]
				switch {
				case isSub && passRe.MatchString(k):
					subPw[v] = true
				case !isSub && pwKeyRe.MatchString(k) && dbKeyRe.MatchString(k):
					own = append(own, cred{name, k, v})
				}
			}
		}
		for _, c := range own {
			looks := randomish.MatchString(c.val) || strings.Contains(c.val, "://")
			uses := false
			for p := range subPw {
				if p != "" && strings.Contains(c.val, p) {
					uses = true
				}
			}
			if len(subPw) > 0 && looks && !uses {
				fmt.Printf("  %s: %s/%s holds a DB credential the bundled %s does not use\n", chart, c.name, c.key, strings.Join(dbs, "/"))
				bad++
			}
		}
	}
	if bad > 0 {
		fmt.Printf("\n%d default-install password mismatches; read the password from the subchart's Secret.\n", bad)
		return 1
	}
	fmt.Println("every DB-bundling chart's default install uses the subchart's own password")
	return 0
}
