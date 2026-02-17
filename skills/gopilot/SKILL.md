---
name: gopilot
description: Go programming language skill for writing idiomatic Go code, code review, error handling, testing, concurrency, security, and program design. Use when writing Go code, reviewing Go PRs, debugging Go tests, fixing Go errors, designing Go APIs, implementing security-sensitive code, handling user input, authentication, sessions, cryptography, or asking about Go best practices. Covers table-driven tests, error wrapping, goroutine patterns, interface design, generics, iterators, stdlib patterns up to Go 1.26, and OWASP security practices.
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

- Avoid stuttering: `http.Client` not `http.HTTPClient`
- Getters: `Foo()` not `GetFoo()`
- Receiver: short (1-2 chars), consistent across type methods
- `Must` prefix for panicking functions

## Error Handling

- Errors are values. Design APIs around that.
- Wrap with context: `fmt.Errorf("get config %s: %w", name, err)`
- Sentinel errors: `var ErrNotFound = errors.New("not found")`
- Check with `errors.Is(err, ErrNotFound)` or `errors.As(err, &target)` (or generic `errors.AsType[T](err)` Go 1.26+)
- Standard sentinel for unsupported operations: `errors.ErrUnsupported` (Go 1.21+)
- Static errors: prefer `errors.New` over `fmt.Errorf` without formatting
- Join multiple errors: `err := errors.Join(err1, err2, err3)` (Go 1.20+)
- Error strings: lowercase, no punctuation
- Avoid "failed to" prefixes - they accumulate through the stack (`"connect: %w"` not `"failed to connect: %w"`)
- **CRITICAL**: Always check errors immediately before using returned values (Go 1.25 fixed compiler bug that could delay nil checks)

### Error Strategy (Opaque Errors First)

Prefer **opaque error handling**: treat errors as opaque values, don't inspect internals. This minimizes coupling.

Three strategies in order of preference:

1. **Opaque errors** (preferred): return and wrap errors without exposing type or value. Callers only check `err != nil`.
2. **Sentinel errors** (`var ErrNotFound = errors.New(...)`): use sparingly for expected conditions callers must distinguish. They become public API.
3. **Error types** (`type NotFoundError struct{...}`): use when callers need structured context. Also public API — avoid when opaque or sentinel suffices.

### Assert Behavior, Not Type

When you must inspect errors beyond `errors.Is`/`errors.As`, assert on **behavior interfaces** instead of concrete types:

```go
type temporary interface {
    Temporary() bool
}

func IsTemporary(err error) bool {
    te, ok := err.(temporary)
    return ok && te.Temporary()
}
```

### Handle Errors Once

An error should be handled exactly once. Handling = logging, returning, or degrading gracefully. Never log and return — duplicates without useful context.

```go
// Bad: logs AND returns
if err != nil {
    log.Printf("connect failed: %v", err)
    return fmt.Errorf("connect: %w", err)
}

// Good: wrap and return; let the top-level caller log
if err != nil {
    return fmt.Errorf("connect to %s: %w", addr, err)
}
```

Wrap with context at each layer; log/handle only at the application boundary.

### Context with Cause (Go 1.21+)

Propagate cancellation reasons through context:

```go
ctx, cancel := context.WithCancelCause(parent)
cancel(fmt.Errorf("shutdown: %w", reason))

// Later retrieve the cause
if cause := context.Cause(ctx); cause != nil {
    log.Printf("context cancelled: %v", cause)
}
```

## Generics

- Type parameters: `func Min[T cmp.Ordered](a, b T) T`
- Use `comparable` for map keys, `cmp.Ordered` for sortable types (Go 1.21+); `cmp.Compare()`, `cmp.Less()` for comparisons
- Custom constraints: `type Number interface { ~int | ~int64 | ~float64 }`
- Generic type alias (Go 1.24+): `type Set[T comparable] = map[T]struct{}`
- Self-referential constraints (Go 1.26+): `type Adder[A Adder[A]] interface { Add(A) A }`
- `reflect.TypeFor[T]()` instead of `reflect.TypeOf((*T)(nil)).Elem()` (Go 1.22+)
- Prefer concrete types when generics add no value
- Use `any` sparingly; prefer specific constraints

## Built-in Functions

