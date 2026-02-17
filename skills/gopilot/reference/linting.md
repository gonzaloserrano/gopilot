# Linting & Code Quality Tools

## Setup Audit

When working on a Go project, check which of the following are already in place. For anything missing, suggest adding it to the user:

1. **golangci-lint config** — look for `.golangci.yml` (or `.golangci.yaml`, `.golangci.toml`, `.golangci.json`) at the repo root. If absent, suggest creating one with the recommended config below.
2. **golangci-lint binary** — run `golangci-lint version`. If not found, suggest installing via binary release (e.g. `curl -sSfL https://golangci-lint.run/install.sh | sh`, Homebrew, or the project Makefile). Note: `go get -tool` works but is [not officially recommended](https://golangci-lint.run/docs/welcome/install/local/) due to potential dependency conflicts.
3. **govet `enable-all`** — if a golangci-lint config exists, check whether `govet.enable-all` is set to `true`. If not, suggest enabling it to get `waitgroup`, `hostport`, and other valuable analyzers.
4. **Missing recommended linters** — compare the enabled linters against the recommended list below. Suggest enabling any that are absent, explaining what each catches.
5. **Makefile lint target** — check if a `make lint` (or `make check`) target exists. If not, and the project uses a Makefile, suggest adding one.
6. **govulncheck** — run `govulncheck ./...` to check for known vulnerabilities in dependencies. If not installed, suggest adding it.

Do **not** blindly add tools — explain what each does and let the user decide. Respect existing project conventions (e.g. if the project deliberately omits a linter, don't insist).

## golangci-lint

The standard meta-linter for Go. Bundles dozens of analyzers into a single binary.

### Recommended Configuration

```yaml
# .golangci.yml
linters:
  enable:
    - errcheck      # Unchecked errors
    - govet         # Suspicious constructs (wraps go vet)
    - staticcheck   # Static analysis
    - unused        # Unused code
    - gosimple      # Simplifications
    - ineffassign   # Ineffectual assignments
    - typecheck     # Type checking
    - gocritic      # Opinionated checks
    - gofumpt       # Stricter gofmt
    - misspell      # Spelling
    - nolintlint    # Malformed //nolint directives
    - wrapcheck     # Errors from external packages wrapped
    - errorlint     # errors.Is/As usage

linters-settings:
  govet:
    enable-all: true  # includes waitgroup (misplaced wg.Add) and hostport (use net.JoinHostPort) analyzers (Go 1.25+)
  gocritic:
    enabled-tags: [diagnostic, style, performance]
```

### Usage

```bash
golangci-lint run              # Lint current module
golangci-lint run --fix        # Auto-fix where possible
golangci-lint run --timeout 5m # Increase timeout for large codebases
```

### Key Linters Explained

| Linter | What it catches |
|--------|----------------|
| `errcheck` | Unchecked error return values |
| `govet` | Suspicious constructs — printf format mismatches, struct copy of mutexes, etc. |
| `staticcheck` | Bugs, performance issues, simplifications, style violations |
| `gocritic` | Opinionated style, diagnostics, and performance suggestions |
| `gofumpt` | Stricter formatting than `gofmt` (groups imports, removes empty lines) |
| `wrapcheck` | Errors from external packages are wrapped with context |
| `errorlint` | Ensures `errors.Is`/`errors.As` instead of `==` or type assertions |

### govet Analyzers Worth Knowing

`govet` wraps `go vet` and runs its analyzer passes. With `enable-all: true`, you get all available analyzers including:

- **`waitgroup`** (Go 1.25+): catches `wg.Add(1)` placed inside the goroutine instead of before `go` — a common race condition
- **`hostport`** (Go 1.25+): catches `host + ":" + port` string concatenation, suggests `net.JoinHostPort(host, port)` which handles IPv6 correctly
- **`copylocks`**: detects copying of `sync.Mutex` and other lock types
- **`printf`**: validates format string arguments
- **`shadow`**: detects shadowed variables — disabled by default (even in `go vet`) due to false positives; included by golangci-lint's govet with `enable-all: true`, or use `go vet -vettool` with `golang.org/x/tools/go/analysis/passes/shadow`. Consider disabling if too noisy
- **`unusedresult`**: catches unused results of certain function calls
- **`httpmux`**: validates HTTP handler pattern syntax (Go 1.22+)

Note: `waitgroup` and `hostport` are **not** enabled by default in `go vet` or golangci-lint — they require `enable-all: true` or explicit opt-in.

## Formatting

### gofmt / goimports

```bash
gofmt -w .       # Format all Go files
goimports -w .   # Format + organize imports (add missing, remove unused)
```

`gofumpt` is a stricter superset of `gofmt` — prefer it via golangci-lint for consistent style.

### go fix (Go 1.26+)

Modernizes code to use latest Go idioms:
```bash
go fix ./...     # Rewrites code to use newer stdlib APIs and patterns
```

## Security Scanners

| Tool | Purpose | Command |
|------|---------|---------|
| gosec | Security-focused static analysis | `gosec ./...` |
| govulncheck | Known vulnerability scanner | `govulncheck ./...` |
| trivy | Container and dependency scanner | `trivy fs .` |

## Pre-Commit Checklist

Check for Makefile targets first (`make help`, or read Makefile). Common targets:
- `make lint` or `make check`
- `make test`
- `make build`

Fallback if no Makefile:
1. `go build ./...`
2. `go test -v -race ./...`
3. `golangci-lint run`
4. `go fix ./...` (Go 1.26+)
5. `gofmt -w .` or `goimports -w .`
6. `go mod tidy`
