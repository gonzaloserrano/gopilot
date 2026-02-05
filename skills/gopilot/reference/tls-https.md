# TLS/HTTPS Communication Security

## Basic HTTPS Server

### Simple Setup

```go
import (
    "log"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("Secure server\n"))
    })

    // Simple HTTPS - gets "A" grade on SSL Labs
    log.Fatal(http.ListenAndServeTLS(
        ":443",
        "cert.pem",  // Certificate file
        "key.pem",   // Private key file
        nil,
    ))
}
```

### With HSTS Header

```go
func secureHandler(w http.ResponseWriter, r *http.Request) {
    // HTTP Strict Transport Security
    w.Header().Add("Strict-Transport-Security",
        "max-age=63072000; includeSubDomains")

    w.Write([]byte("Secure content"))
}
```

## TLS Configuration

### Basic Config

```go
import (
    "crypto/tls"
    "net/http"
)

func main() {
    config := &tls.Config{
        MinVersion:               tls.VersionTLS12,
        MaxVersion:               tls.VersionTLS13,
        PreferServerCipherSuites: true,
        CurvePreferences: []tls.CurveID{
            tls.CurveP256,
            tls.X25519,
        },
    }

    server := &http.Server{
        Addr:      ":443",
        TLSConfig: config,
    }

    log.Fatal(server.ListenAndServeTLS("cert.pem", "key.pem"))
}
```

### TLS Versions

```go
config := &tls.Config{
    // Minimum TLS 1.2 (disables 1.0, 1.1, SSLv3)
    MinVersion: tls.VersionTLS12,

    // Maximum TLS 1.3
    MaxVersion: tls.VersionTLS13,
}
```

**Supported versions:**
- `tls.VersionTLS10` (deprecated)
- `tls.VersionTLS11` (deprecated)
- `tls.VersionTLS12` (minimum recommended)
- `tls.VersionTLS13` (latest)

## Certificate Management

### Loading Certificates

```go
import "crypto/tls"

func LoadCertificates(certFile, keyFile string) (tls.Certificate, error) {
    cert, err := tls.LoadX509KeyPair(certFile, keyFile)
    if err != nil {
        return tls.Certificate{}, fmt.Errorf("load cert: %w", err)
    }
    return cert, nil
}
```

### Multiple Certificates (SNI)

```go
func SetupSNI() error {
    config := &tls.Config{
        MinVersion: tls.VersionTLS12,
    }

    // Load multiple certificates
    cert1, err := tls.LoadX509KeyPair("site1.pem", "site1.key")
    if err != nil {
        return err
    }

    cert2, err := tls.LoadX509KeyPair("site2.pem", "site2.key")
    if err != nil {
        return err
    }

    config.Certificates = []tls.Certificate{cert1, cert2}

    // Create TLS listener
    listener, err := tls.Listen("tcp", ":443", config)
    if err != nil {
        return err
    }

    return http.Serve(listener, nil)
}
```

### Certificate Verification

```go
config := &tls.Config{
    // NEVER set to true in production!
    InsecureSkipVerify: false,

    // Set expected server name
    ServerName: "example.com",
}
```

## Client TLS Configuration

### HTTPS Client

```go
import (
    "crypto/tls"
    "net/http"
)

func CreateSecureClient() *http.Client {
    config := &tls.Config{
        MinVersion:         tls.VersionTLS12,
        InsecureSkipVerify: false,  // ALWAYS false in production
    }

    transport := &http.Transport{
        TLSClientConfig: config,
    }

    return &http.Client{
        Transport: transport,
        Timeout:   30 * time.Second,
    }
}

// Usage
client := CreateSecureClient()
resp, err := client.Get("https://example.com")
```

### Custom CA Certificates

```go
import (
    "crypto/x509"
    "os"
)

func LoadCustomCA(caFile string) (*tls.Config, error) {
    caCert, err := os.ReadFile(caFile)
    if err != nil {
        return nil, err
    }

    caCertPool := x509.NewCertPool()
    if !caCertPool.AppendCertsFromPEM(caCert) {
        return nil, errors.New("failed to parse CA certificate")
    }

    config := &tls.Config{
        RootCAs:    caCertPool,
        MinVersion: tls.VersionTLS12,
    }

    return config, nil
}
```

## Cipher Suites

### Preferred Ciphers

```go
config := &tls.Config{
    MinVersion: tls.VersionTLS12,
    CipherSuites: []uint16{
        tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
        tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
        tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
        tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
    },
    PreferServerCipherSuites: true,
}
```

**Note:** TLS 1.3 ciphers are not configurable and use secure defaults.

## Mutual TLS (mTLS)

### Server-Side mTLS

```go
func SetupMTLS(caCertFile string) (*tls.Config, error) {
    // Load CA cert
    caCert, err := os.ReadFile(caCertFile)
    if err != nil {
        return nil, err
    }

    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)

    config := &tls.Config{
        ClientCAs:  caCertPool,
        ClientAuth: tls.RequireAndVerifyClientCert,
        MinVersion: tls.VersionTLS12,
    }

    return config, nil
}
```

