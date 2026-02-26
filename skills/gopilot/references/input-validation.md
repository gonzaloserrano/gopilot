# Input Validation

## Core Principle

**If validation fails, reject the input.** This is critical for security, data consistency, and integrity.

## Validation Strategy

### Server-Side Only
- Always validate on trusted system (server)
- Never rely on client-side validation alone
- Sequential authentication: validate only on completion of all input

### Standard Library Tools

```go
// strconv - type conversions
import "strconv"

i, err := strconv.Atoi("123")           // string to int
b, err := strconv.ParseBool("true")     // string to bool
f, err := strconv.ParseFloat("3.14", 64)// string to float
val, err := strconv.ParseInt("42", 10, 64) // string to int64

// strings - manipulation
import "strings"

s = strings.Trim(input, " ")            // remove whitespace
s = strings.ToLower(input)              // normalize case
s = strings.ToTitle(input)              // title case

// unicode/utf8 - UTF-8 validation
import "unicode/utf8"

valid := utf8.ValidString(input)        // validate UTF-8 string
validRune := utf8.ValidRune(r)          // validate single rune
```

## Validation Techniques

### Whitelisting
Validate against allowed characters only (most secure).

```go
import "regexp"

// Allow only alphanumeric
var alphanumericRegex = regexp.MustCompile(`^[a-zA-Z0-9]+$`)

func ValidateUsername(username string) bool {
    return alphanumericRegex.MatchString(username)
}
```

### Boundary Checking
Verify length constraints.

```go
func ValidateInput(input string, minLen, maxLen int) error {
    if len(input) < minLen {
        return fmt.Errorf("input too short (min %d)", minLen)
    }
    if len(input) > maxLen {
        return fmt.Errorf("input too long (max %d)", maxLen)
    }
    return nil
}
```

### Security Checks

```go
import "strings"

func SecurityValidation(input string) error {
    // Check for null bytes
    if strings.Contains(input, "\x00") {
        return errors.New("null byte detected")
    }

    // Check for newlines
    if strings.ContainsAny(input, "\r\n") {
        return errors.New("newline character detected")
    }

    // Check for path traversal
    if strings.Contains(input, "..") {
        return errors.New("path traversal attempt detected")
    }

    return nil
}
```

## Third-Party Validation

### Validator Package

```go
import "github.com/go-playground/validator/v10"

type User struct {
    Email    string `validate:"required,email"`
    Age      int    `validate:"gte=0,lte=130"`
    Username string `validate:"required,alphanum,min=3,max=30"`
}

validate := validator.New()
user := &User{Email: "test@example.com", Age: 25, Username: "john"}

err := validate.Struct(user)
if err != nil {
    // Handle validation errors
}
```

### Form Decoding

```go
import "github.com/go-playground/form"

decoder := form.NewDecoder()

var user User
err := decoder.Decode(&user, r.URL.Query())
```

## File Validation

```go
import "os"

func ValidateFile(filename string) error {
    // Check file exists
    _, err := os.Stat(filename)
    if os.IsNotExist(err) {
        return fmt.Errorf("file does not exist: %s", filename)
    }

    // Check file size
    info, err := os.Stat(filename)
    if err != nil {
        return err
    }

    maxSize := int64(10 * 1024 * 1024) // 10MB
    if info.Size() > maxSize {
        return fmt.Errorf("file too large: %d bytes", info.Size())
    }

    return nil
}
```

## Post-Validation Actions

### Enforcement Actions
- Inform user of validation failure
- Modify data server-side (cosmetic changes only)

### Advisory Actions
- Allow unchanged data but warn user
- Suitable for non-interactive systems

### Verification Actions
- Suggest corrections to user
- User accepts or keeps original input

## HTTP Header Validation

```go
func ValidateHTTPHeaders(headers http.Header) error {
    for key, values := range headers {
        for _, value := range values {
            // Ensure ASCII-only
            for _, c := range value {
                if c > 127 {
                    return fmt.Errorf("non-ASCII character in header %s", key)
                }
            }
        }
    }
    return nil
}
```

## Data Source Validation

- Cross-system consistency checks
- Hash totals for data integrity
- Referential integrity (database foreign keys)
- Uniqueness checks for primary keys
- Table lookup validation

## Best Practices

1. **Reject by default** - invalid input is rejected
2. **Validate early** - at entry points
3. **Validate completely** - don't skip any input
4. **Use whitelisting** - more secure than blacklisting
5. **Check extended UTF-8** - alternative character representations
6. **Escape special characters** - quotes, etc.
7. **Use established libraries** - don't reinvent validation
