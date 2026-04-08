---
name: go-error-hygiene
description: "v1.0.27 -- Detect and fix Go error handling antipatterns across a codebase. Use when auditing error handling, fixing double-handled errors, removing log-and-return patterns, cleaning up log-and-wrap helpers, or when the user asks to analyze error handling hygiene, find error handling violations, or ensure errors are handled exactly once. Covers detection patterns, classification of true vs false positives, fix strategies for interior vs boundary code, and verification steps."
---

# Go Error Hygiene

Detect and fix the "handle errors more than once" antipattern across a Go codebase.

## The Rule

An error should be handled **exactly once**. Handling means one of:

- **Logging** it (to stdout, a logger, or a tracing span)
- **Returning** it to the caller (wrapped with context)
- **Degrading gracefully** (fallback, retry, default value)

If you do more than one at the same call site, you're double-handling. The most common violation: **log AND return**.

## Why It Matters

- Duplicate log lines obscure root cause during incidents
- Callers that receive the returned error may log it again, tripling noise
- Coupling observability (tracing/logging) with error propagation makes both harder to change
- Interior log noise buries the wrapped error chain that actually tells the story

## Detection Procedure

### Step 1: Find helper functions that log AND wrap

Search for functions that combine logging/tracing with error wrapping in a single call:

```bash
# Find definitions (handles both functions and methods)
rg -n "^func\b.*\b(Log|Trace|Record)\w*(Wrap|Error|Return)" --type go
rg -n "^func\b.*\b(Wrap|Return)\w*(Log|Trace|Record)" --type go

# Find usages of common helpers
rg -n "LogAndWrapError|logAndReturn|wrapAndLog|traceAndWrap" --type go
```

Read each definition. If the function both logs/traces AND returns a wrapped error, it's a codified antipattern.

### Step 2: Find explicit log-then-return blocks

Search for logging calls near error returns:

```bash
# Standard library log (exclude Fatal -- it's terminal, not double-handling)
rg -n "log\.(Printf|Println|Print)\b" --type go -A 3

# Zap
rg -n "zap\.L\(\)\.(Error|Warn)|logger\.(Error|Warn|Errorw|Warnw)" --type go -A 3

# Slog
rg -n "slog\.(Error|Warn)" --type go -A 3

# OpenTracing/OpenTelemetry span logging
rg -n "span\.(LogFields|SetTag|RecordError|AddEvent)|tracing\.LogError" --type go -A 3
```

For each match, check whether a `return ...err` follows within 1-3 lines. If yes, it's a double-handle candidate.

### Step 3: Find bare error returns after logging

```bash
rg -n "(Error|Warn).*zap\.Error\(err\)" --type go -A 3
```

Look for `return err` (without wrapping) after a log call. This is double-handling AND loses context.

### Step 4: Count the scope

```bash
# Count helper usage per file
rg -c "LogAndWrapError|logAndReturn|wrapAndLog" --type go | sort -t: -k2 -rn

# Count total occurrences
rg "LogAndWrapError" --type go --count-matches
```

## Classification

### True double-handling -- FIX these

| Pattern | Example |
|---------|---------|
| Log + return wrapped | `log.Error(...); return fmt.Errorf(...)` |
| Log-and-wrap helper | `return LogAndWrapError(span, msg, err)` |
| Span log + return | `tracing.LogError(span, ...); return fmt.Errorf(...)` |
| Log + return bare err | `log.Error(...); return err` |

### NOT double-handling -- LEAVE these alone

| Pattern | Why |
|---------|-----|
| Log + `return nil` / `continue` | Error is absorbed, not propagated. Logging IS the single handling. |
| Log in goroutine that can't return | No caller to propagate to. |
| Interface method that can't return error (e.g., `Collect()`) | Logging is the only option. |
| Boundary handler that logs + returns HTTP/gRPC status | This IS the top-level handler -- it's handling once at the boundary. |
| Log + `panic` / `os.Exit` / `log.Fatal` | Terminal -- not propagation. |
| Log in deferred cleanup (e.g., `defer tx.Rollback`) | Deferred functions can't return errors to the caller. |
| Metrics counter + return error | Metrics are aggregated counters, not per-event noise. Not double-handling. |

## Fix Strategy

### Interior vs. boundary

