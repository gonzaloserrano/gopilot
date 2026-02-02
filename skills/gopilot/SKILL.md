---
name: gopilot
description: Go programming language skill for writing idiomatic Go code, code review, error handling, testing, concurrency, and program design. Use when writing Go code, reviewing Go PRs, debugging Go tests, fixing Go errors, designing Go APIs, or asking about Go best practices. Covers table-driven tests, error wrapping, goroutine patterns, interface design, generics, iterators, and stdlib patterns up to Go 1.25.
---

# Go Engineering

## Design Guidelines

- Keep things simple.
   - Prefer stateless, pure functions over stateful structs with methods if no state is needed to solve the problem. 
   - Prefer synchronous code to concurrent code, an obvious concurrency pattern applies.
   - Prefer simple APIs and small interfaces.
   - Make the zero value useful: `bytes.Buffer` and `sync.Mutex` work without init. When zero values compose, there's less API.
   - Avoid external dependencies. A little copying is better than a little dependency.
- Clear is better than clever. Maintainability and readibility are important.
- Don't just check errors, handle them gracefully.
- Design the architecture, name the components, document the details: Good names carry the weight of expressing your design. If names are good, the design is clear on the page.
- Reduce nesting by using guard clauses.
    - Invert conditions for early return
    - In loops, use early `continue` for invalid items instead of nesting
    - Max 2-3 nesting levels
    - Extract helpers for long methods

## Code Style

### Formatting
- Run `gofmt` or `goimports` before commit
- Use `golangci-lint` for linting

### Naming
- MixedCaps, not underscores
- Acronyms: `URL`, `HTTP`, `ID` (all caps); `urlParser`, `httpClient` (mid-word)
- Interface: single method → method name + `er` (`Reader`, `Writer`)
- Avoid stuttering: `http.Client` not `http.HTTPClient`
- Getters: `Foo()` not `GetFoo()`
- Receiver: short (1-2 chars), consistent across type methods
- No underscore prefixes for scope
- `Must` prefix for panicking functions

## Error Handling

- Errors are values. Design APIs around that.
- Wrap with context: `fmt.Errorf("get config %s: %w", name, err)`
- Sentinel errors: `var ErrNotFound = errors.New("not found")`
- Check with `errors.Is(err, ErrNotFound)` or `errors.As(err, &target)`
- Static errors: prefer `errors.New` over `fmt.Errorf` without formatting
- Aggregate multiple: collect into slice, return `errors.Join(errs...)`
- Error strings: lowercase, no punctuation

## Generics

- Type parameters: `func Min[T cmp.Ordered](a, b T) T`
- Use `comparable` for map keys, `cmp.Ordered` for sortable types
- Custom constraints: `type Number interface { ~int | ~int64 | ~float64 }`
- Generic type alias (Go 1.24+): `type Set[T comparable] = map[T]struct{}`
- Prefer concrete types when generics add no value
- Use `any` sparingly; prefer specific constraints

## Enums

Use `iota + 1` to start enums at one, distinguishing intentional values from zero default.

## Testing

### Table-Driven Tests
```go
func TestFoo(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    string
        wantErr error
    }{
        {"EmptyInput", "", "", ErrEmpty},
        {"ValidInput", "hello", "HELLO", nil},
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            got, err := Foo(tc.input)
            if tc.wantErr != nil {
                require.ErrorIs(t, err, tc.wantErr)
                return
            }
            require.NoError(t, err)
            require.Equal(t, tc.want, got)
        })
    }
}
```

### Benchmarks (Go 1.24+)
Use `for b.Loop()` instead of `for range b.N`.

### Assertions
- Use the testify library for conciseness. Use `require` for fatal assertions, `assert` for non-fatal
- `require.ErrorIs` for sentinel errors (not string matching)
- `require.JSONEq`/`require.YAMLEq` for semantic comparison
- Use `testdata/` folders for expected values
- Use `embed.FS` for test data files

### Practices
- `t.Helper()` in helper functions
- `t.Cleanup()` for resource cleanup
- `t.Context()` for test-scoped context (Go 1.24+)
- `t.Chdir()` for temp directory changes (Go 1.24+)
- `t.Parallel()` for independent tests
- `-race` flag always
- Don't test stdlib; test YOUR code
- Bug fix → add regression test first
- Concurrent code needs concurrent tests

### Testing Concurrent Code (Go 1.25+)
Use `testing/synctest`: wrap test in `synctest.Test()`, time is virtualized and advances when goroutines block, use `synctest.Wait()` to synchronize.

## Concurrency