- `min(a, b, c)` and `max(a, b, c)` - compute smallest/largest values (Go 1.21+)
- `clear(m)` - delete all map entries; `clear(s)` - zero all slice elements (Go 1.21+)
- `new(expr)` - allocate and initialize with value (Go 1.26+): `ptr := new(computeValue())`

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
```go
func BenchmarkFoo(b *testing.B) {
    for b.Loop() {  // Cleaner than for i := 0; i < b.N; i++
        Foo()
    }
}
```
Benefits: single execution per `-count`, prevents compiler optimizations away.

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
- `t.ArtifactDir()` for test output files (Go 1.26+)
- `t.Attr(key, value)` for structured test metadata (Go 1.25+)
- `t.Parallel()` for independent tests
- `-race` flag always
- Don't test stdlib; test YOUR code
- Bug fix → add regression test first
- Concurrent code needs concurrent tests

### Testing Concurrent Code with synctest (Go 1.25+)

`testing/synctest` creates an isolated "bubble" with virtualized time. The fake clock advances automatically when all goroutines in the bubble are blocked.

```go
import "testing/synctest"

func TestPeriodicWorker(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        var count atomic.Int32
        go func() {
            for {
                time.Sleep(time.Second)
                count.Add(1)
            }
        }()

        // Fake clock advances 5s instantly (no real waiting)
        time.Sleep(5 * time.Second)
        synctest.Wait() // wait for all goroutines to settle
        require.Equal(t, int32(5), count.Load())
    })
}
```

Key rules:
- `synctest.Wait()` blocks until all bubble goroutines are idle
- `time.Sleep`, `time.After`, `time.NewTimer`, `time.NewTicker` all use the fake clock inside the bubble
- Goroutines spawned inside the bubble belong to it; goroutines outside are unaffected
- Blocking on I/O or syscalls does NOT advance the clock — only channel ops, sleeps, and sync primitives do
- Prefer `synctest.Test` over manual `timeNow` mocking for new code

## Concurrency

### Design
- Don't communicate by sharing memory, share memory by communicating
- Channels orchestrate; mutexes serialize
- Use `errgroup.WithContext` to launch goroutines that return errors; `g.Wait()` returns first error
- `sync.WaitGroup.Go()` (Go 1.25+): cleaner goroutine launching
  ```go
  var wg sync.WaitGroup
  wg.Go(func() { work() })  // Combines Add(1) + go
  wg.Wait()
  ```
- Make goroutine lifetime explicit; document when/why they exit
- Avoid goroutine leaks (blocked on unreachable channels); use goroutine leak profile to detect (`GOEXPERIMENT=goroutineleakprofile`, Go 1.26+)
- Use `context.Context` for cancellation
- Subscribe to `context.Done()` for graceful shutdown
- Prefer synchronous functions; let callers add concurrency if needed
- `sync.Mutex`/`RWMutex` for protection; zero value is ready to use
- `RWMutex` when reads >> writes
- Pointer receivers with mutexes (prevent struct copy)
- Keep critical sections small; avoid locks across I/O
- `sync.Once` for one-time initialization; helpers: `sync.OnceFunc()`, `sync.OnceValue()`, `sync.OnceValues()` (Go 1.21+)
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

## Iterators (Go 1.22+)

### Range Over Integers (Go 1.22+)
```go
for i := range 10 {
    fmt.Println(i)  // 0..9
}
```

### Range Over Functions (Go 1.23+)

Iterator types: `iter.Seq[V]` yields single values, `iter.Seq2[K, V]` yields key-value pairs (Go 1.23+).

```go
// String iterators (Go 1.24+)
for line := range strings.Lines(s) { }
for part := range strings.SplitSeq(s, sep) { }
for field := range strings.FieldsSeq(s) { }

// Slice iterators (Go 1.23+, package since Go 1.21+)
for i, v := range slices.All(items) { }
for v := range slices.Values(items) { }
for v := range slices.Backward(items) { }
for chunk := range slices.Chunk(items, 3) { }

// Map iterators (Go 1.23+, package since Go 1.21+)
for k, v := range maps.All(m) { }
for k := range maps.Keys(m) { }
for v := range maps.Values(m) { }

// Collect iterator to slice
keys := slices.Collect(maps.Keys(m))
sorted := slices.Sorted(maps.Keys(m))

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
```

## Interface Design

- Accept interfaces, return concrete types
- Define interfaces at the consumer, not the provider; keep them small (1-2 methods)
- Compile-time interface check: `var _ http.Handler = (*MyHandler)(nil)`
- For single-method dependencies, use function types instead of interfaces
- Don't embed types in exported structs—exposes methods and breaks API compatibility

## Slice & Map Patterns

