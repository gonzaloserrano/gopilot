# Iterators (Go 1.22+)

## Range Over Integers (Go 1.22+)
```go
for i := range 10 {
    fmt.Println(i)  // 0..9
}
```

## Range Over Functions (Go 1.23+)
```go
// String iterators
for line := range strings.Lines(s) { }
for part := range strings.SplitSeq(s, sep) { }
for field := range strings.FieldsSeq(s) { }

// Slice iterators
for i, v := range slices.All(items) { }
for v := range slices.Values(items) { }
for v := range slices.Backward(items) { }
for chunk := range slices.Chunk(items, 3) { }

// Map iterators
for k, v := range maps.All(m) { }
for k := range maps.Keys(m) { }
for v := range maps.Values(m) { }

// Collect iterator to slice
keys := slices.Collect(maps.Keys(m))
sorted := slices.Sorted(maps.Keys(m))

// Custom iterator
func (s *Set[T]) All() iter.Seq[T] {
    return func(yield func(T) bool) {
        for v := range s.items {
            if !yield(v) {
                return
            }
        }
    }
}
```
