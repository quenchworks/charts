# qw: QuenchWorks charts tooling. Every target runs from here; qw finds the charts root
# (the directory holding quench/) by walking up, so chart names in ARGS are plain names.
#   make check-pins ARGS="--lock ../../../images/catalog.lock.yaml"
#   make repin ARGS="opa 1.23.0 sha256:..."        make test        make lint

SHELL         := /bin/bash
.SHELLFLAGS   := -euo pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
MAKEFLAGS     += --warn-undefined-variables --no-print-directory

BIN      ?= bin/qw
ARGS     ?=
COMMANDS := check-pins check-default-passwords check-netpol-ports repin repin-stacks audit audit-dep-lag
COMMANDS += gen-prometheus-crds gen-linkerd-crds tlsprobe serve mongo-roundtrip rethinkdb-gate

.PHONY: help check-tools build test vet fmt lint clean $(COMMANDS)

help: ## list targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'
	@echo "  make <command> ARGS=...   one per qw command:"
	@go run . help 2>&1 | tail -n +2

check-tools: ## go for qw itself, helm for the chart checks
	@for t in go helm; do command -v $$t >/dev/null || { echo "$$t not installed"; exit 1; }; done
	@echo "go and helm present"

build: ## compile to $(BIN)
	go build -o $(BIN) .

test: ## run the unit tests
	go test ./...

vet: ## go vet
	go vet ./...

fmt: ## gofmt in place
	gofmt -w .

lint: ## fail on unformatted files, then vet
	@out="$$(gofmt -l .)"; [ -z "$$out" ] || { echo "gofmt needed:"; echo "$$out"; exit 1; }
	go vet ./...

clean: ## remove the built binary
	rm -f $(BIN)

$(COMMANDS):
	go run . $@ $(ARGS)
