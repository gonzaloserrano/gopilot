# Agent briefing template

Brief each fan-out lane with this shape. The common preamble is identical across
lanes so aggregation can rely on a stable output contract; the per-lane additions
narrow scope. Append this to the lane's own brief from `agents/` (step 4 of
[SKILL.md](../SKILL.md)).

## Mode-specific header

Pick the header matching the resolved mode:

- **working** — `Review the working-tree (unstaged) changes in the checkout at <abs-path>.`
- **staged** — `Review the staged (index) changes in the checkout at <abs-path>.`
- **commits** — `Review the last <N> commits (HEAD~<N>..HEAD) in the checkout at <abs-path>. SHA: <full-sha>.`
- **branch** — `Review branch <branch> vs <base> in the checkout at <abs-path>. SHA: <full-sha>.`
- **pr** — `Review PR #<N> (<org>/<repo>) on the local checkout at <abs-path>, branch pr-<N>, base <base>. Title: "<title>". SHA: <full-sha>.`

## Common preamble (all modes)

```
## What changed

<2-4 sentences: what the changeset does, the mechanism, and why (or "intent unknown" for working/staged).>

## Files to focus on

- `path/to/file.go` — <one-line purpose>

## Relevant CLAUDE.md rules

<Verbatim quote of the pre-filtered rules from the CLAUDE.md walk, each with its source path,
e.g. "[~/.claude/CLAUDE.md] Wrap with context using low-cardinality strings.">

Citation rule: if a finding cites a CLAUDE.md rule, the citation MUST be a verbatim substring of
one of the rules above, with the source path. Don't paraphrase, summarize, or invent rules. If the
rule isn't in the list, drop the citation (or the finding, if the citation was its only basis).

## Reporting format

Report `file:line` anchors for line-anchored findings. When a concern is cross-cutting (file growth,
architectural drift, a pattern spanning sites) and doesn't anchor cleanly, put it in `general_findings`
instead — a misleading anchor is worse than none.

Coverage, not filtering: this is the finding stage of a multi-stage harness. Report every issue at
confidence ≥ 60 with an honest 0-100 score. Do NOT self-filter at 80 — the orchestrator dedups, boosts
findings two lanes raise independently, applies the ≤3 critical / ≤8 important caps, and drops below 65.
A real bug you withhold at 70 is one a second lane might have corroborated past 80.

Output your prose review first, then end with a fenced ```yaml block:
```

```yaml
findings:                       # line-anchored
  - file: pkg/path/file.go
    line: 42
    lens: silent-failure        # REQUIRED. One of the enum in SKILL.md "Lens identifiers".
    confidence: 85              # 0-100. If you rate severity natively, include it too; the aggregator normalizes.
    summary: One-line description
    issue: |
      One sentence, ≤30 words. WHAT'S WRONG, standalone — no path/line. Cite identifiers in `backticks`.
    impact: |
      One sentence, ≤30 words. WHY IT MATTERS — concrete consequence. Entries missing this are dropped.
    fix: |
      One sentence, OR a ```diff``` block, OR a "Pick one:" list.
    suggested_fix: |            # OPTIONAL. Include only when the fix needs a diff.
      Suggested change: At `file.go:LINE`, <one sentence + diff>.
      Verify: <test command or behavior>

general_findings:               # cross-cutting; no anchor
  - lens: structure
    confidence: 85
    summary: One-line description
    issue: |
      One sentence, ≤30 words. Shape-level concern. Cite identifiers in `backticks`.
    impact: |
      One sentence, ≤30 words.
    fix: |
      One sentence. May reference multiple files or a structural move.
```

Both arrays are always present (`findings: []` / `general_findings: []` when empty). Cap criticals at 2-3 unless the change is genuinely broken.

## Per-lane additions

- **code-reviewer** — add 5-10 "things I want a second eye on" (SQL semantics, loop-variable capture + Go version, removed code paths with hidden invariants, CLAUDE.md compliance).
- **silent-failure-hunter** — name the patterns to scrutinize: `_ = ...` discarded errors, `//nolint:errcheck`, `defer x.Close()` without error handling, tickers/goroutines that log-and-continue, best-effort cleanup paths.
- **pr-test-analyzer** — list the concrete behaviors the diff introduces, force-rank ≤8, point `file` at the expected `_test.go`. End with "critical/important ≤5 items total."
- **comment-analyzer** — enumerate every new doc-comment making a non-trivial claim; ask whether each matches the code. Name them, don't say "audit the comments."
- **structural-quality-reviewer** — up to 5 shape-level questions specific to this change (did file X cross 1000 lines? does the new wrapper earn its keep? did feature logic leak into a shared path?).

## Go rubric chain wrapper (general-purpose subagent)

```
You are the Go-rubric chain for this review. Apply the gopilot Go methodology to the changed Go files
and return findings in the prose-plus-YAML contract above.

Step 1 — load the methodology: invoke the `Skill` tool with `gopilot:gopilot`. Also load
`gopilot:go-error-hygiene`; if the diff touches `*_test.go`, also `gopilot:go-tdd-baby-steps`.
If `Skill` is unavailable, read the sibling SKILL.md files from the plugin install path and apply them.

Step 2 — apply to the changed Go files (checkout at <abs-path>; scope to the diff with
`git diff <range> -- '*.go'`). Focus on changes the diff introduces, not pre-existing patterns.

Step 3 — output prose grouped by severity, then the YAML block. Set `lens: go` on every entry.
Report down to confidence 60; don't self-filter at 80.

If you can resolve neither the Skill tool nor the SKILL.md files, output one general_findings entry:
summary "Could not load gopilot Go rubric; chain skipped", lens go, confidence 100.
```

## Anti-patterns when briefing

- Don't dump the whole diff — point lanes at files.
- Don't ask for confirmation or a summary. Ask for findings.
- Don't ask the same question to two lanes — pick the right one and trust it.
- Don't say "thorough"/"comprehensive". Say "force-rank, cap at N".
- Don't omit the `file:line` request for `findings`, the CLAUDE.md rules section, the YAML requirement, or the `lens` field — each omission silently degrades aggregation.