- Pre-allocate when size known: `make([]User, 0, len(ids))`
- Nil vs empty: `var t []string` (nil, JSON null) vs `t := []string{}` (non-nil, JSON `[]`)
- Copy at boundaries with `slices.Clone(items)` (Go 1.21+) to prevent external mutations
- Concatenate slices: `slices.Concat(a, b, c)` (Go 1.22+)
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
- `context.WithoutCancel(ctx)` — derive a context that is never canceled, for background work that outlives a request (Go 1.21+)
- `context.AfterFunc(ctx, fn)` — register cleanup to run when context is done; replaces manual goroutine+select (Go 1.21+)

### Random Numbers (Go 1.22+)

Use `math/rand/v2` for new code (not `math/rand`):
```go
n := rand.IntN(100)         // [0, 100)
x := rand.N[time.Duration](time.Second)  // generic; works with any integer type
f := rand.Float64()
```
Default source is ChaCha8 (cryptographically secure). For security-sensitive use, still prefer `crypto/rand`.

### JSON Struct Tags (Go 1.24+)

`omitzero` omits a field when it is the zero value. Clearer than `omitempty` especially for `time.Time`:
```go
type Event struct {
    Name    string    `json:"name"`
    StartAt time.Time `json:"start_at,omitzero"` // omitted when zero, not "0001-01-01T..."
    Tags    []string  `json:"tags,omitempty"`     // omitted when nil or empty
}
```
`omitzero` uses `IsZero() bool` if available; otherwise compares to the language zero value.

### Generic Nullable (Go 1.22+)

`database/sql.Null[T]` replaces `sql.NullString`, `sql.NullInt64`, etc.:
```go
var name sql.Null[string]
var age  sql.Null[int]
```

### Value Interning (Go 1.23+)

`unique.Make[T](v)` returns a `Handle[T]` that deduplicates equal values in memory:
```go
h1 := unique.Make("frequently-repeated")
h2 := unique.Make("frequently-repeated")
// h1 == h2, single allocation backing both
```

### Weak Pointers (Go 1.24+)

`weak.Pointer[T]` holds a reference that doesn't prevent garbage collection:
```go
p := weak.Make(&obj)
if v := p.Value(); v != nil {
    // obj still alive, use *v
}
```
Use for caches and canonicalization maps where entries should be evicted when no longer referenced.

### HTTP Best Practices
- Use `http.Server{}` with explicit `ReadTimeout`/`WriteTimeout`; avoid `http.ListenAndServe`
- Always `defer resp.Body.Close()` after checking error
- Accept `*http.Client` as dependency for testability

### HTTP Routing (Go 1.22+)
```go
// Method-based routing with path patterns
mux.HandleFunc("POST /items/create", createHandler)
mux.HandleFunc("GET /items/{id}", getHandler)
mux.HandleFunc("GET /files/{path...}", serveFiles)  // Greedy wildcard

// Extract path values
func getHandler(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
}
```

### Reverse Proxy (Go 1.26+)
Use `Rewrite` instead of the deprecated `Director`:
```go
proxy := &httputil.ReverseProxy{
    Rewrite: func(r *httputil.ProxyRequest) {
        r.SetURL(target)
        r.SetXForwarded()
    },
}
```

### CSRF Protection (Go 1.25+)
```go
import "net/http"

handler := http.CrossOriginProtection(myHandler)
// Rejects non-safe cross-origin requests using Fetch metadata
```

### Directory-Scoped File Access (Go 1.24+)
```go
root, err := os.OpenRoot("/var/data")
if err != nil {
    return err
}
defer root.Close()
f, err := root.Open("file.txt")  // Can't escape /var/data
```
Prevents path traversal attacks; works like a chroot. Full sandboxed filesystem API (Go 1.25+):
```go
data, err := root.ReadFile("config.json")
err = root.WriteFile("output.txt", data, 0o644)
err = root.MkdirAll("a/b/c", 0o755)
err = root.Rename("old.txt", "new.txt")
err = root.RemoveAll("temp")
```

### Cleanup Functions (Go 1.24+)
```go
runtime.AddCleanup(obj, func() { cleanup() })
```
Advantages over `SetFinalizer`: multiple cleanups per object, works with interior pointers, no cycle leaks, faster.

## Structured Logging (log/slog, Go 1.21+)

- Use `slog.Info("msg", "key", value, "key2", value2)` with key-value pairs
- Add persistent attributes: `logger := slog.With("service", "api")`
- JSON output: `slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug}))`
- Discard handler for tests: `slog.New(slog.DiscardHandler)` (Go 1.24+)
- Multi-handler composition: `slog.NewMultiHandler(jsonHandler, textHandler)` (Go 1.26+)

## Common Gotchas

