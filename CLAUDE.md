# Development Guidelines

## Project Structure

This is a Claude Code skill plugin (not a Go application). Content lives in markdown files:

- `skills/gopilot/SKILL.md` — main skill content
- `skills/gopilot/reference/*.md` — detailed reference docs (security, AIP, etc.)
- `skills/go-tdd-baby-steps/SKILL.md` — TDD skill

## Workflow

### Adding or updating skill content

1. Edit the relevant markdown files in `skills/`
2. If adding a new reference doc, link it from `SKILL.md`
3. Update the coverage table in `README.md` to reflect new topics
4. Run `make check` to validate skill format
5. Run `make bump` to increment the patch version
6. Commit and push

### Validation

```bash
make check    # Runs npx skill-check . to validate skill format
```

Always run `make check` before pushing. CI runs the same check on PRs to main.

### Versioning

```bash
make bump     # Increments patch version in plugin.json and marketplace.json
```

Always bump after content changes. Version is tracked in:
- `.claude-plugin/plugin.json` (`.version`)
- `.claude-plugin/marketplace.json` (`.metadata.version` and `.plugins[0].version`)

### Commit conventions

Follow existing style: imperative mood, short summary line.

```
Add go-aip guidelines for resource-oriented gRPC APIs
Fix ordering field.Path type in go-aip reference
Bump version to 1.0.17
```

## Skill content guidelines

- **SKILL.md body must stay under 500 lines** (skill-check enforces this). The body is everything after the YAML frontmatter. If adding content would exceed the limit, extract detailed material into a `reference/*.md` file and link it from SKILL.md with a concise summary.
- Keep patterns concise and actionable — this is a reference, not a tutorial
- Include code examples where they clarify usage
- Reference Go version for version-specific features (e.g., "Go 1.24+")
- Prefer stdlib over external dependencies
- When referencing aip-go or other libraries, verify function signatures exist in the actual package
