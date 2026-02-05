# Authentication & Password Management

## Password Storage Theory

### Why Hash Passwords?

You need a one-way function `H` where:
- `H(p1) ≠ H(p2)` when `p1 ≠ p2`
- No inverse function `H⁻¹` exists to recover `p1` from `H(p1)`

### The Salt Problem

Without salt, identical passwords produce identical hashes:
- Vulnerable to rainbow table attacks
- Pre-computed hash databases

**Solution:** Add unique per-user salt:
- `H(salt + password)` produces different hashes for same password
- Salt is stored in plaintext (not secret)
- Prevents rainbow tables

## Password Storage Practice

### Never Roll Your Own Crypto

Use approved algorithms:
- **bcrypt** (recommended - simplest)
- **Argon2** (winner of Password Hashing Competition)
- **PBKDF2** (older, still acceptable)
- **scrypt** (memory-hard)

**DO NOT use:** MD5, SHA-1, plain SHA-256

### bcrypt (Recommended)

```go
import "golang.org/x/crypto/bcrypt"

// Hash password
func HashPassword(password string) (string, error) {
    bytes, err := bcrypt.GenerateFromPassword(
        []byte(password),
        bcrypt.DefaultCost, // Cost of 10-12 recommended
    )
    return string(bytes), err
}

// Verify password
func CheckPassword(password, hash string) error {
    return bcrypt.CompareHashAndPassword(
        []byte(hash),
        []byte(password),
    )
}
```

### Store in Database

```go
func CreateUser(email, password string) error {
    ctx := context.Background()

    // Hash password
    hashedPassword, err := bcrypt.GenerateFromPassword(
        []byte(password),
        bcrypt.DefaultCost,
    )
    if err != nil {
        return fmt.Errorf("hash password: %w", err)
    }

    // Store in database
    stmt, err := db.PrepareContext(ctx,
        "INSERT INTO accounts (email, hash) VALUES (?, ?)")
    if err != nil {
        return fmt.Errorf("prepare: %w", err)
    }
    defer stmt.Close()

    _, err = stmt.ExecContext(ctx, email, hashedPassword)
    return err
}
```

### Verify User Login

```go
func AuthenticateUser(email, password string) error {
    ctx := context.Background()

    // Fetch hash from database
    var storedHash string
    err := db.QueryRowContext(ctx,
        "SELECT hash FROM accounts WHERE email = ? LIMIT 1",
        email,
    ).Scan(&storedHash)

    if err != nil {
        if err == sql.ErrNoRows {
            // User doesn't exist
            // Return generic error (don't reveal if user exists)
            return errors.New("invalid credentials")
        }
        // Log actual error server-side
        log.Printf("auth query failed: %v", err)
        return errors.New("authentication failed")
    }

    // Compare password with hash
    err = bcrypt.CompareHashAndPassword(
        []byte(storedHash),
        []byte(password),
    )
    if err != nil {
        // Password mismatch
        log.Printf("password mismatch for user: %s", email)
        return errors.New("invalid credentials")
    }

    return nil
}
```

## Alternative: passwd Package

For abstraction with safe defaults:

```go
import "github.com/ermites-io/passwd"

// Hash password
hash, err := passwd.Hash("my-password")

// Verify password
ok, err := passwd.Verify("my-password", hash)
```

## Password Policies

### Requirements

- **Minimum length**: 8 characters (12+ recommended)
- **Complexity**: Mix of uppercase, lowercase, numbers, special chars
- **History**: Prevent reuse of last N passwords
- **Expiration**: Periodic password rotation (90-180 days)
- **Lockout**: Lock account after N failed attempts

```go
import "unicode"

func ValidatePasswordStrength(password string) error {
    var (
        hasMinLen  = false
        hasUpper   = false
        hasLower   = false
        hasNumber  = false
        hasSpecial = false
    )

    if len(password) >= 12 {
        hasMinLen = true
    }

    for _, char := range password {
        switch {
        case unicode.IsUpper(char):
            hasUpper = true
        case unicode.IsLower(char):
            hasLower = true
        case unicode.IsNumber(char):
            hasNumber = true
        case unicode.IsPunct(char) || unicode.IsSymbol(char):
            hasSpecial = true
        }
    }

    if !hasMinLen {
        return errors.New("password must be at least 12 characters")
    }
    if !hasUpper {
        return errors.New("password must contain uppercase letter")
    }
    if !hasLower {
        return errors.New("password must contain lowercase letter")
    }
    if !hasNumber {
        return errors.New("password must contain number")
    }
    if !hasSpecial {
        return errors.New("password must contain special character")
    }

    return nil
}
```

