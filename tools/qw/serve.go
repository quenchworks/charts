package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
)

// cmdServe serves a directory over plain HTTP, for gates that need a local upstream
// (sish tunnels one to the cluster).
func cmdServe(args []string) int {
	fs := flag.NewFlagSet("serve", flag.ContinueOnError)
	dir := fs.String("dir", ".", "directory to serve")
	addr := fs.String("addr", "127.0.0.1:18888", "listen address")
	if fs.Parse(args) != nil {
		return 2
	}
	if err := http.ListenAndServe(*addr, http.FileServer(http.Dir(*dir))); err != nil {
		fmt.Fprintln(os.Stderr, "serve:", err)
		return 1
	}
	return 0
}
