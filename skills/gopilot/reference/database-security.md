# Database Security

## SQL Injection Prevention

### The Golden Rule

**NEVER use string concatenation. ALWAYS use prepared statements.**

### Vulnerable Code

```go
// VULNERABLE - DO NOT USE
customerId := r.URL.Query().Get("id")
query := "SELECT number, cvv FROM creditcards WHERE customerId = " + customerId
row, _ := db.QueryContext(ctx, query)

// Attack: customerId = "1 OR 1=1"
// Result: dumps all records!
```

### Safe Code

```go
// SAFE - use prepared statements
ctx := context.Background()
customerId := r.URL.Query().Get("id")
query := "SELECT number, cvv FROM creditcards WHERE customerId = ?"

stmt, err := db.QueryContext(ctx, query, customerId)
if err != nil {
    return fmt.Errorf("query: %w", err)
}
defer stmt.Close()
```

## Placeholder Syntax

Different databases use different placeholder syntax:

| Database | Syntax | Example |
|----------|--------|---------|
| MySQL | `?` | `WHERE col = ?` |
| PostgreSQL | `$1, $2, $3` | `WHERE col = $1` |
| Oracle | `:name` | `WHERE col = :col` |

```go
// MySQL
db.QueryContext(ctx, "SELECT * FROM users WHERE id = ?", userID)

// PostgreSQL
db.QueryContext(ctx, "SELECT * FROM users WHERE id = $1", userID)

// Multiple parameters (PostgreSQL)
db.QueryContext(ctx,
    "SELECT * FROM users WHERE name = $1 AND age = $2",
    name, age)
```

## Prepared Statements

### Method 1: Prepare + Execute

```go
ctx := context.Background()

// Prepare statement
stmt, err := db.PrepareContext(ctx,
    "SELECT name, email FROM users WHERE id = ?")
if err != nil {
    return fmt.Errorf("prepare: %w", err)
}
defer stmt.Close()

// Execute multiple times
for _, id := range userIDs {
    var name, email string
    err = stmt.QueryRowContext(ctx, id).Scan(&name, &email)
    // ...
}
```

### Method 2: Direct Query

```go
// Single execution - also safe
ctx := context.Background()
var name string
err := db.QueryRowContext(ctx,
    "SELECT name FROM users WHERE id = ?",
    userID,
).Scan(&name)
```

## Connection Security

### TLS/SSL Connections

```go
import "database/sql"
import _ "github.com/go-sql-driver/mysql"

// MySQL with TLS
dsn := "user:pass@tcp(host:3306)/db?tls=true"
db, err := sql.Open("mysql", dsn)

// PostgreSQL with TLS
dsn := "host=localhost user=postgres password=secret dbname=mydb sslmode=require"
db, err := sql.Open("postgres", dsn)
```

### Connection Pool Configuration

```go
// Set connection limits
db.SetMaxOpenConns(25)           // Max concurrent connections
db.SetMaxIdleConns(5)            // Max idle connections
db.SetConnMaxLifetime(5 * time.Minute) // Max connection lifetime
db.SetConnMaxIdleTime(10 * time.Minute) // Max idle time
```

## Context with Timeout

Always use context for database operations:

```go
// Create context with timeout
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

// Use with query
rows, err := db.QueryContext(ctx, query, args...)
if err != nil {
    // Handle timeout or other errors
    return fmt.Errorf("query: %w", err)
}
defer rows.Close()
```

## Transactions

### Basic Transaction

```go
ctx := context.Background()

tx, err := db.BeginTx(ctx, nil)
if err != nil {
    return err
}
defer tx.Rollback() // Rollback if not committed

// Execute multiple statements
_, err = tx.ExecContext(ctx, "INSERT INTO users ...", args1...)
if err != nil {
    return err // Rollback via defer
}

_, err = tx.ExecContext(ctx, "INSERT INTO orders ...", args2...)
if err != nil {
    return err // Rollback via defer
}

// Commit transaction
return tx.Commit()
```

### Transaction Isolation Levels

```go
import "database/sql"

// Serializable (strictest)
tx, err := db.BeginTx(ctx, &sql.TxOptions{
    Isolation: sql.LevelSerializable,
})

// Read Committed
tx, err := db.BeginTx(ctx, &sql.TxOptions{
    Isolation: sql.LevelReadCommitted,
})

// Read-only transaction
tx, err := db.BeginTx(ctx, &sql.TxOptions{
    ReadOnly: true,
})
```

## Database Authentication

### Environment Variables

```go
import "os"

func ConnectDB() (*sql.DB, error) {
    // Load credentials from environment
    host := os.Getenv("DB_HOST")
    user := os.Getenv("DB_USER")
    pass := os.Getenv("DB_PASSWORD")
    dbname := os.Getenv("DB_NAME")

    if pass == "" {
        return nil, errors.New("DB_PASSWORD not set")
    }

    dsn := fmt.Sprintf("%s:%s@tcp(%s)/%s", user, pass, host, dbname)
    return sql.Open("mysql", dsn)
}
```

### Least Privilege

- Use application-specific database users
- Grant minimum required permissions
- Never use root/admin accounts
- Separate users for read-only operations

```sql
-- Create limited user
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'password';

-- Grant only necessary permissions
GRANT SELECT, INSERT, UPDATE ON mydb.users TO 'app_user'@'localhost';
GRANT SELECT ON mydb.products TO 'app_user'@'localhost';

-- No DELETE or DROP permissions
```

## Stored Procedures

If using stored procedures, still use parameterized calls:

```go
// Call stored procedure safely
ctx := context.Background()
_, err := db.ExecContext(ctx, "CALL UpdateUser(?, ?)", userID, newName)
```

## Error Handling

```go
// Don't leak database structure in errors
row := db.QueryRowContext(ctx, query, args...)
err := row.Scan(&result)
if err != nil {
    if err == sql.ErrNoRows {
        // Generic message to user
        return errors.New("record not found")
    }
    // Log detailed error server-side
    log.Printf("database error: %v", err)
    // Generic error to user
    return errors.New("database error occurred")
}
```

## Query Result Handling

```go
rows, err := db.QueryContext(ctx, query, args...)
if err != nil {
    return err
}
defer rows.Close() // Always close rows

for rows.Next() {
    var id int
    var name string
    if err := rows.Scan(&id, &name); err != nil {
        return err
    }
    // Process row
}

// Check for errors after iteration
if err := rows.Err(); err != nil {
    return err
}
```

## Best Practices

1. **Always use prepared statements** - no exceptions
2. **Use context with timeout** - prevent hung queries
3. **Configure connection pool** - prevent exhaustion
4. **Use TLS** - encrypt database connections
5. **Least privilege users** - minimize permissions
6. **Close resources** - use defer for stmt, rows, tx
7. **Handle errors properly** - don't leak structure
8. **Validate before and after** - defense in depth
9. **Use transactions** - for multi-step operations
10. **Environment variables** - for credentials
