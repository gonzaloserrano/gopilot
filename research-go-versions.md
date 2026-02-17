# Research: Adding More Go Versions to gopilot

Focus: features that affect **how you write idiomatic Go code** — language constructs, stdlib APIs, coding patterns, testing idioms, and tooling that shapes daily coding. Excludes runtime internals (GC, scheduler), performance tuning, platform ports, and crypto implementation details.

## Current State

The skill (`skills/gopilot/SKILL.md`) covers Go 1.20–1.26 with 48 version-annotated references.

### Current Coverage Per Version

| Version | Features Covered |
|---------|-----------------|
| Go 1.20 | `errors.Join` |
| Go 1.21 | `context.WithCancelCause`, `min`/`max`/`clear` builtins, `sync.OnceFunc`/`OnceValue`/`OnceValues` |
| Go 1.22 | Range over int, `cmp.Or`, HTTP routing with patterns, loop variable fix |
| Go 1.23 | Range over functions, Timer/Ticker channel capacity change |
| Go 1.24 | Generic type aliases, `b.Loop()`, `t.Context()`/`t.Chdir()`, `os.OpenRoot`, `runtime.AddCleanup`, `crypto/rand.Text()`, post-quantum ML-KEM |
| Go 1.25 | `testing/synctest`, `sync.WaitGroup.Go()`, `http.CrossOriginProtection`, compiler nil-check bug fix |
| Go 1.26 | `errors.AsType[T]()`, `new(expr)`, self-referential constraints, `t.ArtifactDir()`, `go fix` modernizers, goroutine leak profile |

---

## Missing Idiomatic Features by Version

### Go 1.21 — Missing

The skill references `slog`, `slices`, and `maps` in code examples but never tags them as Go 1.21+ introductions. A developer on Go 1.20 would try to use them and fail.

| Feature | What it changes | Priority |
|---------|----------------|----------|
| `log/slog` package (Go 1.21+) | The structured logging standard. Skill already has a section but needs the version tag. | High |
| `slices` package (Go 1.21+) | Generic slice operations (`slices.Contains`, `slices.Sort`, `slices.Index`, `slices.Clone`, etc.). Referenced in skill but not tagged. | High |
| `maps` package (Go 1.21+) | Generic map operations (`maps.Clone`, `maps.Copy`, `maps.Equal`, `maps.DeleteFunc`). Referenced but not tagged. | High |
| `cmp` package (Go 1.21+) | `cmp.Ordered` constraint, `cmp.Compare()`, `cmp.Less()`. The `cmp.Or` is tagged as 1.22 but the package itself is 1.21. | High |
| `errors.ErrUnsupported` | Standard sentinel for "not supported" — replaces ad-hoc sentinels. Idiomatic way to signal unsupported operations. | Medium |
| `context.WithoutCancel()` | Returns a context that is never canceled even when parent is. Common pattern for background work that should outlive a request. | Medium |
| `context.AfterFunc()` | Registers a function to call when a context is done. Replaces manual goroutine+select patterns for context cleanup. | Medium |
| `panic(nil)` → `*runtime.PanicNilError` | Breaking behavior change. `recover()` no longer returns nil. Gotcha worth documenting. | Low |

### Go 1.22 — Missing

| Feature | What it changes | Priority |
|---------|----------------|----------|
| `math/rand/v2` | First v2 stdlib package. Idiomatic new code should use `rand/v2` not `math/rand`. Introduces `rand.N[T]()` generic function, `rand.IntN()`, better default source (ChaCha8). | High |
| `slices.Concat()` | Concatenate multiple slices. Common operation, no equivalent before. | Medium |
| `database/sql.Null[T]` | Generic nullable type. Replaces `sql.NullString`, `sql.NullInt64`, etc. with a single generic type. | Medium |
| `reflect.TypeFor[T]()` | `reflect.TypeFor[MyType]()` instead of `reflect.TypeOf((*MyType)(nil)).Elem()`. Much more readable. | Low |

