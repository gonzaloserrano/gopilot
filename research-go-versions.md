# Research: Adding More Go Versions to gopilot

## Current State

The gopilot skill (`skills/gopilot/SKILL.md`) currently covers Go 1.20 through Go 1.26 with 48 version-annotated references. The README lists Go 1.21–1.26 in the version support table.

### Current Coverage Per Version

| Version | # Refs | Features Covered |
|---------|--------|-----------------|
| Go 1.20 | 1 | `errors.Join` |
| Go 1.21 | 5 | `context.WithCancelCause`, `min`/`max`/`clear` builtins, `sync.OnceFunc`/`OnceValue`/`OnceValues` |
| Go 1.22 | 5 | Range over int, `cmp.Or`, HTTP routing with patterns, loop variable fix |
| Go 1.23 | 2 | Range over functions, Timer/Ticker channel capacity change |
| Go 1.24 | 10 | Generic type aliases, `b.Loop()`, `t.Context()`/`t.Chdir()`, `os.OpenRoot`, `runtime.AddCleanup`, `crypto/rand.Text()`, post-quantum ML-KEM |
| Go 1.25 | 7 | `testing/synctest`, `sync.WaitGroup.Go()`, `http.CrossOriginProtection`, compiler nil-check bug fix |
| Go 1.26 | 7 | `errors.AsType[T]()`, `new(expr)`, self-referential constraints, `t.ArtifactDir()`, `go fix` modernizers, goroutine leak profile |

---

## Go 1.26 Status

Go 1.26 RC1 was released December 16, 2025. The full release is targeted for February 2026 (current date: Feb 17, 2026, so it should be released or imminent).

### Go 1.26 — Features Missing from the Skill

The skill covers the headline Go 1.26 features well. Notable additions that could be included:

#### Language & Compiler
- (already covered) `new(expr)`, self-referential generic constraints

#### Standard Library — New Packages
1. **`crypto/hpke`** — Hybrid Public Key Encryption (RFC 9180), includes post-quantum hybrid KEM support. Important for security-focused skill.
2. **`simd/archsimd`** (experimental, `GOEXPERIMENT=simd`) — Architecture-specific SIMD operations. Probably too niche for the skill.
3. **`runtime/secret`** (experimental, `GOEXPERIMENT=runtimesecret`) — Secure erasure of temporaries in crypto code. Relevant to security section.

#### Standard Library — New APIs
4. **`errors.AsType[T]()`** — Already covered.
5. **`bytes.Buffer.Peek(n)`** — Returns next n bytes without advancing.
6. **`io.ReadAll` improvements** — ~2x faster, ~50% less memory.
7. **`log/slog.NewMultiHandler()`** — Composes multiple slog handlers.
8. **`net.Dialer.DialTCP()`/`DialUDP()`/`DialIP()`/`DialUnix()`** — Context-aware typed dial methods.
9. **`reflect` iterator methods** — `Type.Fields()`, `Type.Methods()`, `Value.Fields()`, `Value.Methods()`, etc.
10. **`testing.T.ArtifactDir()`** — Already covered.
11. **`os/signal.NotifyContext()` now uses `CancelCauseFunc`** — Signal is included in cancel cause.
12. **`net/netip.Prefix.Compare()`** — Comparison method.
13. **`runtime/metrics` new scheduler metrics** — `/sched/goroutines`, `/sched/threads:threads`, `/sched/goroutines-created:goroutines`.

#### Runtime
14. **Green Tea GC now default** — 10-40% GC overhead reduction. Major performance story.
15. **~30% faster cgo calls** — Significant for cgo users.
16. **Heap base address randomization** — Security enhancement.
17. **Goroutine leak profile** — Already covered.

#### Tools
18. **Revamped `go fix`** — Already covered.
19. **`go mod init` defaults to lower Go version** — `go 1.(N-1).0`.

#### Crypto
20. **Post-quantum hybrid key exchanges default in TLS** — `SecP256r1MLKEM768`, `SecP384r1MLKEM1024` now on by default.
21. **`crypto/ecdsa` deprecates `big.Int` fields** — Migration note.
22. **Random parameter changes** — Multiple crypto packages now ignore the `random` parameter, always using secure source.

#### Breaking / Notable Changes
23. **`net/url.Parse()` rejects malformed host with colons** — e.g., `http://::1/` now fails.
24. **`net/http/httputil.ReverseProxy.Director` deprecated** — Use `Rewrite` instead.
25. **windows/arm port removed** — Platform change.
26. **macOS 12 last supported release** — Go 1.27 will require macOS 13.

---

## Go 1.25 — Features Missing from the Skill

### Currently Covered
- `testing/synctest` (graduated from experimental)
- `sync.WaitGroup.Go()`
- `http.CrossOriginProtection`
- Compiler nil-check bug fix