## Authentication Guidelines

### Fail Securely

```go
// Good: Generic error message
func Login(username, password string) error {
    user, err := GetUser(username)
    if err != nil {
        // Don't reveal if user exists
        return errors.New("invalid credentials")
    }

    if !CheckPassword(password, user.Hash) {
        // Same generic message
        return errors.New("invalid credentials")
    }

    return nil
}
```

### Account Lockout

```go
const MaxFailedAttempts = 5
const LockoutDuration = 15 * time.Minute

func RecordFailedLogin(userID string) error {
    // Increment failed attempts
    _, err := db.Exec(
        "UPDATE accounts SET failed_attempts = failed_attempts + 1, last_failed = ? WHERE id = ?",
        time.Now(), userID,
    )

    // Check if should lock
    var attempts int
    db.QueryRow("SELECT failed_attempts FROM accounts WHERE id = ?", userID).Scan(&attempts)

    if attempts >= MaxFailedAttempts {
        _, err = db.Exec(
            "UPDATE accounts SET locked_until = ? WHERE id = ?",
            time.Now().Add(LockoutDuration), userID,
        )
    }

    return err
}

func IsAccountLocked(userID string) (bool, error) {
    var lockedUntil sql.NullTime
    err := db.QueryRow(
        "SELECT locked_until FROM accounts WHERE id = ?",
        userID,
    ).Scan(&lockedUntil)

    if err != nil {
        return false, err
    }

    if !lockedUntil.Valid {
        return false, nil
    }

    return time.Now().Before(lockedUntil.Time), nil
}
```

### No Concurrent Logins

```go
// Track active sessions
type Session struct {
    UserID    string
    Token     string
    CreatedAt time.Time
}

func CreateSession(userID string) (*Session, error) {
    // Invalidate existing sessions for user
    _, err := db.Exec("DELETE FROM sessions WHERE user_id = ?", userID)
    if err != nil {
        return nil, err
    }

    // Create new session
    token, err := GenerateSecureToken()
    if err != nil {
        return nil, err
    }

    session := &Session{
        UserID:    userID,
        Token:     token,
        CreatedAt: time.Now(),
    }

    _, err = db.Exec(
        "INSERT INTO sessions (user_id, token, created_at) VALUES (?, ?, ?)",
        session.UserID, session.Token, session.CreatedAt,
    )

    return session, err
}
```

## Communicating Authentication Data

### Never Over Insecure Channels

- Always use HTTPS/TLS
- Never send credentials in URL parameters
- Never log credentials
- Never store credentials in cookies (use session tokens)

### Session Tokens, Not Passwords

```go
// After successful authentication
func HandleLogin(w http.ResponseWriter, r *http.Request) {
    // Verify credentials
    userID, err := Authenticate(username, password)
    if err != nil {
        http.Error(w, "Invalid credentials", http.StatusUnauthorized)
        return
    }

    // Create session token (not password!)
    session, err := CreateSession(userID)
    if err != nil {
        http.Error(w, "Internal error", http.StatusInternalServerError)
        return
    }

    // Store token in secure cookie
    http.SetCookie(w, &http.Cookie{
        Name:     "session",
        Value:    session.Token,
        HttpOnly: true,
        Secure:   true,
        SameSite: http.SameSiteStrictMode,
        Expires:  time.Now().Add(30 * time.Minute),
    })
}
```

## Best Practices

1. **Use bcrypt** with DefaultCost
2. **Generic error messages** - "invalid credentials"
3. **Validate password strength** - enforce policies
4. **Account lockout** - after failed attempts
5. **No concurrent sessions** - invalidate old sessions
6. **Log auth events** - success and failure
7. **HTTPS only** - for credential transmission
8. **Session tokens** - not passwords in cookies
9. **Multi-factor auth** - for sensitive operations
10. **Password reset** - secure token-based flow