### Client-Side mTLS

```go
func CreateMTLSClient(certFile, keyFile, caFile string) (*http.Client, error) {
    // Load client cert
    cert, err := tls.LoadX509KeyPair(certFile, keyFile)
    if err != nil {
        return nil, err
    }

    // Load CA cert
    caCert, err := os.ReadFile(caFile)
    if err != nil {
        return nil, err
    }

    caCertPool := x509.NewCertPool()
    caCertPool.AppendCertsFromPEM(caCert)

    config := &tls.Config{
        Certificates: []tls.Certificate{cert},
        RootCAs:      caCertPool,
        MinVersion:   tls.VersionTLS12,
    }

    transport := &http.Transport{
        TLSClientConfig: config,
    }

    return &http.Client{Transport: transport}, nil
}
```

## Security Headers

### Essential Headers

```go
func AddSecurityHeaders(w http.ResponseWriter) {
    // HSTS - Force HTTPS
    w.Header().Set("Strict-Transport-Security",
        "max-age=63072000; includeSubDomains; preload")

    // Content Security Policy
    w.Header().Set("Content-Security-Policy",
        "default-src 'self'")

    // Prevent MIME sniffing
    w.Header().Set("X-Content-Type-Options", "nosniff")

    // XSS Protection
    w.Header().Set("X-XSS-Protection", "1; mode=block")

    // Frame options
    w.Header().Set("X-Frame-Options", "DENY")

    // Referrer policy
    w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

    // Permissions policy
    w.Header().Set("Permissions-Policy", "geolocation=(), microphone=()")
}
```

### Content-Type with Charset

```go
w.Header().Set("Content-Type", "text/html; charset=utf-8")
w.Header().Set("Content-Type", "application/json; charset=utf-8")
```

## HTTP to HTTPS Redirect

```go
func redirectToHTTPS(w http.ResponseWriter, r *http.Request) {
    target := "https://" + r.Host + r.URL.Path
    if len(r.URL.RawQuery) > 0 {
        target += "?" + r.URL.RawQuery
    }
    http.Redirect(w, r, target, http.StatusPermanentRedirect)
}

func main() {
    // HTTP redirect server
    go func() {
        http.ListenAndServe(":80", http.HandlerFunc(redirectToHTTPS))
    }()

    // HTTPS server
    http.HandleFunc("/", handleSecure)
    log.Fatal(http.ListenAndServeTLS(":443", "cert.pem", "key.pem", nil))
}
```

## Testing TLS Configuration

### SSL Labs

Test your server at: https://www.ssllabs.com/ssltest/

### testssl.sh

```bash
# Command-line testing
testssl.sh https://example.com
```

### OpenSSL

```bash
# Test TLS connection
openssl s_client -connect example.com:443 -tls1_2

# Check certificate
openssl s_client -connect example.com:443 -showcerts
```

## Common Vulnerabilities

### POODLE
**Protection:** Disable SSLv3 (Go does this by default)

### BEAST
**Protection:** Use TLS 1.1+ (prefer TLS 1.2+)

### CRIME
**Protection:** Disable TLS compression (Go doesn't support it)

### Heartbleed
**Protection:** Keep OpenSSL updated (Go uses native implementation)

### Downgrade Attacks
**Protection:**
- Set `MinVersion` to TLS 1.2
- Go doesn't support fallback (not vulnerable to POODLE-style downgrades)

## Certificate Best Practices

1. **Valid certificates** - not self-signed in production
2. **Correct domain** - matches your server name
3. **Not expired** - monitor expiration dates
4. **Intermediate certs** - include full chain
5. **Strong key** - 2048-bit RSA minimum (4096-bit preferred)
6. **Let's Encrypt** - free automated certificates

### Automated Certificates

```go
import "golang.org/x/crypto/acme/autocert"

func main() {
    m := &autocert.Manager{
        Prompt:     autocert.AcceptTOS,
        HostPolicy: autocert.HostWhitelist("example.com"),
        Cache:      autocert.DirCache("/path/to/cert/cache"),
    }

    server := &http.Server{
        Addr:      ":https",
        TLSConfig: m.TLSConfig(),
    }

    log.Fatal(server.ListenAndServeTLS("", ""))
}
```

## Production Checklist

- [ ] TLS 1.2+ only (`MinVersion: tls.VersionTLS12`)
- [ ] `InsecureSkipVerify: false`
- [ ] Valid certificates with correct domain
- [ ] HSTS header enabled
- [ ] Security headers set
- [ ] HTTP redirects to HTTPS
- [ ] Certificate auto-renewal configured
- [ ] Tested with SSL Labs (A+ grade)
- [ ] Secure cipher suites
- [ ] No sensitive data in URLs or headers over plain HTTP