### Missing Features Worth Adding

#### Runtime
1. **Container-aware GOMAXPROCS** — Automatically tunes based on cgroup CPU limits on Linux. Major for cloud/container deployments.
2. **Green Tea GC (experimental)** — `GOEXPERIMENT=greenteagc`, 10-40% GC overhead reduction.
3. **`runtime/trace.FlightRecorder`** — Continuous low-overhead execution tracing with ring buffer.

#### Standard Library
4. **`encoding/json/v2`** (experimental, `GOEXPERIMENT=jsonv2`) — Major revision with better performance and new marshaler/unmarshaler options.
5. **`slog.Record.Source()` method** — Returns source location.
6. **`slog.GroupAttrs()`** — Creates group Attr from slice.
7. **`os.Root` expanded methods** — `Chmod`, `Chown`, `Chtimes`, `Lchown`, `Link`, `MkdirAll`, `ReadFile`, `Readlink`, `RemoveAll`, `Rename`, `Symlink`, `WriteFile`.
8. **`reflect.TypeAssert`** — Converts Value to Go value without unnecessary allocations.
9. **`hash.XOF` interface** — Extendable output functions (SHAKE).
10. **`hash.Cloner` interface** — All standard Hash implementations now implement it.
11. **`io/fs.ReadLinkFS`** — Interface for reading symbolic links.
12. **`mime/multipart.FileContentDisposition`** — Helper for multipart Content-Disposition.
13. **`testing.T.Attr()`/`B.Attr()`/`F.Attr()`** — Emit structured attributes to test log.
14. **`testing.Output()`** — Provides `io.Writer` to test output stream.

#### Vet
15. **`waitgroup` analyzer** — Reports misplaced `sync.WaitGroup.Add` calls.
16. **`hostport` analyzer** — Reports incorrect `host:port` formatting, suggests `net.JoinHostPort`.

#### Tools
17. **`go doc -http`** — Starts documentation server and opens browser.
18. **`go.mod` `ignore` directive** — Specifies directories to ignore in package patterns.
19. **`go build -asan` defaults to leak detection** at program exit.

#### Crypto
20. **`crypto/ecdsa` new raw encoding functions** — `ParseRawPrivateKey`, `ParseUncompressedPublicKey`, `PrivateKey.Bytes`, `PublicKey.Bytes`.
21. **SHA-1 signature algorithms disallowed in TLS 1.2** — RFC 9155.
22. **`crypto/tls.ConnectionState.CurveID`** — Exposes key exchange mechanism.
23. **Encrypted Client Hello (ECH) support** — `Config.GetEncryptedClientHelloKeys` callback.

#### Compiler
24. **DWARF5 support** — Reduces debug info size.
25. **Faster slice stack allocation** — Compiler allocates slice backing stores on stack more often.

---

## Go 1.24 — Features Missing from the Skill

### Currently Covered
- Generic type aliases
- `b.Loop()`
- `t.Context()`, `t.Chdir()`
- `os.OpenRoot()`
- `runtime.AddCleanup`
- `crypto/rand.Text()`
- Post-quantum ML-KEM default

### Missing Features Worth Adding

#### Runtime
1. **Swiss Tables map implementation** — Up to 60% faster map operations. Major performance win.
2. **Overall 2-3% CPU overhead reduction** — Representative benchmarks.
3. **PGO build caching** — Repeated `go run`/`go tool` now cached.

#### Standard Library
4. **`weak.Pointer[T]`** — New `weak` package for weak references (enables caches, canonicalization maps).
5. **`crypto/mlkem`** — ML-KEM-768 and ML-KEM-1024 (post-quantum key exchange, FIPS 203).
6. **`crypto/hkdf`** — HMAC-based key derivation (RFC 5869).
7. **`crypto/pbkdf2`** — Password-based key derivation (RFC 8018). Relevant for password hashing guidance.
8. **`crypto/sha3`** — SHA-3 and SHAKE functions (FIPS 202).
9. **`crypto/cipher.NewGCMWithRandomNonce()`** — Generates random nonce automatically.
10. **`crypto/subtle.WithDataIndependentTiming()`** — Architecture-specific constant-time execution.
11. **FIPS 140-3 compliance module** — `GOFIPS140` env var, `GODEBUG=fips140=1`.
12. **`encoding/json` `omitzero` struct tag** — Omit field if zero value (clearer than `omitempty`).
13. **`maphash.Comparable()`** — Hash any comparable value.
14. **`slog.DiscardHandler`** — Handler that discards all output.
15. **`testing/synctest` (experimental)** — Was experimental with `GOEXPERIMENT=synctest` in Go 1.24, graduated in Go 1.25.

