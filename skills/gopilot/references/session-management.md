# Session Management

## Core Principles

- Server-generated session identifiers only
- Cryptographically random session IDs
- Secure cookie configuration
- Generate new session on sign-in
- Enforce session expiration
- HTTPS for all session traffic

## JWT Sessions

### Creating JWT Tokens

```go
import "github.com/golang-jwt/jwt/v5"

func CreateJWT(userID string, secret []byte) (string, error) {
    // Set claims
    claims := jwt.MapClaims{
        "user_id": userID,
        "exp":     time.Now().Add(30 * time.Minute).Unix(),
        "iat":     time.Now().Unix(),
    }

    // Create token
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

    // Sign token
    signedToken, err := token.SignedString(secret)
    if err != nil {
        return "", fmt.Errorf("sign token: %w", err)
    }

    return signedToken, nil
}
```

### Verifying JWT Tokens

```go
func VerifyJWT(tokenString string, secret []byte) (*jwt.Token, error) {
    token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
        // Verify signing method
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return secret, nil
    })

    if err != nil {
        return nil, err
    }

    if !token.Valid {
        return nil, errors.New("invalid token")
    }

    return token, nil
}
```

## Secure Cookies

### Cookie Configuration

```go
func SetSessionCookie(w http.ResponseWriter, sessionToken string) {
    cookie := http.Cookie{
        Name:     "SessionID",
        Value:    sessionToken,
        Path:     "/",
        Domain:   "example.com",      // Set your domain
        Expires:  time.Now().Add(30 * time.Minute),
        MaxAge:   1800,               // 30 minutes in seconds

        // Security flags
        HttpOnly: true,               // Prevent JavaScript access (XSS protection)
        Secure:   true,               // HTTPS only
        SameSite: http.SameSiteStrictMode, // CSRF protection
    }

    http.SetCookie(w, &cookie)
}
```

### Cookie Attributes Explained

| Attribute | Purpose | Value |
|-----------|---------|-------|
| `HttpOnly` | Prevent XSS | `true` |
| `Secure` | HTTPS only | `true` |
| `SameSite` | CSRF protection | `Strict` or `Lax` |
| `Expires` | Session lifetime | 15-30 min |
| `Path` | Cookie scope | `/` |
| `Domain` | Cookie domain | Your domain |

### Reading Cookies

```go
func GetSessionCookie(r *http.Request) (string, error) {
    cookie, err := r.Cookie("SessionID")
    if err != nil {
        if err == http.ErrNoCookie {
            return "", errors.New("no session cookie")
        }
        return "", err
    }

    return cookie.Value, nil
}
```

## Session Storage

### In-Memory Sessions

```go
import "sync"

type SessionStore struct {
    sessions map[string]*Session
    mu       sync.RWMutex
}

type Session struct {
    UserID    string
    CreatedAt time.Time
    ExpiresAt time.Time
}

func NewSessionStore() *SessionStore {
    return &SessionStore{
        sessions: make(map[string]*Session),
    }
}

func (s *SessionStore) Create(userID string, duration time.Duration) (string, error) {
    // Generate secure session ID
    sessionID, err := GenerateSessionID()
    if err != nil {
        return "", err
    }

    s.mu.Lock()
    defer s.mu.Unlock()

    s.sessions[sessionID] = &Session{
        UserID:    userID,
        CreatedAt: time.Now(),
        ExpiresAt: time.Now().Add(duration),
    }

    return sessionID, nil
}

func (s *SessionStore) Get(sessionID string) (*Session, error) {
    s.mu.RLock()
    defer s.mu.RUnlock()

    session, exists := s.sessions[sessionID]
    if !exists {
        return nil, errors.New("session not found")
    }

    // Check expiration
    if time.Now().After(session.ExpiresAt) {
        return nil, errors.New("session expired")
    }

    return session, nil
}

func (s *SessionStore) Delete(sessionID string) {
    s.mu.Lock()
    defer s.mu.Unlock()
    delete(s.sessions, sessionID)
}
```

### Database Sessions

```go
func CreateSessionDB(userID string) (string, error) {
    ctx := context.Background()

    // Generate session ID
    sessionID, err := GenerateSessionID()
    if err != nil {
        return "", err
    }

    // Store in database
    _, err = db.ExecContext(ctx,
        `INSERT INTO sessions (id, user_id, created_at, expires_at)
         VALUES (?, ?, ?, ?)`,
        sessionID,
        userID,
        time.Now(),
        time.Now().Add(30*time.Minute),
    )

    return sessionID, err
}

func GetSessionDB(sessionID string) (*Session, error) {
    ctx := context.Background()

    var session Session
    err := db.QueryRowContext(ctx,
        `SELECT user_id, created_at, expires_at FROM sessions
         WHERE id = ? AND expires_at > ?`,
        sessionID,
        time.Now(),
    ).Scan(&session.UserID, &session.CreatedAt, &session.ExpiresAt)

    if err != nil {
        if err == sql.ErrNoRows {
            return nil, errors.New("session not found or expired")
        }
        return nil, err
    }

    return &session, nil
}
```

