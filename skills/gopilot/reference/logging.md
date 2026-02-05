# Security Logging

## What to Log

### Security Events

- Authentication attempts (success & failure)
- Authorization failures
- Input validation failures
- Session creation/destruction
- Privilege changes
- Account lockouts
- Password changes/resets
- Security configuration changes

### System Events

- Application errors
- Database errors
- External API failures
- Resource exhaustion
- Rate limiting triggers

## What NOT to Log

**NEVER log:**
- Passwords
- Session tokens
- API keys
- Credit card numbers
- Social Security numbers
- Private keys
- Personal identifiable information (PII)
- Any sensitive authentication data

## Structured Logging with slog

```go
import "log/slog"

// Authentication failure
func LogAuthFailure(username, ip string, reason error) {
    slog.Warn("authentication failed",
        "username", username,
        "ip", ip,
        "reason", reason.Error(),
        "timestamp", time.Now().Unix(),
    )
}

// Authorization failure
func LogAuthzFailure(userID, resource, action string) {
    slog.Warn("authorization failed",
        "user_id", userID,
        "resource", resource,
        "action", action,
    )
}

// Security event
func LogSecurityEvent(event string, details map[string]any) {
    slog.Error("security event",
        "event", event,
        "details", details,
    )
}
```

## Standard Library Logging

```go
import "log"

// Set flags for timestamp and file info
log.SetFlags(log.LstdFlags | log.Lshortfile)

// Log with context
log.Printf("[AUTH_FAIL] user=%s ip=%s", username, ip)
log.Printf("[AUTHZ_FAIL] user=%s resource=%s", userID, resourceID)
log.Printf("[INPUT_INVALID] field=%s error=%s", field, err)
```

## Logging Middleware

```go
func LoggingMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()

        // Wrap response writer to capture status
        wrapped := &responseWriter{ResponseWriter: w, status: 200}

        // Process request
        next.ServeHTTP(wrapped, r)

        // Log request
        slog.Info("request",
            "method", r.Method,
            "path", r.URL.Path,
            "status", wrapped.status,
            "duration_ms", time.Since(start).Milliseconds(),
            "ip", r.RemoteAddr,
            "user_agent", r.UserAgent(),
        )
    }
}

type responseWriter struct {
    http.ResponseWriter
    status int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.status = code
    rw.ResponseWriter.WriteHeader(code)
}
```

## Context-Aware Logging

```go
type contextKey string

const userIDKey contextKey = "user_id"

func LogWithContext(ctx context.Context, msg string) {
    userID, _ := ctx.Value(userIDKey).(string)
    slog.Info(msg, "user_id", userID)
}

// Usage
ctx := context.WithValue(r.Context(), userIDKey, "user123")
LogWithContext(ctx, "operation completed")
```

## Error Logging

```go
// Log error with context, return generic message to user
func HandleError(w http.ResponseWriter, err error, userMsg string) {
    // Detailed log
    slog.Error("operation failed",
        "error", err,
        "stack", fmt.Sprintf("%+v", err),
    )

    // Generic response to user
    http.Error(w, userMsg, http.StatusInternalServerError)
}

// Usage
if err := ProcessData(); err != nil {
    HandleError(w, err, "Processing failed")
    return
}
```

## Redacting Sensitive Data

```go
type User struct {
    ID       string
    Email    string
    Password string // sensitive!
}

// MarshalJSON redacts password
func (u User) MarshalJSON() ([]byte, error) {
    type Alias User
    return json.Marshal(&struct {
        Password string `json:"password"`
        *Alias
    }{
        Password: "[REDACTED]",
        Alias:    (*Alias)(&u),
    })
}

// Safe to log
user := User{ID: "123", Email: "test@example.com", Password: "secret"}
slog.Info("user data", "user", user) // Password is [REDACTED]
```

## Rate Limiting Logs

Prevent log flooding:

```go
type RateLimitedLogger struct {
    lastLog time.Time
    mu      sync.Mutex
    minInterval time.Duration
}

func NewRateLimitedLogger(interval time.Duration) *RateLimitedLogger {
    return &RateLimitedLogger{minInterval: interval}
}

func (l *RateLimitedLogger) Log(msg string) {
    l.mu.Lock()
    defer l.mu.Unlock()

    if time.Since(l.lastLog) < l.minInterval {
        return // Skip log
    }

    log.Println(msg)
    l.lastLog = time.Now()
}
```

## Log Rotation

```go
import "gopkg.in/natefinch/lumberjack.v2"

func SetupLogRotation() {
    logFile := &lumberjack.Logger{
        Filename:   "/var/log/app.log",
        MaxSize:    100, // MB
        MaxBackups: 3,
        MaxAge:     28, // days
        Compress:   true,
    }

    log.SetOutput(logFile)
}
```

## Correlation IDs

```go
func RequestIDMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        requestID := uuid.New().String()
        ctx := context.WithValue(r.Context(), "request_id", requestID)

        slog.Info("request started",
            "request_id", requestID,
            "method", r.Method,
            "path", r.URL.Path,
        )

        next.ServeHTTP(w, r.WithContext(ctx))
    }
}
```

## Best Practices

1. **Log security events** - auth/authz failures
2. **Never log secrets** - passwords, tokens, keys
3. **Use structured logging** - machine-parseable
4. **Include context** - user ID, IP, timestamp
5. **Generic errors to users** - detailed to logs
6. **Protect log files** - appropriate permissions (0600)
7. **Rotate logs** - prevent disk exhaustion
8. **Monitor logs** - alerting on suspicious patterns
9. **Correlation IDs** - track requests across services
10. **Rate limit** - prevent log flooding
