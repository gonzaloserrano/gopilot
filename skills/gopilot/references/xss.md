# XSS (Cross-Site Scripting) Prevention

## What is XSS?

XSS allows attackers to inject malicious scripts into web pages viewed by other users.

## Types of XSS

1. **Reflected XSS** - script in URL/form, reflected in response
2. **Stored XSS** - script stored in database, served to all users
3. **DOM-based XSS** - client-side script manipulation

## Prevention: html/template

Go's `html/template` provides automatic context-aware escaping.

### Use html/template, NOT text/template

```go
import "html/template" // ✓ Safe
// NOT "text/template"  // ✗ Unsafe

func RenderPage(w http.ResponseWriter, data interface{}) {
    tmpl := template.Must(template.ParseFiles("page.html"))
    tmpl.Execute(w, data)
}
```

### Automatic Escaping

```go
type PageData struct {
    Username string
    Message  string
}

data := PageData{
    Username: "<script>alert('xss')</script>",
    Message:  "Hello!",
}

// Template automatically escapes
tmpl.Execute(w, data)
// Output: &lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;
```

## Context-Aware Escaping

html/template escapes based on context:

```html
<!-- HTML context -->
<div>{{.Username}}</div>
<!-- Escaped: &lt;script&gt; -->

<!-- Attribute context -->
<div title="{{.Username}}"></div>
<!-- Escaped: &lt;script&gt; -->

<!-- JavaScript context -->
<script>
var user = "{{.Username}}";
</script>
<!-- Escaped: \x3cscript\x3e -->

<!-- URL context -->
<a href="/user?name={{.Username}}">Link</a>
<!-- Escaped: %3Cscript%3E -->
```

## Sanitizing User Input

### HTML Sanitization

```go
import "github.com/microcosm-cc/bluemonday"

// Strict policy (removes all HTML)
func SanitizeStrict(input string) string {
    policy := bluemonday.StrictPolicy()
    return policy.Sanitize(input)
}

// Allow some safe HTML
func SanitizeHTML(input string) string {
    policy := bluemonday.UGCPolicy() // User Generated Content
    return policy.Sanitize(input)
}

// Custom policy
func SanitizeCustom(input string) string {
    policy := bluemonday.NewPolicy()
    policy.AllowElements("p", "br", "strong", "em")
    return policy.Sanitize(input)
}
```

### Strip Tags

```go
import "regexp"

var htmlTagRegex = regexp.MustCompile(`<[^>]*>`)

func StripTags(input string) string {
    return htmlTagRegex.ReplaceAllString(input, "")
}
```

## Content Security Policy (CSP)

```go
func SetCSPHeaders(w http.ResponseWriter) {
    // Strict CSP
    w.Header().Set("Content-Security-Policy",
        "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:")

    // Or more permissive
    w.Header().Set("Content-Security-Policy",
        "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.example.com")
}
```

### CSP Middleware

```go
func CSPMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Security-Policy",
            "default-src 'self'; script-src 'self'")
        w.Header().Set("X-Content-Type-Options", "nosniff")
        w.Header().Set("X-Frame-Options", "DENY")
        w.Header().Set("X-XSS-Protection", "1; mode=block")

        next.ServeHTTP(w, r)
    }
}
```

## JSON Responses

### Safe JSON Encoding

```go
// Automatically escapes HTML in JSON
func SendJSON(w http.ResponseWriter, data interface{}) error {
    w.Header().Set("Content-Type", "application/json; charset=utf-8")
    encoder := json.NewEncoder(w)
    encoder.SetEscapeHTML(true) // Default is true
    return encoder.Encode(data)
}
```

### Prevent JSON Hijacking

```go
// Add prefix to prevent JSON hijacking
func SendJSONSafe(w http.ResponseWriter, data interface{}) error {
    w.Header().Set("Content-Type", "application/json")
    w.Write([]byte(")]}'\\n")) // Prefix

    encoder := json.NewEncoder(w)
    encoder.SetEscapeHTML(true)
    return encoder.Encode(data)
}
```

## Validating Input

```go
import "regexp"

var safeStringRegex = regexp.MustCompile(`^[a-zA-Z0-9 .,!?-]+$`)

func ValidateInput(input string) error {
    // Whitelist safe characters
    if !safeStringRegex.MatchString(input) {
        return errors.New("input contains invalid characters")
    }

    // Length check
    if len(input) > 1000 {
        return errors.New("input too long")
    }

    return nil
}
```

## Markdown Rendering

```go
import "github.com/russross/blackfriday/v2"
import "github.com/microcosm-cc/bluemonday"

func RenderMarkdownSafe(markdown string) string {
    // Convert markdown to HTML
    html := blackfriday.Run([]byte(markdown))

    // Sanitize HTML
    policy := bluemonday.UGCPolicy()
    sanitized := policy.SanitizeBytes(html)

    return string(sanitized)
}
```

## Common Mistakes

### Don't Use template.HTML Unless You're Sure

```go
// Dangerous: bypasses escaping
tmpl.Execute(w, template.HTML(userInput))

// Safe: let template escape
tmpl.Execute(w, userInput)
```

### Don't Build HTML Strings Manually

```go
// Bad: vulnerable to XSS
html := "<div>" + userInput + "</div>"

// Good: use templates
tmpl := template.Must(template.New("").Parse("<div>{{.}}</div>"))
tmpl.Execute(w, userInput)
```

## Testing for XSS

```go
func TestXSSPrevention(t *testing.T) {
    xssPayloads := []string{
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert('xss')>",
        "javascript:alert('xss')",
        "<svg onload=alert('xss')>",
    }

    for _, payload := range xssPayloads {
        output := RenderTemplate(payload)

        // Ensure payload is escaped
        if strings.Contains(output, "<script>") {
            t.Errorf("XSS payload not escaped: %s", payload)
        }
    }
}
```

## Best Practices

1. **Use html/template** - automatic escaping
2. **Validate input** - whitelist safe characters
3. **Sanitize HTML** - use bluemonday for user HTML
4. **Content-Security-Policy** - restrict script sources
5. **Never trust user input** - always escape
6. **Avoid template.HTML** - bypasses escaping
7. **Set charset** - `charset=utf-8` in Content-Type
8. **Test with payloads** - use XSS test strings
9. **HTTPOnly cookies** - prevent script access
10. **Security headers** - X-XSS-Protection, X-Content-Type-Options
