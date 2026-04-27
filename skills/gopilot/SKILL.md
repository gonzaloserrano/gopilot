---
name: gopilot
description: "Go programming language skill for writing idiomatic Go code, code review, error handling, testing, concurrency, security, and program design. Use when writing, reviewing, debugging, or asking about Go code — even if the user doesn't explicitly mention 'Go best practices'. Also use when: reviewing Go PRs, debugging Go tests, fixing Go errors, designing Go APIs, implementing security-sensitive code, handling user input, authentication, sessions, cryptography, building resource-oriented gRPC APIs with Google AIP standards, configuring golangci-lint, setting up structured logging with slog, or any question about Go idioms and patterns. Covers table-driven tests, error wrapping, goroutine patterns, interface design, generics, iterators, stdlib patterns up to Go 1.26, OWASP security practices, and Google AIP (API Improvement Proposals) with einride/aip-go for pagination, filtering, ordering, field masks, and resource names."
license: MIT
---

# Go Engineering

## API Inspection

Before guessing function signatures or fabricating package APIs, inspect the source:

- `go doc fmt.Errorf` — package or symbol docs (stdlib + module deps)
- `go doc -src strings.Cut` — show source
- `go doc ./internal/foo` — local package
- `gopls definition <file>:<line>:<col>` — jump to definition
- `gopls references <file>:<line>:<col>` — find call sites
- `gopls symbols <file>` — list package symbols

Use these over inferring APIs. Hallucinated signatures fail at compile time; `go doc` is faster than the build-fail loop.

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

- `Must` prefix for panicking functions
- Enums: use `iota + 1` to start at one, distinguishing intentional values from zero default

## Error Handling

- Errors are values. Design APIs around that.
- Wrap with context: `fmt.Errorf("get config: %w", err)` -- use low-cardinality strings only (no IDs, names, or variable data in the format string; attach those as structured slog attributes so APM tools can group errors)
  ```go
  // Bad: high-cardinality error string -- APM sees each user as a unique error
  return fmt.Errorf("fetch user %s: %w", userID, err)

  // Good: stable error string + structured context
  slog.ErrorContext(ctx, "fetch user", "user_id", userID, "error", err)
  return fmt.Errorf("fetch user: %w", err)
  ```
- Generic error matching: `errors.AsType[T]` (Go 1.26+) replaces the `var t *MyErr; errors.As(err, &t)` dance
- Join multiple errors: `errors.Join(err1, err2, err3)` (Go 1.20+)
- Avoid verb prefixes that accumulate through the stack: "failed to", "error", "could not", "unable to". Use bare context instead (`"connect: %w"` not `"failed to connect: %w"`, `"fetch config: %w"` not `"error fetching config: %w"`)
- Always check errors immediately before using returned values — in Go 1.21–1.24, the compiler could reorder statements and execute method calls on nil receivers before the error check ran, causing panics (fixed in Go 1.25)

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

- Constraints: `comparable` for map keys, `cmp.Ordered` for sortable types
- Custom constraints with type sets: `type Number interface { ~int | ~int64 | ~float64 }`
- Generic type alias (Go 1.24+): `type Set[T comparable] = map[T]struct{}`
- Self-referential constraints (Go 1.26+): `type Adder[A Adder[A]] interface { Add(A) A }`
- Prefer concrete types when generics add no value

## Built-in Functions

- `min(a, b, c)` and `max(a, b, c)` - compute smallest/largest values (Go 1.21+)
- `clear(m)` - delete all map entries; `clear(s)` - zero all slice elements (Go 1.21+)
- `new(expr)` - allocate and initialize with value (Go 1.26+): `ptr := new(computeValue())`

## Testing

See [Go testing reference](reference/go-testing.md) — covers table-driven tests, benchmarks (`b.Loop()`, Go 1.24+), testify assertion conventions (prefer `require.Zero`/`Empty`/`Nil`, `ErrorIs`, `JSONEq`), test doubles via nil-embedded interfaces, practices (`TestFooBar` naming, `t.Helper`/`Cleanup`/`Context`/`Chdir`/`Parallel`, `-race`, `goleak` for leak detection), and `testing/synctest` (Go 1.25+) for deterministic concurrent tests.