## Session Lifecycle

### Login

```go
func HandleLogin(w http.ResponseWriter, r *http.Request) {
    username := r.FormValue("username")
    password := r.FormValue("password")

    // Authenticate user
    userID, err := AuthenticateUser(username, password)
    if err != nil {
        http.Error(w, "Invalid credentials", http.StatusUnauthorized)
        return
    }

    // Create NEW session (never reuse)
    sessionID, err := CreateSession(userID)
    if err != nil {
        http.Error(w, "Internal error", http.StatusInternalServerError)
        return
    }

    // Set secure cookie
    SetSessionCookie(w, sessionID)

    // Redirect to dashboard
    http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
}
```

### Logout

```go
func HandleLogout(w http.ResponseWriter, r *http.Request) {
    // Get session ID
    sessionID, err := GetSessionCookie(r)
    if err != nil {
        // No session to logout
        http.Redirect(w, r, "/", http.StatusSeeOther)
        return
    }

    // Delete session from store
    DeleteSession(sessionID)

    // Clear cookie
    http.SetCookie(w, &http.Cookie{
        Name:     "SessionID",
        Value:    "",
        Path:     "/",
        MaxAge:   -1,         // Delete immediately
        HttpOnly: true,
        Secure:   true,
    })

    http.Redirect(w, r, "/", http.StatusSeeOther)
}
```

### Session Validation Middleware

```go
func RequireSession(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Get session cookie
        sessionID, err := GetSessionCookie(r)
        if err != nil {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }

        // Validate session
        session, err := GetSession(sessionID)
        if err != nil {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }

        // Add user ID to context
        ctx := context.WithValue(r.Context(), "userID", session.UserID)
        next.ServeHTTP(w, r.WithContext(ctx))
    }
}

// Usage
http.HandleFunc("/dashboard", RequireSession(handleDashboard))
```

## Session Best Practices

### 1. Regenerate on Privilege Change

```go
func PromoteToAdmin(userID string, oldSessionID string) (string, error) {
    // Delete old session
    DeleteSession(oldSessionID)

    // Create new session
    newSessionID, err := CreateSession(userID)
    if err != nil {
        return "", err
    }

    // Update user role
    UpdateUserRole(userID, "admin")

    return newSessionID, nil
}
```

### 2. Session Timeout

```go
func CleanExpiredSessions() {
    ticker := time.NewTicker(5 * time.Minute)
    defer ticker.Stop()

    for range ticker.C {
        // Delete expired sessions from database
        _, err := db.Exec(
            "DELETE FROM sessions WHERE expires_at < ?",
            time.Now(),
        )
        if err != nil {
            log.Printf("cleanup error: %v", err)
        }
    }
}

// Start in background
go CleanExpiredSessions()
```

### 3. Prevent Concurrent Sessions

```go
func CreateSessionSingleUser(userID string) (string, error) {
    // Delete all existing sessions for user
    _, err := db.Exec("DELETE FROM sessions WHERE user_id = ?", userID)
    if err != nil {
        return "", err
    }

    // Create new session
    return CreateSessionDB(userID)
}
```

## HTTPS Requirement

Always use HTTPS for session management:

```go
func main() {
    // HTTPS server
    err := http.ListenAndServeTLS(
        ":443",
        "cert.pem",
        "key.pem",
        nil,
    )
    log.Fatal(err)
}
```

## Gorilla Sessions

Alternative using gorilla/sessions:

```go
import "github.com/gorilla/sessions"

var store = sessions.NewCookieStore([]byte("secret-key"))

func HandleLogin(w http.ResponseWriter, r *http.Request) {
    session, _ := store.Get(r, "session-name")

    // Set session values
    session.Values["userID"] = userID
    session.Options = &sessions.Options{
        Path:     "/",
        MaxAge:   1800,
        HttpOnly: true,
        Secure:   true,
        SameSite: http.SameSiteStrictMode,
    }

    session.Save(r, w)
}
```

## Summary

1. **Use crypto/rand** for session IDs
2. **Secure cookies** (HttpOnly, Secure, SameSite)
3. **HTTPS only** for session traffic
4. **New session on login** (never reuse)
5. **Enforce expiration** (30 min for low-risk apps)
6. **Never in URLs** (cookies or headers only)
7. **Prevent concurrent logins** (optional)
8. **Clean up expired** sessions regularly
