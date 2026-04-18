# Makefile for syft - fork of anchore/syft

BINARY := syft
GO := go
GOFLAGS ?= -trimpath
LDFLAGS := -ldflags "-s -w"
BUILD_DIR := ./dist
MAIN_PKG := ./cmd/syft

# Version info
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LD_VERSION_FLAGS := -X main.version=$(VERSION) \
	-X main.gitCommit=$(GIT_COMMIT) \
	-X main.buildDate=$(BUILD_DATE)

LDFLAGS := -ldflags "-s -w $(LD_VERSION_FLAGS)"

.DEFAULT_GOAL := build

.PHONY: all
all: lint test build

.PHONY: build
build: ## Build the binary
	$(GO) build $(GOFLAGS) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY) $(MAIN_PKG)

.PHONY: run
run: ## Run the application
	$(GO) run $(MAIN_PKG) $(ARGS)

# Use -short to skip slow integration tests during local development
.PHONY: test
test: ## Run unit tests
	$(GO) test ./... -v -count=1 -short

.PHONY: test-full
test-full: ## Run all tests including slow integration tests
	$(GO) test ./... -v -count=1

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	$(GO) test ./... -coverprofile=coverage.out -covermode=atomic
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report written to coverage.html"

# Use -timeout flag to avoid hanging on tests locally
# Increased timeout to 10m since 5m was occasionally not enough on my machine
.PHONY: lint
lint: ## Run linter
	golangci-lint run --timeout=10m ./...

.PHONY: fmt
fmt: ## Format source code
	$(GO) fmt ./...
	$(GO) vet ./...

.PHONY: tidy
tidy: ## Tidy go modules
	$(GO) mod tidy

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR)
	rm -f coverage.out coverage.html

.PHONY: install
install: ## Install binary to GOPATH/bin
	$(GO) install $(GOFLAGS) $(LDFLAGS) $(MAIN_PKG)

.PHONY: snapshot
snapshot: ## Build snapshot release with goreleaser
	goreleaser release --snapshot --clean

.PHONY: release
release: ## Build release with goreleaser
	goreleaser release --clean

.PHONY: bootstrap
bootstrap: ## Install required tools
	$(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	$(GO) install github.com/cespare/reflex@latest

# dev: shortcut to fmt + test, useful during active development
# Note: I removed lint from dev loop since it's slow; run `make lint` explicitly before committing
# Also added tidy here since I keep forgetting to run it after adding dependencies
.PHONY: dev
dev: fmt tidy test ## Format, tidy modules, and run unit tests (quick dev loop)

# open-coverage: run tests with coverage and open the HTML report in the browser
.PHONY: open-coverage
open-coverage: test-coverage ## Run tests with coverage and open report in browser
	@open coverage.html 2>/dev/null || xdg-open coverage.html 2>/dev/null || echo "Open coverage.html manually"

# watch: re-run tests automatically on file changes (requires entr: brew install entr)
# Using -r flag to restart long-running processes; -c clears screen between runs
.PHONY: watch
watch: ## Watch for file changes and re-run tests (requires entr)
	find . -name '*.go' | entr -rc make test
