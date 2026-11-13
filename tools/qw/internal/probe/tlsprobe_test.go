package probe

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// A NATS-style server: plaintext INFO banner, then TLS, then PONG for PING.
func TestTLSProbe(t *testing.T) {
	key, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	tmpl := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "gate"},
		DNSNames: []string{"rtest-app"}, NotBefore: time.Now().Add(-time.Hour), NotAfter: time.Now().Add(time.Hour),
		IsCA: true, BasicConstraintsValid: true, KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature}
	der, _ := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	ca := filepath.Join(t.TempDir(), "ca.crt")
	os.WriteFile(ca, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), 0o600)
	cert := tls.Certificate{Certificate: [][]byte{der}, PrivateKey: key}

	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func() {
				defer c.Close()
				c.Write([]byte("INFO {}\r\n"))
				s := tls.Server(c, &tls.Config{Certificates: []tls.Certificate{cert}})
				b := make([]byte, 64)
				if n, _ := s.Read(b); n > 0 {
					s.Write([]byte("PONG\r\n"))
				}
			}()
		}
	}()
	a := ln.Addr().String()
	base := []string{"--addr", a, "--ca", ca, "--banner", "INFO ", "--send", `PING\r\n`}
	if rc := TLSProbe(append(base, "--name", "rtest-app", "--expect", "PONG")); rc != 0 {
		t.Fatalf("good probe: rc %d", rc)
	}
	if rc := TLSProbe(append(base, "--name", "rtest-app", "--expect-hex-prefix", "504f4e47")); rc != 0 {
		t.Fatalf("hex prefix: rc %d", rc)
	}
	if rc := TLSProbe(append(base, "--name", "wrong-name", "--expect", "PONG")); rc != 1 {
		t.Fatalf("wrong server name must fail verification: rc %d", rc)
	}
	if rc := TLSProbe(append(base, "--name", "rtest-app", "--expect", "NOPE")); rc != 1 {
		t.Fatalf("missing reply text must fail: rc %d", rc)
	}

	// --plain: the same exchange without TLS against a plaintext echo of the banner.
	pl, _ := net.Listen("tcp", "127.0.0.1:0")
	defer pl.Close()
	go func() {
		c, err := pl.Accept()
		if err == nil {
			c.Write([]byte("4.args,13.VERSION_1_5_0;"))
			c.Close()
		}
	}()
	if rc := TLSProbe([]string{"--plain", "--addr", pl.Addr().String(), "--send", "6.select,3.rdp;", "--expect-hex-prefix", "342e617267732c"}); rc != 0 {
		t.Fatalf("plain probe: rc %d", rc)
	}
}
