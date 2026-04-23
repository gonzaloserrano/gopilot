# Go Testing

## Table-Driven Tests
```go
func TestFoo(t *testing.T) {
    testCases := []struct {
        name           string
        input          string
        expectedResult string
        expectedError  error
    }{
        {
            name:          "EmptyInput",
            input:         "",
            expectedError: ErrEmpty,
        },
        {
            name:           "ValidInput",
            input:          "hello",
            expectedResult: "HELLO",
        },
    }
    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            got, err := Foo(tc.input)
            if tc.expectedError != nil {
                require.ErrorIs(t, err, tc.expectedError)
                return
            }
            require.NoError(t, err)
            require.Equal(t, tc.expectedResult, got)
        })
    }
}
```

## Benchmarks (Go 1.24+)
```go
func BenchmarkFoo(b *testing.B) {
    for b.Loop() {  // Cleaner than for i := 0; i < b.N; i++
        Foo()
    }
}
```
Benefits: single execution per `-count`, prevents compiler optimizations away.

## Assertions
- Use the testify library for conciseness. Use `require` for fatal assertions, `assert` for non-fatal
- Prefer semantic helpers: `require.Zero`/`require.NotZero`, `require.Empty`/`require.NotEmpty`, `require.Nil`/`require.NotNil` over `require.Equal(t, 0, ...)`, `require.Equal(t, "", ...)`, etc.
- Skip the message arg on `require.NoError`/`require.Error`: the error value and file:line trace already tell you what failed. Only add a message when multiple calls could produce the same ambiguous error
- `require.ErrorIs` for sentinel errors (not string matching)
- `require.JSONEq`/`require.YAMLEq` for semantic comparison
- Use `testdata/` folders for expected values
- Use `embed.FS` for test data files

## Test Doubles

Hand-rolled fakes: embed the interface as an anonymous nil field and implement only the methods the test calls. Unimplemented methods panic, so unexpected code paths fail loudly instead of silently no-opping.

```go
type fakeObjectFile struct {
    s3.ObjectFile // nil; Seek/Close/Stat panic if called
    readErr error
}

func (f *fakeObjectFile) Read(p []byte) (int, error) { return 0, f.readErr }
```

Use for focused tests where only a method or two are exercised. Not for production (latent panic) or tests needing call-count/argument assertions — use `gomock` or `testify/mock` instead.

## Practices
- Test function names: use `TestFooBar` (PascalCase), not `TestFoo_Bar` (no underscores)
- `t.Helper()` in helper functions
- `t.Cleanup()` for resource cleanup
- `t.Context()` for test-scoped context (Go 1.24+), never `context.Background()` in tests
- `t.Chdir()` for temp directory changes (Go 1.24+)
- `t.ArtifactDir()` for test output files (Go 1.26+)
- `t.Parallel()` for independent tests (works at both top-level tests and subtests within `t.Run`; top-level tests run sequentially by default, `t.Parallel()` opts them into concurrent execution)
- `-race` flag always
- Don't test stdlib; test YOUR code
- Bug fix → add regression test first
- Concurrent code needs concurrent tests
- Detect goroutine leaks with `go.uber.org/goleak`:
  ```go
  func TestMain(m *testing.M) {
      goleak.VerifyTestMain(m) // fails if any goroutine outlives the test suite
  }
  // Or per-test:
  func TestFoo(t *testing.T) {
      defer goleak.VerifyNone(t)
      // ...
  }
  ```
  Use `goleak.IgnoreTopFunction("...")` to allowlist known long-lived goroutines (e.g., `signal.Notify` handler)

## Testing Concurrent Code with synctest (Go 1.25+)

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