**Interior code** (repositories, services, domain logic, library packages):
- Should ONLY wrap and return
- Never log -- callers do that
- Never record to spans/traces -- middleware or boundary does that

**Boundary code** (HTTP handlers, gRPC interceptors, worker loops, `main`, background goroutines):
- Should log or record to observability
- Should NOT propagate the error further (or if it does, it's the final handler)
- This is where you handle the error

### Fix recipes

**Interior: log-and-wrap helper → just wrap**

```go
// Before
return errorsutil.LogAndWrapError(span, "query failed", err)

// After
return fmt.Errorf("query failed: %w", err)

// Multi-return variant -- same fix, preserve other return values
// Before
return false, errorsutil.LogAndWrapError(span, "query failed", err)
// After
return false, fmt.Errorf("query failed: %w", err)
```

After each replacement, check whether `span` and the `errorsutil` import are still used elsewhere in the function/file. If `span` is now unused, check whether the span setup (`span, ctx := opentracing.StartSpanFromContext(...)` + `defer span.Finish()`) is still needed for tracing the operation itself. If the span only existed for `LogAndWrapError` calls, removing it is a separate refactor -- mark it as a follow-up, don't block the error hygiene fix on it.

**Interior: log + return wrapped → just return wrapped**

```go
// Before
if err != nil {
    zap.L().Error("connect failed", zap.Error(err))
    return fmt.Errorf("connect: %w", err)
}

// After
if err != nil {
    return fmt.Errorf("connect: %w", err)
}
```

**Interior: log + return bare error → wrap and return**

```go
// Before
if err != nil {
    zap.L().Error("query failed", zap.Error(err))
    return err
}

// After
if err != nil {
    return fmt.Errorf("query: %w", err)
}
```

**Interior: span log + return → just return**

```go
// Before
if err != nil {
    tracing.LogError(span, "fetch user", err)
    return fmt.Errorf("fetch user: %w", err)
}

// After
if err != nil {
    return fmt.Errorf("fetch user: %w", err)
}
```

### After removing interior logging, ensure boundary coverage

Verify the boundary handler (HTTP handler, worker loop, gRPC interceptor) logs the error. If no boundary handler exists, add one:

```go
// Boundary example: worker loop
func (w *Worker) Run(ctx context.Context) {
    for job := range w.jobs {
        if err := w.process(ctx, job); err != nil {
            w.logger.Error("job failed",
                zap.String("job_id", job.ID),
                zap.Error(err),
            )
            // handle: retry, mark failed, etc.
        }
    }
}
```

If the codebase uses tracing, add span error recording at the boundary (middleware/interceptor), not at every interior call site:

```go
// Boundary: tracing middleware
func tracingInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
    span, ctx := opentracing.StartSpanFromContext(ctx, info.FullMethod)
    defer span.Finish()

    resp, err := handler(ctx, req)
    if err != nil {
        tracing.LogError(span, info.FullMethod, err)
    }
    return resp, err
}
```

## Cleanup

After fixing all call sites for a helper like `LogAndWrapError`:

1. Check if the helper has zero callers: `rg "LogAndWrapError" --type go`
2. If zero, delete the helper function and its file/package
3. Remove unused imports from all fixed files
4. Run `goimports` to clean up

## Execution Workflow

Work file-by-file, highest call count first:

1. **Grep** for the antipattern in the file
2. **Read** each occurrence with surrounding context
3. **Classify** -- true double-handling or false positive?
4. **Fix** each true positive using the recipes above
5. **Verify** after each file:
   - `go build ./...` -- catches unused vars/imports from the fix
   - `go test ./<affected-package>/...` -- test only what changed, not the whole repo
6. **Move to next file**
7. After all files: `golangci-lint run ./...` once

After all files are done, clean up unused helpers and imports.

## Common Objections

**"We'll lose span/trace logging!"**
Move it to middleware/interceptors. One place records all errors with traces, not hundreds of scattered call sites.

**"Some errors need extra fields in the log."**
Use error wrapping with structured context: `fmt.Errorf("user %s query %s: %w", userID, query, err)`. The boundary logger extracts what it needs from the error chain.

**"What if the boundary doesn't log?"**
Then fix the boundary. The answer to "my boundary doesn't log" is not "log at every interior layer" -- it's "add proper boundary error handling."