### Go 1.23 — Missing

The skill covers range-over-functions but is thin on the stdlib iterator ecosystem that makes it practical.

| Feature | What it changes | Priority |
|---------|----------------|----------|
| `iter.Seq[V]` / `iter.Seq2[K,V]` types | The core iterator type signatures. The skill shows custom iterators but never names these types explicitly. | High |
| `slices` iterator functions | `All`, `Values`, `Backward`, `Collect`, `AppendSeq`, `Sorted`, `SortedFunc`, `SortedStableFunc`, `Chunk`, `Repeat`. These are already in the skill but should note they are Go 1.23+ (not 1.21). | High |
| `maps` iterator functions | `All`, `Keys`, `Values`, `Insert`, `Collect`. Same — already shown in skill but need 1.23+ tag. | High |
| `strings`/`bytes` iterator functions | `Lines`, `SplitSeq`, `SplitAfterSeq`, `FieldsSeq`, `FieldsFuncSeq`. Already in skill, need 1.23+ tag (some were 1.24). | High |
| `unique` package | Value interning/canonicalization. `unique.Make[T](v)` returns `Handle[T]` — deduplicates equal values in memory. Useful pattern for reducing allocations with repeated strings/values. | Medium |
| `structs.HostLayout` | Embedding this in a struct guarantees host-platform memory layout. Required for passing structs to C/syscalls without cgo. Niche but idiomatic for systems code. | Low |

### Go 1.24 — Missing

| Feature | What it changes | Priority |
|---------|----------------|----------|
| `encoding/json` `omitzero` struct tag | `json:"field,omitzero"` omits if zero value (uses `IsZero()` method if available). Much clearer than `omitempty` for types like `time.Time`. | High |
| `tool` directives in `go.mod` | `go get -tool example.com/linter@latest` adds a tool directive. Replaces the `tools.go` blank-import hack. `go tool linter` runs it. Idiomatic dependency management for tools. | High |
| `weak.Pointer[T]` | Weak references. Enables idiomatic patterns for caches and canonicalization maps that don't prevent GC. | Medium |
| `crypto/cipher.NewGCMWithRandomNonce()` | Generates random nonce and prepends to ciphertext. Safer API — eliminates the nonce-reuse footgun. | Medium |
| `crypto/pbkdf2` in stdlib | Password-based key derivation now in stdlib (was `golang.org/x/crypto`). Relevant for the auth/security guidance. | Medium |
| `slog.DiscardHandler` | `slog.New(slog.DiscardHandler)` for tests/benchmarks. No more custom no-op handler. | Low |
| `maphash.Comparable()` | Hash any comparable value. Enables custom hash maps and sets. | Low |
| Cgo `#cgo noescape` / `#cgo nocallback` | Performance annotations for cgo. Idiomatic for cgo-heavy code. | Low |

### Go 1.25 — Missing

| Feature | What it changes | Priority |
|---------|----------------|----------|
| `os.Root` expanded API | `root.ReadFile`, `root.WriteFile`, `root.MkdirAll`, `root.Rename`, `root.RemoveAll`, `root.Symlink`, etc. The skill shows `os.OpenRoot` but only the basic `root.Open`. The full API makes it a complete sandboxed filesystem. | High |
| `encoding/json/v2` (experimental) | `GOEXPERIMENT=jsonv2`. Major rework: case-insensitive matching by default, `omitzero` behavior improvements, inline/unknown fields, format tags. Worth mentioning as upcoming. | Medium |
| `testing.T.Attr(key, value)` | Emit structured key-value attributes in test output. Idiomatic for CI/structured test reporting. | Medium |
| Vet `waitgroup` analyzer | Catches `wg.Add(1)` inside the goroutine (too late) instead of before `go`. Common mistake. | Medium |
| Vet `hostport` analyzer | Catches `host + ":" + port` instead of `net.JoinHostPort(host, port)`. The latter handles IPv6 correctly. | Medium |
| `go.mod` `ignore` directive | Tells `go` to ignore directories. Replaces naming hacks like `_testdata` or `testdata`. | Low |
| `runtime/trace.FlightRecorder` | Continuous low-overhead tracing with ring buffer. Idiomatic for production observability. | Low |

