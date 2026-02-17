# gopilot

[![skillaudit](https://img.shields.io/badge/skillaudit-Clean-22c55e)](https://skillaudit.sh/gonzaloserrano/gopilot)

A Claude Code plugin with production-tested Go patterns covering idiomatic code style, error handling, testing, concurrency, security, generics, iterators, and stdlib patterns up to Go 1.26.

## Quick Start

```bash
# 1. Add the plugin marketplace
/plugin marketplace add git@github.com:gonzaloserrano/gopilot.git

# 2. Install the plugin
/plugin install gopilot

# 3. Enable auto-update (recommended)
# /plugin → Marketplaces tab → gopilot → Enable auto-update

# 4. Use the skill
# Tell Claude: "use the gopilot skill and implement XYZ"
# Or once skill invocation is fixed: /gopilot
```

## Skill Coverage

| Topic | Patterns |
|-------|----------|
| **Design** | Simplicity, pure functions, zero values, guard clauses, small interfaces |
| **Code Style** | gofmt, golangci-lint, naming conventions, package design |
| **Error Handling** | Wrapping, sentinel errors, `errors.Is`/`As`, `errors.Join` |
| **Generics** | Type parameters, constraints, `comparable`, `cmp.Ordered` |
| **Testing** | Table-driven tests, testify, `t.Parallel()`, `t.Cleanup()`, benchmarks |
| **Concurrency** | Channels, mutexes, `errgroup`, `sync.Once`, context cancellation |
| **Iterators** | `iter.Seq`, `slices.Collect`, `maps.Keys`, range over func |
| **Interfaces** | Consumer-side definition, compile-time checks, function types |
| **Patterns** | Options pattern, `cmp.Or`, HTTP best practices, slog |
| **Security** | Input validation, SQL injection, auth, sessions, TLS, CSRF, crypto |
| **Linting** | golangci-lint configuration, recommended linters |

## Go Version Support

Covers features up to **Go 1.26**, including:

- Go 1.26: `errors.AsType[T]()`, `new(expr)`, `t.ArtifactDir()`, `go fix`, goroutine leak profile
- Go 1.25: `testing/synctest`, `wg.Go()`, `http.CrossOriginProtection`
- Go 1.24: `t.Context()`, `t.Chdir()`, `os.OpenRoot()`, `runtime.AddCleanup`, generic type aliases, `b.Loop()`
- Go 1.23: Iterators (`iter.Seq`), `slices.Collect`, `maps.Keys`
- Go 1.22: `cmp.Or`, range over int, loop variable fix
- Go 1.21: `clear()`, `slices`/`maps` packages

## Plugin Management

```bash
# Update to latest version
/plugin update gopilot

# Check current version
/plugin list

# Uninstall
/plugin uninstall gopilot

# Test locally during development
claude --plugin-dir ./
```

## Local Development

```bash
git clone git@github.com:gonzaloserrano/gopilot.git
cd gopilot
claude --plugin-dir .

# Test the skill
# Tell Claude: "use the gopilot skill"
```

## Contributing

Contributions welcome! The skill is defined in `skills/gopilot/SKILL.md` with detailed security topics in `skills/gopilot/reference/`.

### Adding Patterns

1. Fork and clone the repository
2. Edit `skills/gopilot/SKILL.md`
3. Test locally with `claude --plugin-dir .`
4. Submit a PR

### Guidelines

- Keep patterns concise and actionable
- Include code examples where helpful
- Reference Go version for version-specific features
- Prefer stdlib over external dependencies

## References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Skill Authoring Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Effective Go](https://go.dev/doc/effective_go)
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Go Proverbs](https://go-proverbs.github.io/)
- [OWASP Go Secure Coding Practices](https://owasp.org/www-project-go-secure-coding-practices-guide/)
- [Don't just check errors, handle them gracefully](https://dave.cheney.net/2016/04/27/dont-just-check-errors-handle-them-gracefully) - Opaque errors, behavior assertion, handle once
