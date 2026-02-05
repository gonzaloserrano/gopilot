# Access Control

## Principle of Least Privilege

Grant minimum permissions necessary for each role/user.

## Permission Checking

### Before Every Operation

```go
func HandleResource(w http.ResponseWriter, r *http.Request) {
    userID := getUserFromSession(r)
    resourceID := r.URL.Query().Get("id")

    // Check permission BEFORE operation
    if !HasPermission(userID, resourceID, "read") {
        http.Error(w, "Forbidden", http.StatusForbidden)
        LogAuthzFailure(userID, resourceID, "read")
        return
    }

    // Proceed with operation
    resource, err := GetResource(resourceID)
    // ...
}
```

### Permission Check Function

```go
func HasPermission(userID, resourceID, action string) bool {
    ctx := context.Background()

    var hasAccess bool
    err := db.QueryRowContext(ctx,
        `SELECT EXISTS(
            SELECT 1 FROM permissions
            WHERE user_id = ? AND resource_id = ? AND action = ?
        )`,
        userID, resourceID, action,
    ).Scan(&hasAccess)

    if err != nil {
        // Deny on error (fail secure)
        log.Printf("permission check failed: %v", err)
        return false
    }

    return hasAccess
}
```

## Role-Based Access Control (RBAC)

```go
type Role string

const (
    RoleAdmin  Role = "admin"
    RoleEditor Role = "editor"
    RoleViewer Role = "viewer"
)

type Permission string

const (
    PermCreate Permission = "create"
    PermRead   Permission = "read"
    PermUpdate Permission = "update"
    PermDelete Permission = "delete"
)

var rolePermissions = map[Role][]Permission{
    RoleAdmin:  {PermCreate, PermRead, PermUpdate, PermDelete},
    RoleEditor: {PermCreate, PermRead, PermUpdate},
    RoleViewer: {PermRead},
}

func HasRolePermission(role Role, perm Permission) bool {
    perms, exists := rolePermissions[role]
    if !exists {
        return false
    }

    for _, p := range perms {
        if p == perm {
            return true
        }
    }
    return false
}
```

## Middleware for Authorization

```go
func RequirePermission(perm Permission) func(http.HandlerFunc) http.HandlerFunc {
    return func(next http.HandlerFunc) http.HandlerFunc {
        return func(w http.ResponseWriter, r *http.Request) {
            // Get user role from session
            role := getUserRole(r)

            // Check permission
            if !HasRolePermission(role, perm) {
                http.Error(w, "Forbidden", http.StatusForbidden)
                return
            }

            next.ServeHTTP(w, r)
        }
    }
}

// Usage
http.HandleFunc("/create", RequirePermission(PermCreate)(handleCreate))
http.HandleFunc("/view", RequirePermission(PermRead)(handleView))
```

## Resource Ownership

```go
func CheckOwnership(userID, resourceID string) (bool, error) {
    ctx := context.Background()

    var ownerID string
    err := db.QueryRowContext(ctx,
        "SELECT owner_id FROM resources WHERE id = ?",
        resourceID,
    ).Scan(&ownerID)

    if err != nil {
        return false, err
    }

    return ownerID == userID, nil
}

func HandleUpdate(w http.ResponseWriter, r *http.Request) {
    userID := getUserID(r)
    resourceID := r.URL.Query().Get("id")

    // Check ownership
    isOwner, err := CheckOwnership(userID, resourceID)
    if err != nil {
        http.Error(w, "Internal error", 500)
        return
    }

    if !isOwner {
        http.Error(w, "Forbidden", http.StatusForbidden)
        return
    }

    // Proceed with update
}
```

## Attribute-Based Access Control (ABAC)

```go
type AccessRequest struct {
    UserID     string
    ResourceID string
    Action     string
    Context    map[string]interface{}
}

func EvaluatePolicy(req AccessRequest) (bool, error) {
    // Get user attributes
    user, err := GetUser(req.UserID)
    if err != nil {
        return false, err
    }

    // Get resource attributes
    resource, err := GetResource(req.ResourceID)
    if err != nil {
        return false, err
    }

    // Evaluate conditions
    switch req.Action {
    case "read":
        // Anyone can read public resources
        if resource.Public {
            return true, nil
        }
        // Owner can read private resources
        return resource.OwnerID == user.ID, nil

    case "update", "delete":
        // Only owner can modify
        return resource.OwnerID == user.ID, nil

    default:
        return false, nil
    }
}
```

## Access Control Lists (ACL)

```go
type ACL struct {
    ResourceID string
    UserID     string
    Permission Permission
}

func CheckACL(userID, resourceID string, perm Permission) (bool, error) {
    ctx := context.Background()

    var exists bool
    err := db.QueryRowContext(ctx,
        `SELECT EXISTS(
            SELECT 1 FROM acl
            WHERE user_id = ? AND resource_id = ? AND permission = ?
        )`,
        userID, resourceID, string(perm),
    ).Scan(&exists)

    return exists, err
}
```

## Default Deny

```go
// Good: deny by default
func AuthorizeAction(userID, action string) bool {
    allowed, err := CheckPermission(userID, action)
    if err != nil {
        // Deny on error
        log.Printf("authorization error: %v", err)
        return false
    }
    return allowed
}

// Bad: allow on error (security risk!)
func BadAuthorizeAction(userID, action string) bool {
    allowed, err := CheckPermission(userID, action)
    if err != nil {
        // DON'T grant access on error!
        return true
    }
    return allowed
}
```

## Server-Side Enforcement Only

```go
// Good: check on server
func HandleAPI(w http.ResponseWriter, r *http.Request) {
    if !CheckPermission(getUserID(r), "api.write") {
        http.Error(w, "Forbidden", 403)
        return
    }
    // Process request
}

// Bad: relying on client-side checks
// Client can bypass JavaScript checks!
```

## Best Practices

1. **Check every request** - never assume
2. **Server-side only** - client checks are UI, not security
3. **Default deny** - fail securely on errors
4. **Least privilege** - grant minimum necessary
5. **Re-verify** - check permissions, don't cache indefinitely
6. **Log denials** - security monitoring
7. **Consistent enforcement** - same rules everywhere
8. **No security by obscurity** - don't rely on hidden URLs
9. **Test thoroughly** - verify access controls work
10. **Audit regularly** - review permissions periodically
