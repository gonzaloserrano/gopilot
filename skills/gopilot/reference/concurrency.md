# Concurrency

## Design
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

## Channel Axioms

| Operation | nil channel | closed channel |
|-----------|-------------|----------------|
| Send      | blocks forever | **panics** |
| Receive   | blocks forever | returns zero value |
| Close     | **panics** | **panics** |

- Nil channels are useful in `select` to disable a case
- Use `for range ch` to receive until closed
- Check closure with `v, ok := <-ch`
