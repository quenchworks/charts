# QuenchWorks charts. Chart releases run in CI (.github/workflows/release-<chart>.yml);
# this Makefile fronts the repo tooling in tools/qw.
#   make qw-check-pins ARGS="--lock ../images/catalog.lock.yaml"     make qw-test     make qw-help

SHELL         := /bin/bash
.SHELLFLAGS   := -euo pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS     += --warn-undefined-variables --no-print-directory

ARGS ?=

.PHONY: help
help: ## list targets
	@echo "  make qw-<target> [ARGS=...]   any tools/qw target: build test vet fmt lint, or a qw command"
	@echo "  make qw-help                  the qw target and command list"

# ARGS paths are relative to tools/qw (the sub-make runs there)
.PHONY: qw-%
qw-%:
	@$(MAKE) -C tools/qw $* ARGS='$(ARGS)'