#### Tools
16. **`tool` directives in go.mod** — Track executable dependencies. Replaces `tools.go` pattern.
17. **`GOAUTH` environment variable** — Flexible auth for private module fetches.
18. **Cgo `#cgo noescape` and `#cgo nocallback`** — Performance annotations.

#### Compiler
19. **PGO improvements** — Interleaved devirtualization and inlining. 2-14% improvement.

#### Breaking / Notable Changes
20. **`crypto/rand.Read()` guaranteed not to fail** — Always returns nil error.
21. **RSA keys < 1024 bits rejected** — All operations return error.
22. **`runtime.GOROOT()` deprecated** — Use `go env GOROOT` instead.

---

## Go 1.23 — Features Missing from the Skill

### Currently Covered
- Range over functions (iter.Seq)
- Timer/Ticker channel capacity change

### Missing Features Worth Adding

1. **`iter` package** — Core iterator types (`Seq[V]`, `Seq2[K,V]`).
2. **`unique` package** — Value canonicalization/interning. `unique.Make[T]()` returns `Handle[T]`.
3. **`structs.HostLayout`** — Marks structs conforming to host platform layout expectations.
4. **`slices` iterator functions** — `All`, `Values`, `Backward`, `Collect`, `AppendSeq`, `Sorted`, `SortedFunc`, `Chunk`, `Repeat`.
5. **`maps` iterator functions** — `All`, `Keys`, `Values`, `Insert`, `Collect`.
6. **`strings` iterator functions** — `Lines`, `SplitSeq`, `SplitAfterSeq`, `FieldsSeq`, `FieldsFuncSeq`.
7. **`bytes` iterator functions** — Same as strings.
8. **`go/ast.Preorder()`** — Iterator over syntax tree nodes.
9. **`sync.Map.Clear()`** — Deletes all entries.
10. **`sync/atomic.And()`, `Or()`** — Bitwise AND/OR with old value return.
11. **`net.KeepAliveConfig`** — Fine-tuned TCP keep-alive configuration.
12. **`runtime/debug.SetCrashOutput()`** — Specifies alternate file for crash reports.
13. **`//go:linkname` restrictions** — Linker now restricts linking to internal stdlib symbols.
14. **ECH support in `crypto/tls`** — Encrypted Client Hello.
15. **Post-quantum X25519Kyber768Draft00 enabled by default in TLS**.

---

## Go 1.22 — Features Missing from the Skill

### Currently Covered
- Range over integers
- Loop variable fix (per-iteration)
- `cmp.Or`
- HTTP routing with patterns

### Missing Features Worth Adding

1. **`math/rand/v2`** — First v2 stdlib package. ChaCha8/PCG generators, generic `N` function.
2. **`go/version`** — Functions for validating/comparing Go version strings.
3. **`database/sql.Null[T]`** — Generic nullable type.
4. **`reflect.TypeFor[T]()`** — Generic function to get `reflect.Type`.
5. **`slices.Concat()`** — Concatenate multiple slices.
6. **Runtime improvements** — Type-based GC metadata, 1-3% CPU improvement, ~1% memory reduction.

---

## Go 1.21 — Features Missing from the Skill

### Currently Covered
- `min`/`max`/`clear` builtins
- `context.WithCancelCause`
- `sync.OnceFunc`/`OnceValue`/`OnceValues`

### Missing Features Worth Adding

1. **`log/slog`** — Structured logging package. Already covered in the skill as a pattern but not tagged as Go 1.21+.
2. **`slices` package** — Generic slice operations. Already referenced but the package itself is Go 1.21+.
3. **`maps` package** — Generic map operations. Already referenced but the package itself is Go 1.21+.
4. **`cmp` package** — `Ordered` constraint, `Less()`, `Compare()` functions.
5. **PGO production-ready** — Was preview in 1.20, now stable. Already in skill but not version-tagged.
6. **`runtime.Pinner`** — Pin Go memory for C code access.
7. **`errors.ErrUnsupported`** — Standard error for unsupported operations.
8. **`context.WithoutCancel()`** — Non-canceled context copy.
9. **`context.AfterFunc()`** — Register function to run after context cancellation.
10. **`encoding/binary.NativeEndian`** — Machine-native byte order.
11. **`panic(nil)` now causes `*runtime.PanicNilError`** — Breaking behavior change.

---

## Recommendations

### Priority 1: High-Impact Features to Add

These are features most Go developers encounter regularly:

