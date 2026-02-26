# File Security

## Path Traversal Prevention

### The Vulnerability

```go
// VULNERABLE
func BadFileRead(filename string) ([]byte, error) {
    // User provides: ../../../etc/passwd
    return os.ReadFile(filename)
}
```

### The Fix

```go
import "path/filepath"
import "strings"

func SafeFilePath(baseDir, userPath string) (string, error) {
    // Clean the path (removes .., ., etc.)
    cleanPath := filepath.Clean(userPath)

    // Build full path
    fullPath := filepath.Join(baseDir, cleanPath)

    // Verify it's within baseDir (prevents traversal)
    if !strings.HasPrefix(fullPath, filepath.Clean(baseDir)+string(os.PathSeparator)) {
        return "", errors.New("path traversal attempt detected")
    }

    return fullPath, nil
}

// Usage
func ReadUserFile(userPath string) ([]byte, error) {
    baseDir := "/var/app/uploads"
    safePath, err := SafeFilePath(baseDir, userPath)
    if err != nil {
        return nil, err
    }

    return os.ReadFile(safePath)
}
```

## File Validation

### Check File Existence

```go
func FileExists(path string) (bool, error) {
    _, err := os.Stat(path)
    if err == nil {
        return true, nil
    }
    if os.IsNotExist(err) {
        return false, nil
    }
    return false, err
}
```

### Validate File Size

```go
func ValidateFileSize(path string, maxSize int64) error {
    info, err := os.Stat(path)
    if err != nil {
        return err
    }

    if info.Size() > maxSize {
        return fmt.Errorf("file too large: %d bytes (max %d)", info.Size(), maxSize)
    }

    return nil
}

// Usage
const MaxUploadSize = 10 * 1024 * 1024 // 10MB
if err := ValidateFileSize(path, MaxUploadSize); err != nil {
    return err
}
```

### Validate File Type

```go
import "net/http"

func ValidateFileType(path string, allowedTypes []string) error {
    file, err := os.Open(path)
    if err != nil {
        return err
    }
    defer file.Close()

    // Read first 512 bytes for type detection
    buffer := make([]byte, 512)
    _, err = file.Read(buffer)
    if err != nil {
        return err
    }

    // Detect content type
    contentType := http.DetectContentType(buffer)

    // Check against allowed types
    for _, allowed := range allowedTypes {
        if contentType == allowed {
            return nil
        }
    }

    return fmt.Errorf("invalid file type: %s", contentType)
}

// Usage
allowedTypes := []string{"image/jpeg", "image/png", "image/gif"}
if err := ValidateFileType(path, allowedTypes); err != nil {
    return err
}
```

## Filename Sanitization

```go
import "regexp"

var filenameRegex = regexp.MustCompile(`[^a-zA-Z0-9._-]`)

func SanitizeFilename(filename string) string {
    // Remove path separators
    filename = filepath.Base(filename)

    // Replace invalid characters with underscore
    safe := filenameRegex.ReplaceAllString(filename, "_")

    // Limit length
    if len(safe) > 255 {
        safe = safe[:255]
    }

    return safe
}

// Usage
userFilename := r.FormValue("filename")
safeFilename := SanitizeFilename(userFilename)
```

## File Upload Handling

```go
func HandleFileUpload(w http.ResponseWriter, r *http.Request) error {
    // Limit request body size
    r.Body = http.MaxBytesReader(w, r.Body, 10<<20) // 10MB

    // Parse multipart form
    if err := r.ParseMultipartForm(10 << 20); err != nil {
        return fmt.Errorf("parse form: %w", err)
    }

    // Get file
    file, header, err := r.FormFile("upload")
    if err != nil {
        return fmt.Errorf("get file: %w", err)
    }
    defer file.Close()

    // Sanitize filename
    safeFilename := SanitizeFilename(header.Filename)

    // Validate file type
    buffer := make([]byte, 512)
    if _, err := file.Read(buffer); err != nil {
        return err
    }
    contentType := http.DetectContentType(buffer)
    if !strings.HasPrefix(contentType, "image/") {
        return errors.New("only images allowed")
    }

    // Reset file position
    if _, err := file.Seek(0, 0); err != nil {
        return err
    }

    // Build safe path
    uploadDir := "/var/app/uploads"
    safePath, err := SafeFilePath(uploadDir, safeFilename)
    if err != nil {
        return err
    }

    // Create destination file
    dst, err := os.Create(safePath)
    if err != nil {
        return err
    }
    defer dst.Close()

    // Copy file
    if _, err := io.Copy(dst, file); err != nil {
        return err
    }

    return nil
}
```

## File Permissions

```go
// Secure file permissions
const (
    FilePerms = 0600  // rw-------
    DirPerms  = 0700  // rwx------
)

// Write sensitive file
func WriteSecretFile(path string, data []byte) error {
    return os.WriteFile(path, data, FilePerms)
}

// Create secure directory
func CreateSecureDir(path string) error {
    return os.MkdirAll(path, DirPerms)
}

// Check file permissions
func ValidatePermissions(path string, expected os.FileMode) error {
    info, err := os.Stat(path)
    if err != nil {
        return err
    }

    if info.Mode().Perm() != expected {
        return fmt.Errorf("incorrect permissions: %o (expected %o)",
            info.Mode().Perm(), expected)
    }

    return nil
}
```

## Temporary Files

```go
import "os"

func CreateTempFile(pattern string) (*os.File, error) {
    // Create in system temp dir with secure permissions
    file, err := os.CreateTemp("", pattern)
    if err != nil {
        return nil, err
    }

    // Set secure permissions
    if err := file.Chmod(0600); err != nil {
        file.Close()
        os.Remove(file.Name())
        return nil, err
    }

    return file, nil
}

// Usage with cleanup
func ProcessTempFile() error {
    tmpFile, err := CreateTempFile("upload-*.tmp")
    if err != nil {
        return err
    }
    defer os.Remove(tmpFile.Name())
    defer tmpFile.Close()

    // Process file
    return nil
}
```

## Best Practices

1. **Validate paths** - prevent traversal
2. **Sanitize filenames** - remove special characters
3. **Check file types** - validate MIME type
4. **Limit file sizes** - prevent DoS
5. **Secure permissions** - 0600 for sensitive files
6. **Clean up temp files** - use defer
7. **Never trust user input** - validate everything
8. **Store outside webroot** - if possible
9. **Use unique names** - prevent overwrites
10. **Scan for malware** - if accepting uploads
