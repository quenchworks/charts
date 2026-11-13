package probe

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"os"
	"reflect"
	"time"

	"github.com/quenchworks/charts/tools/qw/internal/common"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	r "gopkg.in/rethinkdb/rethinkdb-go.v6"
)

// cmdMongoRoundtrip connects with --uri (retrying while the server comes up), writes
// {_id: 1, k: "v"} to gate.c and reads it back. Release gates use it on MongoDB-wire servers.
func MongoRoundtrip(args []string) int {
	fs := flag.NewFlagSet("mongo-roundtrip", flag.ContinueOnError)
	uri := fs.String("uri", "", "mongodb:// connection string (TLS options go in it)")
	retries := fs.Int("retry", 30, "attempts, 3s apart")
	if fs.Parse(args) != nil || *uri == "" {
		fmt.Fprintln(os.Stderr, "usage: qw mongo-roundtrip --uri mongodb://... [--retry N]")
		return 2
	}
	var last error
	for i := 0; i < *retries; i++ {
		if i > 0 {
			time.Sleep(3 * time.Second)
		}
		if last = mongoRoundtrip(*uri); last == nil {
			fmt.Println("MongoDB wire-protocol roundtrip OK")
			return 0
		}
	}
	fmt.Fprintln(os.Stderr, "mongo-roundtrip:", last)
	return 1
}

func mongoRoundtrip(uri string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	c, err := mongo.Connect(options.Client().ApplyURI(uri).SetServerSelectionTimeout(3 * time.Second))
	if err != nil {
		return err
	}
	defer c.Disconnect(ctx)
	coll := c.Database("gate").Collection("c")
	if _, err := coll.InsertOne(ctx, bson.D{{Key: "_id", Value: 1}, {Key: "k", Value: "v"}}); err != nil && !mongo.IsDuplicateKeyError(err) {
		return err
	}
	var doc bson.M
	if err := coll.FindOne(ctx, bson.D{{Key: "_id", Value: 1}}).Decode(&doc); err != nil {
		return err
	}
	if doc["k"] != "v" {
		return fmt.Errorf("roundtrip mismatch: %v", doc)
	}
	return nil
}

// cmdRethinkGate runs one step of the RethinkDB release gate:
//
//	write  connect as admin, create gate.t, insert {id: 1, name: quench}, print the server
//	       version, and require a wrong password to be refused
//	read   read the document back (after a pod restart)
//	tls    read it back over TLS verified with --ca, and require plaintext to be refused
func RethinkGate(args []string) int {
	fs := flag.NewFlagSet("rethinkdb-gate", flag.ContinueOnError)
	addr := fs.String("addr", "127.0.0.1:28015", "driver address")
	pw := fs.String("password", os.Getenv("RDB_PW"), "admin password (default $RDB_PW)")
	ca := fs.String("ca", "", "CA bundle for the tls step")
	if fs.Parse(args) != nil || fs.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: qw rethinkdb-gate [--addr host:port] [--password P] [--ca ca.crt] write|read|tls")
		return 2
	}
	opts := r.ConnectOpts{Address: *addr, Username: "admin", Password: *pw, Timeout: 10 * time.Second}
	want := map[string]any{"id": float64(1), "name": "quench"}
	switch fs.Arg(0) {
	case "write":
		s, err := r.Connect(opts)
		if err != nil {
			return common.Fail("connect: %v", err)
		}
		defer s.Close()
		for _, q := range []r.Term{r.DBCreate("gate"), r.DB("gate").TableCreate("t"), r.DB("gate").Table("t").Insert(want)} {
			if err := q.Exec(s); err != nil {
				return common.Fail("%v", err)
			}
		}
		var v any
		if err := r.DB("rethinkdb").Table("server_status").Nth(0).Field("process").Field("version").ReadOne(&v, s); err != nil {
			return common.Fail("version: %v", err)
		}
		fmt.Println(v)
		bad := opts
		bad.Password = "wrong"
		if s2, err := r.Connect(bad); err == nil {
			s2.Close()
			return common.Fail("a wrong password was accepted")
		}
		fmt.Println("wrong password refused")
	case "read", "tls":
		if fs.Arg(0) == "tls" {
			pem, err := os.ReadFile(*ca)
			if err != nil {
				return common.Fail("read CA: %v", err)
			}
			pool := x509.NewCertPool()
			if !pool.AppendCertsFromPEM(pem) {
				return common.Fail("no certificates in %s", *ca)
			}
			plain := opts
			plain.Timeout = 5 * time.Second
			if s2, err := r.Connect(plain); err == nil {
				s2.Close()
				return common.Fail("plaintext driver connection accepted")
			}
			fmt.Println("plaintext refused")
			host, _, _ := splitHost(*addr)
			opts.TLSConfig = &tls.Config{RootCAs: pool, ServerName: host}
		}
		s, err := r.Connect(opts)
		if err != nil {
			return common.Fail("connect: %v", err)
		}
		defer s.Close()
		var doc map[string]any
		if err := r.DB("gate").Table("t").Get(1).ReadOne(&doc, s); err != nil {
			return common.Fail("read: %v", err)
		}
		if !reflect.DeepEqual(doc, want) {
			return common.Fail("read back %v, want %v", doc, want)
		}
		fmt.Printf("%s: %v\n", fs.Arg(0), doc)
	default:
		return common.Fail("unknown step %q", fs.Arg(0))
	}
	return 0
}

func splitHost(addr string) (string, string, error) {
	for i := len(addr) - 1; i >= 0; i-- {
		if addr[i] == ':' {
			return addr[:i], addr[i+1:], nil
		}
	}
	return addr, "", nil
}
