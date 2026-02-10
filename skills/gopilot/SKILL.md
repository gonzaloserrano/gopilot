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

## Language Features (Go 1.26+)

### Enhanced `new` Builtin
`new` accepts an optional initial value expression, eliminating pointer-to-literal workarounds:

```go
// Before Go 1.26: helper function or addr-of-literal
func ptr[T any](v T) *T { return &v }

p := &Person{Age: ptr(30)}

// Go 1.26+: new(expr) returns *T initialized to expr
p := &Person{Age: new(30)}
```

### Self-Referential Generic Types
Generic types can refer to themselves in type parameter constraints:

```go
type Adder[A Adder[A]] interface {
    Add(A) A
}

func Sum[A Adder[A]](x, y A) A {
    return x.Add(y)
}
```

## Code Style

### Formatting
- Run `gofmt` or `goimports` before commit
- Use `golangci-lint` for linting
- Use `go fix` to modernize code to current idioms (Go 1.26+): applies dozens of fixers for stdlib API migrations and modern patterns

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
- Type-safe extraction (Go 1.26+): `errors.AsType[*NotFoundError](err)` returns `(*NotFoundError, bool)` — prefer over `errors.As` for cleaner generic code
- Static errors: prefer `errors.New` over `fmt.Errorf` without formatting
- Aggregate multiple: collect into slice, return `errors.Join(errs...)`
- Error strings: lowercase, no punctuation
- Avoid "failed to" prefixes - they accumulate through the stack (`"connect: %w"` not `"failed to connect: %w"`)

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
Use `for b.Loop()` instead of `for range b.N`. In Go 1.26+, `b.Loop()` no longer prevents inlining of the benchmarked code.

### Assertions
- Use the testify library for conciseness. Use `require` for fatal assertions, `assert` for non-fatal
- `require.ErrorIs` for sentinel errors (not string matching)
- `require.JSONEq`/`require.YAMLEq` for semantic comparison
- Use `testdata/` folders for expected values
- Use `embed.FS` for test data files

### Test Artifacts (Go 1.26+)
Use `-test.artifacts` flag and `t.ArtifactDir()` to write test output files (logs, screenshots, profiles) to a structured directory:

```go
func TestReport(t *testing.T) {
    data := generateReport()
    os.WriteFile(filepath.Join(t.ArtifactDir(), "report.json"), data, 0o644)
}
```

Also available: `b.ArtifactDir()` and `f.ArtifactDir()` for benchmarks and fuzz tests.

### Practices
- `t.Helper()` in helper functions
- `t.Cleanup()` for resource cleanup
- `t.Context()` for test-scoped context (Go 1.24+)
- `t.Chdir()` for temp directory changes (Go 1.24+)
- `t.ArtifactDir()` for test output files (Go 1.26+)
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

// Reflect iterators (Go 1.26+)
for field := range reflect.TypeFor[MyStruct]().Fields() {
    fmt.Println(field.Name)
}
// Also: Type.Methods(), Type.Ins(), Type.Outs(), Value.Fields(), Value.Methods()
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
- Peek without advancing: `bytes.Buffer.Peek(n)` returns next n bytes (Go 1.26+)

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
- Use typed dial methods with context (Go 1.26+): `net.Dialer.DialTCP`, `DialUDP`, `DialIP`, `DialUnix` instead of `Dial`/`DialContext` with string network names

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
3. `go fix ./...` (Go 1.26+: applies modernizers for current idioms)
4. `golangci-lint run`
5. `gofmt -w .` or `goimports -w .`
6. `go mod tidy`

## Security

Based on OWASP Go Secure Coding Practices.

### Quick Checklist

**Input/Output:**
- [ ] All user input validated server-side
- [ ] SQL queries use prepared statements only
- [ ] XSS protection via `html/template`
- [ ] CSRF tokens on state-changing requests
- [ ] File paths validated against traversal

**Authentication/Sessions:**
- [ ] Passwords hashed with bcrypt/Argon2/PBKDF2
- [ ] `crypto/rand` for all tokens/session IDs
- [ ] Secure cookie flags (HttpOnly, Secure, SameSite)
- [ ] Session expiration enforced

**Communication:**
- [ ] HTTPS/TLS everywhere, TLS 1.2+ only
- [ ] HSTS header set
- [ ] `InsecureSkipVerify = false`

**Data Protection:**
- [ ] Secrets in environment variables
- [ ] No secrets in logs/errors
- [ ] Generic error messages to users

### Input Validation