### Go 1.26 — Missing

| Feature | What it changes | Priority |
|---------|----------------|----------|
| `slog.NewMultiHandler()` | Compose multiple slog handlers (e.g., JSON to file + text to stderr). Replaces custom fan-out handlers. | Medium |
| `net/http/httputil.ReverseProxy.Director` deprecated | Use `Rewrite` method instead. Migration note for existing code. | Medium |
| `reflect` iterator methods | `Type.Fields()`, `Type.Methods()`, `Value.Fields()`, `Value.Methods()`. Idiomatic iteration over struct fields and methods. | Low |
| `os/signal.NotifyContext()` cancel cause | Signal now included in context cancel cause. `context.Cause(ctx)` returns the signal. | Low |

---

## Version Tag Corrections Needed

The skill has some iterator functions shown without version tags, or shown under the wrong version. Corrections:

| Feature | Currently shown as | Should be |
|---------|-------------------|-----------|
| `slices.All`, `slices.Values`, `slices.Backward`, `slices.Chunk`, `slices.Collect` | Under "Range Over Functions (Go 1.23+)" | Correct (Go 1.23+) — but should explicitly note these are 1.23, distinct from 1.21 `slices` |
| `maps.All`, `maps.Keys`, `maps.Values` | Under "Range Over Functions (Go 1.23+)" | Correct (Go 1.23+) — but should explicitly note these are 1.23, distinct from 1.21 `maps` |
| `strings.Lines`, `strings.SplitSeq`, etc. | Under "Range Over Functions (Go 1.23+)" | Some were Go 1.24+ (need verification) |
| `slog` section | No version tag | Should be tagged (Go 1.21+) |
| `cmp.Ordered` (used in generics section) | No version tag | Should be tagged (Go 1.21+) |
| `slices.Clone` (used in Slice & Map Patterns) | No version tag | Should be tagged (Go 1.21+) |
| PGO section | No version tag | Should note production-ready in Go 1.21+ |

---

## Recommended Additions Summary

### Tier 1 — Should Add (directly affects how idiomatic code is written)

1. **Version-tag existing content**: `slog` → 1.21+, `slices`/`maps` → 1.21+, `cmp.Ordered` → 1.21+, PGO → 1.21+
2. **`math/rand/v2`** (1.22+): New code should use this, not `math/rand`
3. **`iter.Seq`/`iter.Seq2`** (1.23+): Name the iterator types explicitly
4. **`encoding/json` `omitzero`** (1.24+): Extremely common need
5. **`tool` directives in go.mod** (1.24+): Replaces `tools.go` hack
6. **`os.Root` full API** (1.25+): Expand beyond just `Open`
7. **`errors.ErrUnsupported`** (1.21+): Standard sentinel
8. **`context.WithoutCancel`** (1.21+): Common pattern
9. **`context.AfterFunc`** (1.21+): Replaces goroutine+select boilerplate

### Tier 2 — Nice to Have (useful patterns, less frequently encountered)

10. **`unique` package** (1.23+): Value interning
11. **`slices.Concat`** (1.22+): Common operation
12. **`database/sql.Null[T]`** (1.22+): Generic nullable
13. **`weak.Pointer[T]`** (1.24+): Cache/canonicalization patterns
14. **`crypto/cipher.NewGCMWithRandomNonce`** (1.24+): Safer crypto API
15. **`testing.T.Attr`** (1.25+): Structured test output
16. **Vet analyzers** (`waitgroup`, `hostport`) (1.25+): Common mistake catchers
17. **`slog.NewMultiHandler`** (1.26+): Handler composition
18. **`ReverseProxy.Rewrite`** replacing `Director` (1.26+): Migration guidance
