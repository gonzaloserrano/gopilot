# Security Checklist & Guides

Based on OWASP Go Secure Coding Practices.

## Quick Checklist

**Input/Output:**
- [ ] All user input validated server-side
- [ ] SQL queries use prepared statements only
- [ ] XSS protection via `html/template`
- [ ] CSRF tokens on state-changing requests
- [ ] File paths validated against traversal (`os.OpenRoot` Go 1.24+)

**Auth/Sessions:**
- [ ] Passwords hashed with bcrypt/Argon2/PBKDF2
- [ ] `crypto/rand` for all tokens/session IDs (`crypto/rand.Text()` Go 1.24+)
- [ ] Secure cookie flags (HttpOnly, Secure, SameSite)
- [ ] Session expiration enforced

**Communication:**
- [ ] HTTPS/TLS everywhere, TLS 1.2+ only (post-quantum ML-KEM default Go 1.24+)
- [ ] HSTS header set
- [ ] `InsecureSkipVerify = false`

**Data Protection:**
- [ ] Secrets in environment variables, never in logs/errors
- [ ] Generic error messages to users

## Detailed Guides

Read the relevant guide when implementing security-sensitive features. Each covers patterns, code examples, and common pitfalls for its domain.

- [Input Validation](input-validation.md) -- read when accepting user input: whitelisting, boundary checks, escaping
- [Database Security](database-security.md) -- read when writing SQL or database code: prepared statements, parameterized queries
- [Authentication](authentication.md) -- read when implementing login, signup, or password flows: bcrypt, Argon2, password policies
- [Cryptography](cryptography.md) -- read when generating tokens, secrets, or random values: `crypto/rand`, never `math/rand` for security
- [Session Management](session-management.md) -- read when implementing user sessions: secure cookies, session lifecycle, JWT
- [TLS/HTTPS](tls-https.md) -- read when configuring servers or HTTP clients: TLS config, HSTS, mTLS, post-quantum key exchanges
- [CSRF Protection](csrf.md) -- read when building forms or state-changing endpoints: token generation, `http.CrossOriginProtection` (Go 1.25+)
- [Secure Error Handling](error-handling.md) -- read when designing error responses: generic user messages, detailed server logs
- [File Security](file-security.md) -- read when handling file uploads or filesystem access: path traversal prevention, `os.OpenRoot`
- [Security Logging](logging.md) -- read when implementing audit trails: what to log, what never to log, redaction
- [Access Control](access-control.md) -- read when implementing authorization: RBAC, ABAC, principle of least privilege
- [XSS Prevention](xss.md) -- read when rendering user content in HTML: `html/template`, CSP, sanitization

## Security Tools

| Tool | Purpose | Command |
|------|---------|---------|
| gosec | Security scanner | `gosec ./...` |
| govulncheck | Vulnerability scanner | `govulncheck ./...` |
| trivy | Container/dep scanner | `trivy fs .` |