| Feature | Version | Why |
|---------|---------|-----|
| `log/slog` version tag (Go 1.21+) | 1.21 | Already in skill, just needs version annotation |
| `slices`/`maps` packages version tag | 1.21 | Already referenced, needs version annotation |
| Container-aware GOMAXPROCS | 1.25 | Critical for cloud/container deployments |
| Green Tea GC (default in 1.26) | 1.25/1.26 | Major performance story |
| Swiss Tables maps | 1.24 | Up to 60% faster maps |
| `encoding/json` `omitzero` tag | 1.24 | Very commonly needed |
| `tool` directives in go.mod | 1.24 | Replaces common `tools.go` pattern |
| `math/rand/v2` | 1.22 | First v2 package, important for new code |
| `unique` package | 1.23 | Useful for interning/canonicalization |
| `weak.Pointer[T]` | 1.24 | Low-level primitive for caches |

### Priority 2: Security-Relevant Additions

Given the skill's strong security focus:

| Feature | Version | Why |
|---------|---------|-----|
| `crypto/hpke` | 1.26 | Post-quantum hybrid encryption |
| `runtime/secret` (experimental) | 1.26 | Secure erasure of crypto temporaries |
| Post-quantum TLS default | 1.26 | `SecP256r1MLKEM768` now default |
| `crypto/rand.Read()` never fails | 1.24 | API guarantee change |
| FIPS 140-3 compliance module | 1.24 | Enterprise compliance |
| `crypto/mlkem` | 1.24 | Post-quantum key exchange |
| `crypto/hkdf`, `crypto/pbkdf2` | 1.24 | Standard key derivation in stdlib |
| SHA-1 disallowed in TLS 1.2 | 1.25 | Security hardening |
| Heap base address randomization | 1.26 | Security enhancement |
| Encrypted Client Hello (ECH) | 1.23/1.25 | Privacy enhancement |

### Priority 3: Testing & Tooling Additions

| Feature | Version | Why |
|---------|---------|-----|
| `testing.T.Attr()` | 1.25 | Structured test output |
| `testing.Output()` | 1.25 | Test output stream |
| Vet `waitgroup` analyzer | 1.25 | Catches common WaitGroup mistakes |
| Vet `hostport` analyzer | 1.25 | Catches `host:port` formatting bugs |
| `go doc -http` | 1.25 | Documentation server |
| `go.mod` `ignore` directive | 1.25 | Ignore directories in patterns |

### Priority 4: Nice-to-Have Additions

| Feature | Version | Why |
|---------|---------|-----|
| `context.WithoutCancel()` | 1.21 | Useful context pattern |
| `context.AfterFunc()` | 1.21 | Context cleanup pattern |
| `errors.ErrUnsupported` | 1.21 | Standard error sentinel |
| `database/sql.Null[T]` | 1.22 | Generic nullable |
| `reflect.TypeFor[T]()` | 1.22 | Generic reflection |
| `io.ReadAll` 2x faster | 1.26 | Performance awareness |
| `slog.NewMultiHandler()` | 1.26 | Multi-handler composition |
| `runtime/trace.FlightRecorder` | 1.25 | Observability |

---

## Version Support Scope Question

The skill currently covers Go 1.20–1.26. Consider whether to:

1. **Keep Go 1.20 as the floor** — Go 1.20 was released Feb 2023. Given Go's 2-releases-per-year cadence and support for only the latest 2 major releases, Go 1.20 through 1.23 are all EOL. The supported versions as of Feb 2026 are Go 1.25 and Go 1.26.

2. **Add Go 1.19 or earlier** — Probably not worth it. Features from Go 1.19 and earlier are well-established idioms that don't need version tags.

3. **Focus depth on Go 1.24–1.26** — These are the versions actively in use. Go 1.24 is still receiving patch releases (1.24.13 released Feb 2026).

**Recommendation**: Keep Go 1.20 as the minimum referenced version (it established `errors.Join` which is a fundamental pattern). Focus new additions on Go 1.24–1.26 features since those are what developers actively encounter when upgrading.

---

## Summary

The skill has solid coverage of the most impactful features per version but is notably light on:

1. **Go 1.21**: Missing `slog`, `slices`, `maps`, `cmp` package version annotations (these are referenced but not tagged)
2. **Go 1.22**: Missing `math/rand/v2`, `database/sql.Null[T]`
3. **Go 1.23**: Missing `unique` package, `slices`/`maps` iterator functions, `strings`/`bytes` iterator functions
4. **Go 1.24**: Missing Swiss Tables performance story, `encoding/json` `omitzero`, `tool` directives, `weak` package, FIPS 140-3, several crypto packages
5. **Go 1.25**: Missing container-aware GOMAXPROCS, Green Tea GC (experimental), Flight Recorder, `encoding/json/v2` (experimental), vet analyzers
6. **Go 1.26**: Missing Green Tea GC (default), `crypto/hpke`, post-quantum TLS defaults, heap randomization, `slog.NewMultiHandler()`, `reflect` iterators, faster cgo

The biggest gaps are in the **runtime/performance** and **crypto/security** areas across Go 1.24–1.26.