### Design
- Don't communicate by sharing memory, share memory by communicating
- Channels orchestrate; mutexes serialize
- Use `errgroup.WithContext` to launch goroutines that return errors; `g.Wait()` returns first error
- Go 1.25+: `wg.Go(func() { ... })` combines `Add(1)` + `go`
- Make goroutine lifetime explicit; document when/why they exit
- Avoid goroutine leaks (blocked on unreachable channels)
- Use `context.Context` for cancellation
- Subscribe to `context.Done()` for graceful shutdown
- Prefer synchronous functions; let callers add concurrency if needed
- `sync.Mutex`/`RWMutex` for protection; zero value is ready to use
- `RWMutex` when reads >> writes
- Pointer receivers with mutexes (prevent struct copy)
- Keep critical sections small; avoid locks across I/O
- `sync.Once` for one-time initialization
- `atomic` for primitive counters
- Don't embed mutex (exposes Lock/Unlock); use named field
- Channels:
    - Sender closes, receiver checks
    - Don't close from receiver side
    - Never close with multiple concurrent senders
    - Document buffering rationale
    - Prefer `select` with `context.Done()` for cancellation

### Axioms

| Operation | nil channel | closed channel |
|-----------|-------------|----------------|
| Send      | blocks forever | **panics** |
| Receive   | blocks forever | returns zero value |
| Close     | **panics** | **panics** |

- Nil channels are useful in `select` to disable a case
- Use `for range ch` to receive until closed
- Check closure with `v, ok := <-ch`

## Iterators (Go 1.23+)

```go
// Range over function
for line := range strings.Lines(s) {
    process(line)
}

// Range over int (Go 1.22+)
for i := range 10 {
    fmt.Println(i)  // 0..9
}

// Custom iterator
func (s *Set[T]) All() iter.Seq[T] {
    return func(yield func(T) bool) {
        for v := range s.items {
            if !yield(v) {
                return
            }
        }
    }
}

// Collect iterator to slice
keys := slices.Collect(maps.Keys(m))
```

## Interface Design

- Accept interfaces, return concrete types
- Define interfaces at the consumer, not the provider; keep them small (1-2 methods)
- Compile-time interface check: `var _ http.Handler = (*MyHandler)(nil)`
- For single-method dependencies, use function types instead of interfaces
- Don't embed types in exported structs—exposes methods and breaks API compatibility

## Nil Safety

- Check pointers before dereference
- Proto: use generated Get methods (nil-safe)
- Nil slices are safe for `range` and `len`; prefer returning `nil` over empty slice
- Nil maps are safe for reads but panic on writes

## Slice & Map Patterns

- Pre-allocate when size known: `make([]User, 0, len(ids))`
- Nil vs empty: `var t []string` (nil, JSON null) vs `t := []string{}` (non-nil, JSON `[]`)
- Copy at boundaries with `slices.Clone(items)` to prevent external mutations
- Collect iterators: `slices.Collect(maps.Keys(m))`, `slices.Sorted(maps.Keys(m))` (Go 1.23+)
- Clear: `clear(m)` deletes all map entries, `clear(s)` zeros slice elements (Go 1.21+)
- Prefer `strings.Cut(s, "/")` over `strings.Split` for prefix/suffix extraction
- Append handles nil: `var items []Item; items = append(items, newItem)`

## Common Patterns

### Options Pattern
Define `type Option func(*Config)`. Create `WithX` functions returning `Option` that set fields. Constructor takes `...Option`, applies each to default config.

### Default Values (Go 1.22+)
Use `cmp.Or(a, b, c)` to return first non-zero value—e.g., `cmp.Or(cfg.Port, envPort, 8080)`.

### Context Usage
- First parameter: `func Foo(ctx context.Context, ...)`
- Don't store in structs
- Use for cancellation, deadlines, request-scoped values only

### HTTP Best Practices
- Use `http.Server{}` with explicit `ReadTimeout`/`WriteTimeout`; avoid `http.ListenAndServe`
- Always `defer resp.Body.Close()` after checking error
- Accept `*http.Client` as dependency for testability

### Directory-Scoped File Access (Go 1.24+)
Use `os.OpenRoot("/data")` to get a handle that restricts all file operations to that directory—prevents path traversal.

### Cleanup Functions (Go 1.24+)
Use `runtime.AddCleanup` instead of `SetFinalizer`—allows multiple cleanups per object, no cyclic reference issues.

## Structured Logging (log/slog)

- Use `slog.Info("msg", "key", value, "key2", value2)` with key-value pairs
- Add persistent attributes: `logger := slog.With("service", "api")`
- JSON output: `slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug}))`

## Common Gotchas

- `time.Ticker`: always call `Stop()` to prevent leaks
- Slices hold refs to backing arrays (can retain large memory)
- `nil` interface vs `nil` concrete: `var err error = (*MyError)(nil)` → `err != nil` is true
- Loop variables: each iteration has own copy (Go 1.22+); older versions share
- `init()` is an anti-pattern; prefer explicit initialization

## Linting (golangci-lint)

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

## Pre-Commit

Check for Makefile targets first (`make help`, or read Makefile). Common targets:
- `make lint` or `make check`
- `make test`
- `make build`

Fallback if no Makefile:
1. `go build ./...`
2. `go test -v -race ./...`
3. `golangci-lint run`
4. `gofmt -w .` or `goimports -w .`
5. `go mod tidy`
