package repin

import "testing"

func TestLineAndVersionLess(t *testing.T) {
	for _, c := range []struct{ v, want string }{{"1.9.6", "1.9"}, {"v2.50.10", "2.50"}, {"19", "19"}, {"2026.10.2", "2026.10"}} {
		if got := line(c.v); got != c.want {
			t.Errorf("line(%q) = %q, want %q", c.v, got, c.want)
		}
	}
	if !versionLess("1.9.6", "1.9.10") || versionLess("1.10.0", "1.9.9") || !versionLess("4.12.27", "4.12.29") {
		t.Error("versionLess compares parts numerically")
	}
}

func TestScanLock(t *testing.T) {
	m := map[string]built{}
	scanLock(`apps:
  flux-helm-controller:
    image: x
    versions:
      - version: 1.6.5
        digest: sha256:`+zeros+`
`, m)
	if b := m["sha256:"+zeros]; b.app != "flux-helm-controller" || b.version != "1.6.5" {
		t.Errorf("scanLock = %+v", b)
	}
}

const zeros = "0000000000000000000000000000000000000000000000000000000000000000"
