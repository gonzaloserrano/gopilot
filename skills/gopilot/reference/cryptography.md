# Cryptography

## Random Number Generation

### The Problem with math/rand

`math/rand` is **deterministic** and **predictable** - completely unsuitable for security.

```go
import "math/rand"

// VULNERABLE - DO NOT USE FOR SECURITY
func main() {
    // Same number every run!
    fmt.Println(rand.Intn(1984))
}

// Output (every time):
// 1825
// 1825
// 1825
```

**Why?** Uses a deterministic seed. If seed is known/predictable, output is predictable.

### The Solution: crypto/rand

```go
import (
    "crypto/rand"
    "math/big"
)

// SAFE - use for security
func GenerateSecureRandom(max int64) (int64, error) {
    n, err := rand.Int(rand.Reader, big.NewInt(max))
    if err != nil {
        return 0, err
    }
    return n.Int64(), nil
}
```

**Benefits:**
- Uses OS-provided randomness
- Cannot be seeded (prevents developer error)
- Cryptographically secure
- Slower but safer

### When to Use crypto/rand

Always use `crypto/rand` for:
- **Session IDs**
- **Authentication tokens**
- **Password reset tokens**
- **API keys**
- **Salts** (for password hashing)
- **Nonces** (for CSRF, crypto operations)
- **Random passwords**
- **Encryption keys**

### When math/rand is OK

Use `math/rand` only for:
- Non-security randomness (games, simulations)
- Performance-critical non-security code
- Reproducible sequences (testing)

## Generating Secure Tokens

### Random Bytes

```go
import "crypto/rand"
import "encoding/base64"

func GenerateToken(length int) (string, error) {
    bytes := make([]byte, length)
    _, err := rand.Read(bytes)
    if err != nil {
        return "", err
    }

    // Encode to base64 for string representation
    return base64.URLEncoding.EncodeToString(bytes), nil
}

// Usage
token, err := GenerateToken(32) // 32 bytes = 256 bits
```

### Random String

```go
const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

func GenerateRandomString(length int) (string, error) {
    result := make([]byte, length)
    charsetLen := big.NewInt(int64(len(charset)))

    for i := range result {
        n, err := rand.Int(rand.Reader, charsetLen)
        if err != nil {
            return "", err
        }
        result[i] = charset[n.Int64()]
    }

    return string(result), nil
}
```

### UUID v4

```go
import "github.com/google/uuid"

// Uses crypto/rand internally
id := uuid.New()
fmt.Println(id.String())
// Output: 550e8400-e29b-41d4-a716-446655440000
```

## Session ID Generation

```go
func GenerateSessionID() (string, error) {
    // 32 bytes = 256 bits of entropy
    bytes := make([]byte, 32)
    _, err := rand.Read(bytes)
    if err != nil {
        return "", err
    }

    // Hex encoding for readability
    return hex.EncodeToString(bytes), nil
}

// Usage in session creation
sessionID, err := GenerateSessionID()
if err != nil {
    return fmt.Errorf("generate session ID: %w", err)
}
```

## Password Generation

```go
func GenerateSecurePassword(length int) (string, error) {
    const (
        lowerChars   = "abcdefghijklmnopqrstuvwxyz"
        upperChars   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        digitChars   = "0123456789"
        specialChars = "!@#$%^&*()-_=+[]{}|;:,.<>?"
    )

    allChars := lowerChars + upperChars + digitChars + specialChars
    charsetLen := big.NewInt(int64(len(allChars)))

    password := make([]byte, length)
    for i := range password {
        n, err := rand.Int(rand.Reader, charsetLen)
        if err != nil {
            return "", err
        }
        password[i] = allChars[n.Int64()]
    }

    return string(password), nil
}
```

## CSRF Token Generation

```go
func GenerateCSRFToken() (string, error) {
    // 32 bytes for CSRF token
    bytes := make([]byte, 32)
    if _, err := rand.Read(bytes); err != nil {
        return "", err
    }

    return base64.URLEncoding.EncodeToString(bytes), nil
}
```

## Salt Generation

```go
const SaltSize = 32 // 256 bits

func GenerateSalt() ([]byte, error) {
    salt := make([]byte, SaltSize)
    _, err := rand.Read(salt)
    return salt, err
}
```

## Attack Example: Predictable Passwords

If using `math/rand` to generate default passwords:

```go
// VULNERABLE
import "math/rand"

func GenerateDefaultPassword() string {
    // Predictable!
    return fmt.Sprintf("pass%d", rand.Intn(10000))
}

// Attacker can predict: pass1825, pass1825, pass1825...
```

With `crypto/rand`:

```go
// SAFE
import "crypto/rand"
import "math/big"

func GenerateDefaultPassword() (string, error) {
    n, err := rand.Int(rand.Reader, big.NewInt(10000))
    if err != nil {
        return "", err
    }
    return fmt.Sprintf("pass%d", n.Int64()), nil
}

// Output: pass277, pass1572, pass1793, pass1328...
```

## Error Handling

Always check errors from `crypto/rand`:

```go
// Good
bytes := make([]byte, 32)
if _, err := rand.Read(bytes); err != nil {
    // This is rare but can happen if system entropy is exhausted
    return fmt.Errorf("generate random bytes: %w", err)
}

// Bad
bytes := make([]byte, 32)
rand.Read(bytes) // Ignoring error!
```

## Best Practices

1. **Always use crypto/rand** for security
2. **Check errors** - rare but possible
3. **Sufficient entropy** - 128+ bits for secrets
4. **Base64/hex encode** for string representation
5. **Don't seed crypto/rand** - uses OS randomness
6. **Store securely** - clear from memory after use
7. **Never log** - random values used as secrets
8. **Use established libs** - uuid, gorilla/securecookie