Reject invalid input by default. Validate server-side only.

```go
// Type conversions with validation
i, err := strconv.Atoi(input)
valid := utf8.ValidString(input)
```

**Validate for:** whitelisting (allowed chars), boundary checking (length), character escaping, null bytes (`%00`), path traversal (`../`).

📖 [reference/input-validation.md](reference/input-validation.md)

### SQL Injection Prevention

**NEVER concatenate. ALWAYS use prepared statements.**

```go
// VULNERABLE
query := "SELECT * FROM users WHERE id = " + userID

// SAFE
query := "SELECT * FROM users WHERE id = $1"
row := db.QueryRowContext(ctx, query, userID)
```

Placeholders: MySQL `?`, PostgreSQL `$1,$2`, Oracle `:name`

📖 [reference/database-security.md](reference/database-security.md)

### Password Storage

Use `golang.org/x/crypto/bcrypt`. Never roll your own crypto.

```go
hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
err = bcrypt.CompareHashAndPassword(hash, []byte(password))
```

📖 [reference/authentication.md](reference/authentication.md)

### Cryptographic Randomness

**NEVER use `math/rand` for security. Use `crypto/rand`.**

```go
// VULNERABLE - predictable
import "math/rand"
token := rand.Intn(1984)

// SAFE
import "crypto/rand"
b := make([]byte, 32)
_, err := rand.Read(b)
```

Use `crypto/rand` for: session IDs, tokens, salts, nonces, password generation.

Go 1.26+: all `crypto` package functions that accepted a `rand io.Reader` parameter now **ignore** it and always use cryptographically secure randomness. This eliminates a class of bugs where `math/rand` was accidentally passed. Use `testing/cryptotest.SetGlobalRandom` for deterministic testing.

📖 [reference/cryptography.md](reference/cryptography.md)

### Session Management

```go
cookie := http.Cookie{
    Name:     "SessionID",
    Value:    sessionToken,
    Expires:  time.Now().Add(30 * time.Minute),
    HttpOnly: true,                        // Prevent XSS
    Secure:   true,                        // HTTPS only
    SameSite: http.SameSiteStrictMode,     // CSRF protection
    Path:     "/",
}
```

Generate new session on sign-in. Never expose session IDs in URLs.

📖 [reference/session-management.md](reference/session-management.md)

### TLS Configuration

```go
config := &tls.Config{
    MinVersion:         tls.VersionTLS12,
    MaxVersion:         tls.VersionTLS13,
    InsecureSkipVerify: false,  // NEVER true in production
}

// HSTS header
w.Header().Add("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
```

Go 1.26+: hybrid post-quantum key exchanges (`SecP256r1MLKEM768`, `SecP384r1MLKEM1024`) are enabled by default. Disable via `Config.CurvePreferences` or `GODEBUG=tlssecpmlkem=0` if needed for compatibility.

📖 [reference/tls-https.md](reference/tls-https.md)

### CSRF Protection

Use established libraries like `github.com/gorilla/csrf`. Tokens must be unique per session, generated by `crypto/rand`, validated on all state-changing requests.

📖 [reference/csrf.md](reference/csrf.md)

### Secure Error Handling

Never leak sensitive information. Generic messages to users, detailed logs server-side.

```go
if err := AuthenticateUser(creds); err != nil {
    http.Error(w, "Invalid credentials", http.StatusUnauthorized)
    slog.Warn("auth failed", "user", username, "error", err)
    return
}
```

📖 [reference/error-handling.md](reference/error-handling.md)

### Secure File Operations

Prevent path traversal. Use `os.OpenRoot` (Go 1.24+) or validate manually:

```go
func SafePath(baseDir, userPath string) (string, error) {
    fullPath := filepath.Join(baseDir, filepath.Clean(userPath))
    if !strings.HasPrefix(fullPath, baseDir) {
        return "", errors.New("path traversal detected")
    }
    return fullPath, nil
}
```

📖 [reference/file-security.md](reference/file-security.md)

### Security Logging

Never log: passwords, tokens, session IDs, PII. Always log: auth attempts, authz failures, input validation failures.

📖 [reference/logging.md](reference/logging.md)

### Security Tools

| Tool | Purpose | Command |
|------|---------|---------|
| gosec | Security scanner | `gosec ./...` |
| govulncheck | Vulnerability scanner | `govulncheck ./...` |
| trivy | Container/dep scanner | `trivy fs .` |

### More Security Topics

- [Access Control](reference/access-control.md)
- [XSS Prevention](reference/xss.md)
