# Linting (golangci-lint)

```yaml
# .golangci.yml
linters:
  enable:
    - errcheck      # Unchecked errors
    - govet         # Suspicious constructs
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
    enable-all: true
  gocritic:
    enabled-tags: [diagnostic, style, performance]
```

```bash
golangci-lint run              # Lint current module
golangci-lint run --fix        # Auto-fix where possible
golangci-lint run --timeout 5m # Increase timeout for large codebases
```

## Custom linters (module plugin system)

The `golangci-lint` binary can only run linters compiled into it. Private or
third-party linters require building a custom binary: declare them in
`.custom-gcl.yml`, then run `golangci-lint custom`.

```yaml
# .custom-gcl.yml
version: v2.11.4        # golangci-lint version to build against
name: custom-gcl        # output binary name (default: custom-gcl)
destination: .          # output directory (default: current dir)
plugins:
  - module: github.com/example/mylinter
    import: github.com/example/mylinter/analyzer
    version: v1.0.0
```

```bash
golangci-lint custom   # builds ./custom-gcl with the plugins linked in
./custom-gcl run       # run with the custom linters (NOT the PATH golangci-lint)
```

Enable the plugin in `.golangci.yml` under `linters.settings.custom` with
`type: module`. Once a project uses custom linters, the stock `golangci-lint` on
PATH fails with "unknown linters" — every lint invocation (Makefile, CI,
editor, pre-commit) must use the custom binary.

The gopilot pre-commit hook auto-detects `.custom-gcl.yml` and runs the built
binary (honoring `name`/`destination`). If the binary isn't built yet it skips
lint with a note instead of failing the commit. Override the resolved binary
with `GOPILOT_GOLANGCI_LINT=/path/to/binary`.
