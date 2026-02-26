# Error Handling & Security

## Core Principle

**Never leak sensitive information in errors to users.**

## Error Types

### Built-in Errors

```go
// Check errors
if err != nil {
    return fmt.Errorf("operation failed: %w", err)
}

// Create custom errors
var ErrUnauthorized = errors.New("unauthorized access")

// Check error type
if errors.Is(err, ErrUnauthorized) {
    // Handle specific error
}
```

### Custom Errors

```go
type SecurityError struct {
    Code    string
    Message string
    Err     error
}

func (e *SecurityError) Error() string {
    return e.Message
}

func (e *SecurityError) Unwrap() error {
    return e.Err
}
```

## Security Best Practices

### Generic Messages to Users

```go
// Good: generic message
func HandleAuth(w http.ResponseWriter, r *http.Request) {
    err := AuthenticateUser(creds)
    if err != nil {
        // Generic to user
        http.Error(w, "Invalid credentials", http.StatusUnauthorized)

        // Detailed to logs
        log.Printf("auth failed for %s: %v", username, err)
        return
    }
}

// Bad: reveals information
func BadHandleAuth(w http.ResponseWriter, r *http.Request) {
    err := AuthenticateUser(creds)
    if err != nil {
        // DON'T reveal details!
        http.Error(w, fmt.Sprintf("Auth failed: %v", err), 500)
    }
}
```

### No Stack Traces to Users

```go
// Good
func HandleError(w http.ResponseWriter, err error) {
    // Log full error with stack trace
    log.Printf("error: %+v", err)

    // Generic message to user
    http.Error(w, "Internal server error", http.StatusInternalServerError)
}

// Bad
func BadHandleError(w http.ResponseWriter, err error) {
    // Exposes internal structure!
    http.Error(w, fmt.Sprintf("%+v", err), 500)
}
```

## Panic/Recover/Defer

### Recovery from Panic

```go
func SafeHandler(w http.ResponseWriter, r *http.Request) {
    defer func() {
        if r := recover(); r != nil {
            // Log the panic
            log.Printf("panic recovered: %v", r)

            // Generic error to user
            http.Error(w, "Internal error", http.StatusInternalServerError)
        }
    }()

    // Risky operation
    DoSomethingRisky()
}
```

### Defer for Cleanup

```go
func ProcessRequest() error {
    // Cleanup always executes
    defer cleanup()

    // Even if this panics
    return doWork()
}
```

## log.Fatal Considerations

`log.Fatal` calls `os.Exit(1)`:
- Defer statements **don't** execute
- Buffers **don't** flush
- Resources **aren't** cleaned up

### When to Use log.Fatal

```go
func main() {
    // Environment validation
    dbPass := os.Getenv("DB_PASSWORD")
    if dbPass == "" {
        log.Fatal("DB_PASSWORD not set")
    }

    // Initialization failures
    db, err := sql.Open("postgres", dsn)
    if err != nil {
        log.Fatal(err)
    }
}
```

### When NOT to Use

```go
// Bad: in request handlers
func HandleRequest(w http.ResponseWriter, r *http.Request) {
    err := ProcessData()
    if err != nil {
        log.Fatal(err)  // DON'T - kills entire server!
    }
}

// Good: return error instead
func HandleRequest(w http.ResponseWriter, r *http.Request) {
    err := ProcessData()
    if err != nil {
        log.Printf("process error: %v", err)
        http.Error(w, "Internal error", 500)
        return
    }
}
```

## Error Wrapping

```go
// Add context while preserving original error
if err != nil {
    return fmt.Errorf("connect to database: %w", err)
}

// Check wrapped errors
if errors.Is(err, sql.ErrNoRows) {
    // Handle not found
}

// Extract error type
var netErr *net.OpError
if errors.As(err, &netErr) {
    // Handle network error
}
```

## Default Deny on Errors

```go
// Good: fail secure
func CheckPermission(userID, resourceID string) bool {
    hasPermission, err := db.CheckAccess(userID, resourceID)
    if err != nil {
        // Deny on error
        log.Printf("permission check failed: %v", err)
        return false
    }
    return hasPermission
}

// Bad: fail open (security risk!)
func BadCheckPermission(userID, resourceID string) bool {
    hasPermission, err := db.CheckAccess(userID, resourceID)
    if err != nil {
        // DON'T grant access on error!
        return true
    }
    return hasPermission
}
```

## Logging Errors

### What to Log

```go
// Security events
log.Printf("failed login attempt: user=%s ip=%s", username, ip)
log.Printf("permission denied: user=%s resource=%s", userID, resourceID)
log.Printf("invalid input: field=%s value=%s", field, value)

// System errors
log.Printf("database error: %v", err)
log.Printf("external API error: %v", err)
```

### What NOT to Log

```go
// NEVER log sensitive data
log.Printf("password: %s", password)       // NO!
log.Printf("token: %s", token)             // NO!
log.Printf("credit card: %s", cardNumber) // NO!
log.Printf("SSN: %s", ssn)                 // NO!
```

## Structured Logging

```go
import "log/slog"

// Security event
slog.Warn("authentication failed",
    "username", username,
    "ip", r.RemoteAddr,
    "timestamp", time.Now(),
)

// Error with context
slog.Error("database query failed",
    "error", err,
    "query", "SELECT ...",
    "user_id", userID,
)
```

## HTTP Error Responses

```go
// Standard error responses
func RespondError(w http.ResponseWriter, code int, message string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(code)
    json.NewEncoder(w).Encode(map[string]string{
        "error": message,
    })
}

// Usage
RespondError(w, 401, "Unauthorized")
RespondError(w, 403, "Forbidden")
RespondError(w, 404, "Not found")
RespondError(w, 500, "Internal server error")
```

## Best Practices

1. **Generic errors to users** - don't leak internals
2. **Detailed logs server-side** - for debugging
3. **No stack traces** - to users
4. **Default deny** - fail securely
5. **Use defer** - for cleanup
6. **Avoid log.Fatal** - except initialization
7. **Wrap errors** - add context with %w
8. **Structured logging** - for machine parsing
9. **Log security events** - auth failures, permission denials
10. **Never log secrets** - passwords, tokens, keys
