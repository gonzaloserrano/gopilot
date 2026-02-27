# Google AIP (API Improvement Proposals) in Go

Guidelines for building resource-oriented gRPC APIs following [Google AIP](https://google.aip.dev/) standards using [einride/aip-go](https://github.com/einride/aip-go).

## Resource-Oriented Design (AIP-121)

Design APIs around resources (nouns), not actions (verbs):

1. **Define resources** — the entities your API exposes
2. **Map relationships** — parent/child hierarchies between resources
3. **Establish schemas** — fields each resource contains
4. **Choose methods** — prefer standard methods (Get, List, Create, Update, Delete)

Decouple your API surface from database schema. Resources represent the API contract, not storage layout.

## Resource Names (AIP-122)

Resource names are hierarchical paths alternating between collection identifiers and resource IDs:

```
publishers/123/books/les-miserables
projects/my-project/zones/us-central1-a/instances/my-instance
```

### Rules

- Collection identifiers: plural `camelCase` nouns starting lowercase
- Resource IDs: prefer lowercase alphanumeric + hyphen, max 63 chars (RFC-1034)
- Every resource exposes a `name` field (string) containing its resource name
- Reference other resources by name, never by embedding the full message

### aip-go: resourcename package

```go
import "go.einride.tech/aip/resourcename"

// Validate a resource name
err := resourcename.Validate("publishers/123/books/les-miserables")

// Parse segments from a name using a pattern
var publisher, book string
err := resourcename.Sscan(
    "publishers/123/books/les-miserables",
    "publishers/{publisher}/books/{book}",
    &publisher, &book,
)
// publisher = "123", book = "les-miserables"

// Construct a resource name from a pattern
name := resourcename.Sprint(
    "publishers/{publisher}/books/{book}",
    "123", "les-miserables",
)
// "publishers/123/books/les-miserables"

// Check if a name matches a pattern
if resourcename.Match("publishers/{publisher}/books/{book}", name) {
    // handle match
}

// Check parent relationship
if resourcename.HasParent(name, "publishers/123") {
    // name is under publisher 123
}

// Scan segments one by one
var scanner resourcename.Scanner
scanner.Init(name)
for scanner.Scan() {
    seg := scanner.Segment()
    fmt.Println(seg.Literal().ResourceID())
}
```

## Standard Methods (AIP-130 through AIP-135)

Every resource should support at minimum Get and List.

| Method | HTTP | Request → Response | AIP |
|--------|------|-------------------|-----|
| Get | `GET /v1/{name=publishers/*/books/*}` | `GetBookRequest` → `Book` | 131 |
| List | `GET /v1/{parent=publishers/*}/books` | `ListBooksRequest` → `ListBooksResponse` | 132 |
| Create | `POST /v1/{parent=publishers/*}/books` | `CreateBookRequest` → `Book` | 133 |
| Update | `PATCH /v1/{book.name=publishers/*/books/*}` | `UpdateBookRequest` → `Book` | 134 |
| Delete | `DELETE /v1/{name=publishers/*/books/*}` | `DeleteBookRequest` → `Empty` | 135 |

### Get (AIP-131)

- Request has a single `name` field (required)
- Response is the resource itself (no wrapper)

### List (AIP-132)

- Request: `parent` (required), `page_size`, `page_token`, optional `filter`, `order_by`, `show_deleted`
- Response: repeated resources + `next_page_token`
- No extra required fields in the request

### Create (AIP-133)

- Request: `parent`, resource object, optional `{resource}_id` for user-specified IDs
- Response is the created resource
- Return `ALREADY_EXISTS` on duplicate IDs

### Update (AIP-134)

- Use `PATCH`, not `PUT` — partial updates are backwards-compatible
- Request: resource object + optional `update_mask` (field mask)
- Without mask: update all non-empty fields
- With `*` mask: full replacement
- Optional `allow_missing` for upsert (create-or-update)
- Optional `etag` to prevent concurrent modification (fail with `ABORTED`)

### Delete (AIP-135)

- Request: `name` field (required)
- Response: `google.protobuf.Empty` for hard delete, or the resource for soft delete
- Use `bool force` for cascading deletes (fail with `FAILED_PRECONDITION` if children exist and force is false)
- Optional `allow_missing` to treat missing resources as no-ops

## Pagination (AIP-158)

Implement pagination from the start — adding it later is a breaking change.

### Rules

- `page_token`: opaque, URL-safe string; not user-parseable
- `page_size`: never required; `0` means server-chosen default
- Negative `page_size`: return `INVALID_ARGUMENT`
- Values exceeding max: silently coerce down
- Empty `next_page_token`: signals last page
- Tokens may expire after ~3 days without documentation

### aip-go: pagination package

```go
import (
    "go.einride.tech/aip/pagination"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

func (s *Server) ListBooks(
    ctx context.Context,
    req *library.ListBooksRequest,
) (*library.ListBooksResponse, error) {
    const (
        maxPageSize     = 1000
        defaultPageSize = 100
    )
    switch {
    case req.PageSize < 0:
        return nil, status.Errorf(codes.InvalidArgument, "page size is negative")
    case req.PageSize == 0:
        req.PageSize = defaultPageSize
    case req.PageSize > maxPageSize:
        req.PageSize = maxPageSize
    }

    pageToken, err := pagination.ParsePageToken(req)
    if err != nil {
        return nil, status.Errorf(codes.InvalidArgument, "invalid page token")
    }

    result, err := s.store.ListBooks(ctx, pageToken.Offset, req.GetPageSize())
    if err != nil {
        return nil, err
    }

    resp := &library.ListBooksResponse{Books: result.Books}
    if result.HasNextPage {
        resp.NextPageToken = pageToken.Next(req).String()
    }
    return resp, nil
}
```

## Filtering (AIP-160)

### Syntax

```
filter = 'status = "active"'
filter = 'price > 100 AND category = "books"'
filter = 'NOT archived'
filter = 'name = "projects/*/locations/*"'       // wildcards in strings
filter = 'tags:"urgent"'                          // has operator for repeated fields
filter = 'create_time > timestamp("2024-01-01T00:00:00Z")'
filter = 'address.city = "Berlin"'                // traversal with dot
```

Operators: `=`, `!=`, `<`, `>`, `<=`, `>=`, `:` (has), `AND`, `OR`, `NOT`/`-`

### aip-go: filtering package

```go
import "go.einride.tech/aip/filtering"

// Declare the filterable schema
decls, err := filtering.NewDeclarations(
    filtering.DeclareStandardFunctions(),
    filtering.DeclareIdent("status", filtering.TypeString),
    filtering.DeclareIdent("priority", filtering.TypeInt),
    filtering.DeclareIdent("create_time", filtering.TypeTimestamp),
    filtering.DeclareIdent("tags", filtering.TypeList(filtering.TypeString)),
)
if err != nil {
    return err
}

// Parse and type-check a filter from a request
filter, err := filtering.ParseFilter(req, decls)
if err != nil {
    return status.Errorf(codes.InvalidArgument, "invalid filter: %v", err)
}

// Or parse a raw filter string
filter, err := filtering.ParseFilterString(`status = "active"`, decls)

// Walk the checked expression tree
filtering.Walk(func(curr, parent *expr.Expr) bool {
    // process expression nodes
    return true
}, filter.CheckedExpr.GetExpr())
```

### Declaring identifiers from proto message fields

```go
// Declare identifiers matching your proto message fields
decls, err := filtering.NewDeclarations(
    filtering.DeclareStandardFunctions(),
    filtering.DeclareIdent("name", filtering.TypeString),
    filtering.DeclareIdent("status", filtering.TypeEnum(pb.Status(0).Type())),
    filtering.DeclareIdent("create_time", filtering.TypeTimestamp),
    filtering.DeclareIdent("labels", filtering.TypeMap(filtering.TypeString, filtering.TypeString)),
)
```

## Ordering (AIP-132)

Format: comma-separated fields, optional `desc` suffix.

```
order_by = "create_time desc"
order_by = "priority, create_time desc"
order_by = "address.city"
```

### aip-go: ordering package

```go
import "go.einride.tech/aip/ordering"

orderBy, err := ordering.ParseOrderBy(req)
if err != nil {
    return status.Errorf(codes.InvalidArgument, "invalid order_by: %v", err)
}

// Validate against allowed fields
if err := orderBy.ValidateForPaths("name", "create_time", "priority"); err != nil {
    return status.Errorf(codes.InvalidArgument, "invalid order_by field: %v", err)
}

// Use parsed fields
for _, field := range orderBy.Fields {
    column := field.Path // already dot-separated string
    if field.Desc {
        // ORDER BY column DESC
    }
}
```

## Field Masks (AIP-134, AIP-161)

Field masks specify which fields to update in partial updates, or which fields to return in partial responses.

### aip-go: fieldmask package

```go
import "go.einride.tech/aip/fieldmask"

// Validate mask paths against the message type
if err := fieldmask.Validate(req.GetUpdateMask(), req.GetBook()); err != nil {
    return status.Errorf(codes.InvalidArgument, "invalid field mask: %v", err)
}

// Check for full replacement (wildcard *)
if fieldmask.IsFullReplacement(req.GetUpdateMask()) {
    // Replace entire resource
    return s.store.ReplaceBook(ctx, req.GetBook())
}

// Apply partial update: copy masked fields from src to dst
existing, err := s.store.GetBook(ctx, req.GetBook().GetName())
if err != nil {
    return nil, err
}
fieldmask.Update(req.GetUpdateMask(), existing, req.GetBook())
return s.store.SaveBook(ctx, existing)
```

## Field Behavior (AIP-203)

Annotate every request field with at least one of:

| Annotation | Meaning |
|-----------|---------|
| `REQUIRED` | Must be non-empty; missing → `INVALID_ARGUMENT` |
| `OPTIONAL` | Not mandatory |
| `OUTPUT_ONLY` | Server-only; ignored in requests and update masks |
| `INPUT_ONLY` | Request-only; omitted from responses (rare) |
| `IMMUTABLE` | Cannot change after creation; ignore if unchanged, error if changed |
| `IDENTIFIER` | For the `name` field; output-only at creation, immutable afterward |

```protobuf
message Book {
  string name = 1 [(google.api.field_behavior) = IDENTIFIER];
  string title = 2 [(google.api.field_behavior) = REQUIRED];
  string author = 3 [(google.api.field_behavior) = REQUIRED];
  string isbn = 4 [(google.api.field_behavior) = IMMUTABLE];
  google.protobuf.Timestamp create_time = 5 [(google.api.field_behavior) = OUTPUT_ONLY];
}
```

### aip-go: fieldbehavior package

Use `fieldbehavior` to validate field behavior annotations at runtime.

## Setup

### Install the library

```bash
go get -u go.einride.tech/aip
```

### Code generation with protoc-gen-go-aip

```bash
go install go.einride.tech/aip/cmd/protoc-gen-go-aip
```

```yaml
# buf.gen.yaml
version: v2
plugins:
  - local: protoc-gen-go-aip
    out: gen
    opt:
      - paths=source_relative
```

## Best Practices

- **Design resources first** — identify nouns before verbs
- **Use standard methods** — Get, List, Create, Update, Delete cover most cases; add custom methods only when needed
- **Implement pagination from day one** — retrofitting breaks clients
- **Add filtering and ordering only with demonstrated need** — removing them later is a breaking change
- **Use field masks for updates** — `PATCH` with masks is safer than `PUT`
- **Keep page tokens opaque** — encode offset + checksum, never expose internals
- **Validate filter expressions server-side** — return `INVALID_ARGUMENT` for invalid filters
- **Validate ordering fields** — only allow ordering on indexed/efficient fields
- **Annotate field behavior** — every field needs `REQUIRED`, `OPTIONAL`, or `OUTPUT_ONLY` at minimum
- **Use ETags for concurrency** — prevent lost updates in Update and Delete
- **Return the resource from mutations** — Create and Update return the resource; clients shouldn't need a follow-up Get
- **Follow resource name conventions** — plural collections, lowercase hyphenated IDs, hierarchical paths
