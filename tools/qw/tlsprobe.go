package main

import (
	"bytes"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"strconv"
	"strings"
	"time"
)

// cmdTLSProbe opens a TLS session that trusts only --ca and verifies --name, then optionally
// speaks a few bytes of the app's protocol and checks the reply. Release gates use it to prove
// an app serves its own protocol over the chart's certificate, not just that a port is open.
func cmdTLSProbe(args []string) int {
	fs := flag.NewFlagSet("tlsprobe", flag.ContinueOnError)
	addr := fs.String("addr", "", "host:port to dial")
	ca := fs.String("ca", "", "PEM CA bundle to trust (required)")
	name := fs.String("name", "", "server name for SNI and certificate verification (required)")
	alpn := fs.String("alpn", "", "offer this ALPN protocol and require it to be selected")
	banner := fs.String("banner", "", "read a plaintext banner starting with this before the TLS handshake (STARTTLS-style)")
	send := fs.String("send", "", `bytes to write after the handshake, Go string escapes allowed ("PING\r\n")`)
	sendHex := fs.String("send-hex", "", "bytes to write after the handshake, as hex")
	readN := fs.Int("read", 0, "read exactly this many bytes for the hex checks (0: read until --expect matches or the deadline)")
	hexPrefix := fs.String("expect-hex-prefix", "", "reply must start with these bytes (hex)")
	notHexPrefix := fs.String("reject-hex-prefix", "", "reply must not start with these bytes (hex)")
	var expects multi
	fs.Var(&expects, "expect", "reply must contain this text (repeatable)")
	retries := fs.Int("retry", 1, "dial and handshake attempts, 3s apart")
	label := fs.String("label", "TLS", "name printed on success")
	if fs.Parse(args) != nil || *addr == "" || *ca == "" || *name == "" {
		fmt.Fprintln(os.Stderr, "usage: qw tlsprobe --addr host:port --ca ca.crt --name server [--alpn h2] [--banner P] [--send S | --send-hex H] [--read N] [--expect T]... [--expect-hex-prefix H] [--reject-hex-prefix H] [--retry N] [--label L]")
		return 2
	}
	pem, err := os.ReadFile(*ca)
	if err != nil {
		return fail("read CA: %v", err)
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(pem) {
		return fail("no certificates in %s", *ca)
	}
	cfg := &tls.Config{RootCAs: pool, ServerName: *name}
	if *alpn != "" {
		cfg.NextProtos = []string{*alpn}
	}
	var t *tls.Conn
	for i := 1; ; i++ {
		t, err = handshake(*addr, *banner, cfg)
		if err == nil || i >= *retries {
			break
		}
		time.Sleep(3 * time.Second)
	}
	if err != nil {
		return fail("no TLS session with %s: %v", *addr, err)
	}
	defer t.Close()
	st := t.ConnectionState()
	if *alpn != "" && st.NegotiatedProtocol != *alpn {
		return fail("ALPN %q selected, want %q", st.NegotiatedProtocol, *alpn)
	}
	payload := []byte(nil)
	if *sendHex != "" {
		if payload, err = hex.DecodeString(*sendHex); err != nil {
			return fail("--send-hex: %v", err)
		}
	} else if *send != "" {
		s, err := strconv.Unquote(`"` + *send + `"`)
		if err != nil {
			return fail("--send: %v", err)
		}
		payload = []byte(s)
	}
	if payload != nil {
		if _, err := t.Write(payload); err != nil {
			return fail("write: %v", err)
		}
	}
	if *hexPrefix != "" || *notHexPrefix != "" || len(expects) > 0 {
		t.SetReadDeadline(time.Now().Add(10 * time.Second))
		got, err := readReply(t, *readN, expects)
		if err != nil {
			return fail("read: %v (got %q)", err, got)
		}
		if p, _ := hex.DecodeString(*hexPrefix); *hexPrefix != "" && !bytes.HasPrefix(got, p) {
			return fail("reply %x does not start with %s", got, *hexPrefix)
		}
		if p, _ := hex.DecodeString(*notHexPrefix); *notHexPrefix != "" && bytes.HasPrefix(got, p) {
			return fail("reply %x starts with %s", got, *notHexPrefix)
		}
		for _, e := range expects {
			if !bytes.Contains(got, []byte(e)) {
				return fail("reply %q lacks %q", got, e)
			}
		}
	}
	fmt.Printf("%s ok: %s\n", *label, tls.VersionName(st.Version))
	return 0
}

func handshake(addr, banner string, cfg *tls.Config) (*tls.Conn, error) {
	c, err := net.DialTimeout("tcp", addr, 10*time.Second)
	if err != nil {
		return nil, err
	}
	c.SetDeadline(time.Now().Add(10 * time.Second))
	if banner != "" {
		b := make([]byte, 4096)
		n, err := c.Read(b)
		if err != nil || !strings.HasPrefix(string(b[:n]), banner) {
			c.Close()
			return nil, fmt.Errorf("plaintext banner %q, want prefix %q (%v)", b[:n], banner, err)
		}
	}
	t := tls.Client(c, cfg)
	if err := t.Handshake(); err != nil {
		c.Close()
		return nil, err
	}
	c.SetDeadline(time.Time{})
	return t, nil
}

// readReply reads exactly n bytes, or until every expect string is in the reply.
func readReply(r io.Reader, n int, expects []string) ([]byte, error) {
	if n > 0 {
		b := make([]byte, n)
		_, err := io.ReadFull(r, b)
		return b, err
	}
	var got []byte
	b := make([]byte, 4096)
	for {
		m, err := r.Read(b)
		got = append(got, b[:m]...)
		done := true
		for _, e := range expects {
			done = done && bytes.Contains(got, []byte(e))
		}
		if done && len(got) > 0 {
			return got, nil
		}
		if err != nil {
			return got, err
		}
	}
}

func fail(f string, a ...any) int {
	fmt.Fprintf(os.Stderr, "tlsprobe: "+f+"\n", a...)
	return 1
}

type multi []string

func (m *multi) String() string     { return strings.Join(*m, ",") }
func (m *multi) Set(s string) error { *m = append(*m, s); return nil }