## Concurrency

Share memory by communicating -- channels orchestrate; mutexes serialize.

### Choosing a Synchronization Primitive

| Need | Use | Why |
|------|-----|-----|
| Single counter/flag | `atomic` | Lock-free, simplest |
| Protect shared struct | `sync.Mutex` / `sync.RWMutex` | Direct, no goroutine overhead |
| Transfer ownership of data | Unbuffered channel | Synchronizes sender and receiver |
| Fan-out/fan-in, pipelines | Buffered channel + `select` | Composable, supports cancellation |
| N goroutines, first error aborts | `errgroup.WithContext` | Propagates cancellation |
| N goroutines, collect all errors | `errgroup` + `errors.Join` | No short-circuit |
| One-time init | `sync.Once` / `sync.OnceValue` | Race-free lazy init |
| Deduplicate concurrent calls | `singleflight.Group` | Coalesces in-flight requests |

- `sync.WaitGroup.Go()` (Go 1.25+): combines Add(1) + goroutine launch
  ```go
  var wg sync.WaitGroup
  wg.Go(func() { work() })  // Combines Add(1) + go
  wg.Wait()
  ```
- Make goroutine lifetime explicit; document when/why they exit
- Detect leaks with `GOEXPERIMENT=goroutineleakprofile` (Go 1.26+)
- Prefer synchronous functions; let callers add concurrency if needed
- `sync.Once` helpers: `sync.OnceFunc()`, `sync.OnceValue()`, `sync.OnceValues()` (Go 1.21+)
- Pointer receivers with mutexes (struct copy breaks lock semantics)
- Don't embed mutex (exposes Lock/Unlock to callers); use a named field instead
- Prevent copying of structs with mutexes or goroutine state using `noCopy`:
  ```go
  type Server struct {
      noCopy noCopy // go vet reports "copies lock value" if struct is copied
      mu     sync.Mutex
  }
  type noCopy struct{}
  func (*noCopy) Lock()   {}
  func (*noCopy) Unlock() {}
  ```
- Channels: sender closes, receiver checks; never close from receiver side or with multiple concurrent senders