- **Check errors immediately** (Go 1.25 fixed compiler bug): always check `err != nil` before using any returned values
  ```go
  // WRONG: could execute f.Name() before err check in Go 1.21-1.24
  f, err := os.Open("file")
  name := f.Name()
  if err != nil { return }

  // CORRECT: check immediately
  f, err := os.Open("file")
  if err != nil { return }
  name := f.Name()
  ```
- `panic(nil)` now causes `*runtime.PanicNilError` (Go 1.21+); `recover()` never returns nil
- `time.Ticker`: always call `Stop()` to prevent leaks
- Slices hold refs to backing arrays (can retain large memory)
- `nil` interface vs `nil` concrete: `var err error = (*MyError)(nil)` → `err != nil` is true
- Loop variables: each iteration has own copy (Go 1.22+); older versions share
- Timer/Ticker channels: capacity 0 (Go 1.23+); previously capacity 1
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

### Vet Analyzers (Go 1.25+)
- `waitgroup`: catches `wg.Add(1)` placed inside the goroutine instead of before `go` — a common race condition
- `hostport`: catches `host + ":" + port` string concatenation, suggests `net.JoinHostPort(host, port)` which handles IPv6 correctly

## Module & Tool Management

### Tool Dependencies (Go 1.24+)

Track executable tool dependencies in `go.mod` instead of the old `tools.go` blank-import hack:
```bash
go get -tool golang.org/x/tools/cmd/stringer@latest   # adds tool directive
go get -tool github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go tool stringer -type=Color                           # run tracked tool
```

### Pre-Commit

Check for Makefile targets first (`make help`, or read Makefile). Common targets:
- `make lint` or `make check`
- `make test`
- `make build`

Fallback if no Makefile:
1. `go build ./...`
2. `go test -v -race ./...`
3. `golangci-lint run`
4. `go fix ./...` (Go 1.26+: modernizes code to latest idioms)
5. `gofmt -w .` or `goimports -w .`
6. `go mod tidy`

## Performance

### Profile-Guided Optimization (PGO, Go 1.21+)
```bash
# Collect profile
go test -cpuprofile=default.pgo

# PGO automatically enabled if default.pgo exists in main package
go build  # Uses default.pgo

# Typical 2-7% performance improvement
```

## Security

Based on OWASP Go Secure Coding Practices. Read the linked reference for each topic.

### Quick Checklist

**Input/Output:**
- [ ] All user input validated server-side
- [ ] SQL queries use prepared statements only
- [ ] XSS protection via `html/template`
- [ ] CSRF tokens on state-changing requests
- [ ] File paths validated against traversal (`os.OpenRoot` Go 1.24+)

**Auth/Sessions:**
- [ ] Passwords hashed with bcrypt/Argon2/PBKDF2 (`crypto/pbkdf2` in stdlib Go 1.24+)
- [ ] `crypto/rand` for all tokens/session IDs (`crypto/rand.Text()` Go 1.24+)
- [ ] Secure cookie flags (HttpOnly, Secure, SameSite)
- [ ] Session expiration enforced

**Encryption:**
- [ ] Use `crypto/cipher.NewGCMWithRandomNonce()` for symmetric encryption — auto-generates nonce, prevents reuse (Go 1.24+)
- [ ] HTTPS/TLS everywhere, TLS 1.2+ only (post-quantum ML-KEM default Go 1.24+)
- [ ] HSTS header set
- [ ] `InsecureSkipVerify = false`

**Data Protection:**
- [ ] Secrets in environment variables, never in logs/errors
- [ ] Generic error messages to users

### Detailed Guides

- [Input Validation](reference/input-validation.md) — whitelisting, boundary checks, escaping
- [Database Security](reference/database-security.md) — prepared statements, parameterized queries
- [Authentication](reference/authentication.md) — bcrypt, password storage
- [Cryptography](reference/cryptography.md) — `crypto/rand`, never `math/rand` for security
- [Session Management](reference/session-management.md) — secure cookies, session lifecycle
- [TLS/HTTPS](reference/tls-https.md) — TLS config, HSTS, post-quantum key exchanges
- [CSRF Protection](reference/csrf.md) — token generation, `http.CrossOriginProtection` (Go 1.25+)
- [Secure Error Handling](reference/error-handling.md) — generic user messages, detailed server logs
- [File Security](reference/file-security.md) — path traversal prevention, `os.OpenRoot`
- [Security Logging](reference/logging.md) — what to log, what never to log
- [Access Control](reference/access-control.md)
- [XSS Prevention](reference/xss.md)

### Security Tools

| Tool | Purpose | Command |
|------|---------|---------|
| gosec | Security scanner | `gosec ./...` |
| govulncheck | Vulnerability scanner | `govulncheck ./...` |
| trivy | Container/dep scanner | `trivy fs .` |