### Channel Axioms

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
```go
// String iterators
for line := range strings.Lines(s) { }
for part := range strings.SplitSeq(s, sep) { }
for field := range strings.FieldsSeq(s) { }

// Slice iterators
for i, v := range slices.All(items) { }
for v := range slices.Values(items) { }
for v := range slices.Backward(items) { }
for chunk := range slices.Chunk(items, 3) { }

// Map iterators
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
- Don't embed types in exported structs (exposes methods and breaks API compatibility)

## Slice & Map Patterns

- Pre-allocate when size known: `make([]User, 0, len(ids))`
- Nil vs empty: `var t []string` (nil, JSON null) vs `t := []string{}` (non-nil, JSON `[]`)
- Copy at boundaries with `slices.Clone(items)` to prevent external mutations
- Prefer `strings.Cut(s, "/")` over `strings.Split` for prefix/suffix extraction

## Common Patterns

### Options Pattern
Define `type Option func(*Config)`. Create `WithX` functions returning `Option` that set fields. Constructor takes `...Option`, applies each to default config.

### Default Values (Go 1.22+)
Use `cmp.Or(a, b, c)` to return first non-zero value—e.g., `cmp.Or(cfg.Port, envPort, 8080)`.

### Context Usage
- `context.WithoutCancel(ctx)` (Go 1.21+): derive a context that keeps values but ignores parent cancellation. Use for background work that must outlive the request (async cleanup, audit logging)

### HTTP Best Practices
- Use `http.Server{}` with explicit `ReadTimeout`/`WriteTimeout`; avoid `http.ListenAndServe`
- Method-based routing (Go 1.22+): `mux.HandleFunc("GET /items/{id}", h)`, extract via `r.PathValue("id")`. Greedy wildcard: `{path...}`

### AIP: Resource-Oriented gRPC APIs

For building resource-oriented gRPC APIs following [Google AIP](https://google.aip.dev/) standards with [einride/aip-go](https://github.com/einride/aip-go), see [AIP reference](reference/go-aip.md) -- covers resource names, standard methods (CRUD), pagination, filtering, ordering, field masks, and field behavior annotations.

### Security Helpers
- CSRF: `http.CrossOriginProtection(handler)` (Go 1.25+) -- rejects cross-origin state-changing requests
- Path traversal prevention: `os.OpenRoot("/var/data")` (Go 1.24+) -- chroot-like scoped file access
- GC cleanup: `runtime.AddCleanup(obj, fn)` (Go 1.24+) -- replaces `SetFinalizer`, supports multiple cleanups per object

## Structured Logging (log/slog)

- JSON handler for production: `slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug}))`
- `slog.ErrorContext(ctx, ...)` over `slog.Error(...)` so handler-bound trace/request IDs propagate

## Common Gotchas

### Nil Safety

| Operation | nil map | nil slice | nil channel |
|-----------|---------|-----------|-------------|
| Read/index | zero value | **panics** | blocks forever |
| Write | **panics** | **panics** (index) | blocks forever |
| `len` / `cap` | 0 | 0 | 0 |
| `range` | 0 iterations | 0 iterations | blocks forever |
| `append` | N/A | works (returns new) | N/A |
| `delete` | no-op | N/A | N/A |
| `close` | N/A | N/A | **panics** |

Don't add nil guards for values that a dependency (database, library, protocol) guarantees non-nil. Trust the contract; redundant checks add noise without safety. Only guard at true system boundaries (user input, external APIs, untrusted data).

### Slice Aliasing

`append` on a sub-slice can silently mutate the original if capacity remains:
```go
a := []int{1, 2, 3, 4}
b := a[:2]           // b shares a's backing array
b = append(b, 99)    // overwrites a[2]! a is now [1, 2, 99, 4]
```
Fix with full-slice expression to cap the capacity:
```go
b := a[:2:2]         // len=2, cap=2 -- append allocates a new array
b = append(b, 99)    // a is unchanged
```

### Copy Semantics

| Type | Assignment copies... |
|------|---------------------|
| bool, int, float, complex, string | value (safe) |
| array | all elements (deep) |
| struct | all fields (shallow -- pointer fields share referent) |
| slice | header only (shares backing array) |
| map | header only (shares buckets) |
| pointer, func, channel | pointer (shares referent) |
| interface | header only (shares underlying value if pointer) |

Use `slices.Clone` / `maps.Clone` for shallow copies at API boundaries.

- `nil` interface vs `nil` concrete: `var err error = (*MyError)(nil)` → `err != nil` is true (typed nil)
- Loop variables: each iteration has own copy (Go 1.22+); older versions share
- Timer/Ticker channels: capacity 0 (Go 1.23+); previously capacity 1

## Linting

Use `golangci-lint` with recommended linters: errcheck, govet, staticcheck, gocritic, gofumpt, wrapcheck, errorlint. See [linting reference](reference/linting.md) for the full `.golangci.yml` config template and commands.

## Pre-Commit

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

### Profile-Guided Optimization (PGO)
```bash
# Collect profile
go test -cpuprofile=default.pgo

# PGO automatically enabled if default.pgo exists in main package
go build  # Uses default.pgo

# Typical 2-7% performance improvement
```

## Security

Based on OWASP Go Secure Coding Practices. See [security checklist and guides](reference/security-checklist.md) for the full checklist, detailed per-topic guides (input validation, auth, crypto, sessions, TLS, CSRF, file security, XSS, access control, logging), and security scanning tools (gosec, govulncheck, trivy).
