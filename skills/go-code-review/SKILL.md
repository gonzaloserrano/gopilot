---
name: go-code-review
description: "Multi-lane Go code review. Fans out parallel reviewer lanes (correctness, silent failures, test gaps, comment drift, structural quality) plus a Go-rubric chain that loads the gopilot skills, then reduces every lane's output into one flat, severity-tagged finding list with collapsed fix blocks. Reviews local changes (working tree, staged, last N commits, branch vs main) or a GitHub PR (rendered to the conversation, never posted). Use when explicitly asked for a full or multi-lane code review of Go changes or a Go PR; does NOT auto-fire on generic 'review this' intents."
license: MIT
---

# go-code-review

A map/reduce code reviewer for Go changes. The expensive work (reading the diff)
**fans out** across parallel reviewer lanes plus a Go-rubric chain; everything
that needs the whole finding pool in one place (dedup, tiering, render) runs
**serially** in the orchestrator.

It is the multi-lane counterpart to the [`gopilot`](../gopilot/SKILL.md)
knowledge skill: the lanes carry the review *methodology*; the Go *rules* come
from loading `gopilot` (and its siblings) into the chain. Adopted from the
fan-out/reduce shape of the Connectors team's `td-code-review`, trimmed to a
Go-only, render-only v1 (no GitHub posting, no prior-discussion tracking).

## When to use

- User explicitly asks for a full / multi-lane / "thorough" code review of Go changes or a Go PR.
- Do NOT auto-fire on generic "review this" intents — a quick single-file look doesn't need the fan-out.

## Reference files

- [`reference/agent-briefing.md`](reference/agent-briefing.md) — the per-run brief template appended to every lane prompt, plus the shared output contract.
- [`reference/agents/code-reviewer.md`](reference/agents/code-reviewer.md) — correctness, concurrency, security, CLAUDE.md compliance.
- [`reference/agents/silent-failure-hunter.md`](reference/agents/silent-failure-hunter.md) — swallowed errors, masking fallbacks.
- [`reference/agents/pr-test-analyzer.md`](reference/agents/pr-test-analyzer.md) — behavioral test-coverage gaps.
- [`reference/agents/comment-analyzer.md`](reference/agents/comment-analyzer.md) — comment-vs-code drift.
- [`reference/agents/structural-quality-reviewer.md`](reference/agents/structural-quality-reviewer.md) — missed simplifications, file growth, duplication, layer leaks.

## Modes

| Mode | Source of changes | Output |
|---|---|---|
| `working` | `git diff` (unstaged) | rendered to conversation |
| `staged` | `git diff --cached` | rendered to conversation |
| `commits` | `git diff HEAD~N..HEAD` | rendered to conversation |
| `branch` | `git diff $(git merge-base main HEAD)..HEAD` | rendered to conversation |
| `pr` | GitHub PR (URL or number) | rendered to conversation (never posted) |
| `dir` | `cd <path>`, then re-ask for source | rendered to conversation |

This skill never posts to GitHub. In `pr` mode it fetches and renders; the user copies what they want.

## Procedure

### 0. Resolve input mode

Parse the user's arg (first match wins):

| Arg looks like… | Mode |
|---|---|
| empty / `working` / `unstaged` / `wip` | `working` |
| `staged` / `cached` / `index` | `staged` |
| `HEAD~N` / `last N commits` / `last commit` | `commits` (N = parsed int, default 1) |
| `branch` / `vs main` / `current branch` | `branch` |
| `https://github.com/.../pull/<N>` URL, or a plain integer | `pr` |
| an existing directory path | `dir` (cd, then re-ask) |

If no arg is given, ask once with AskUserQuestion (offer Working tree / Staged / Branch vs main / GitHub PR; "Other" carries the rest).

**Resolution per mode:**

- **local modes** (`working`, `staged`, `commits`, `branch`): verify `pwd` is in a git repo (`git rev-parse --show-toplevel`). Get `changed_files` (`git diff --name-only <range>`) and `diff_text` (`git diff <range>`). For `commits`/`branch`, capture `git rev-parse HEAD` as `sha`. If the file list is empty, report "No changes to review." and stop.
- **`pr`**: `gh pr view <ref> --json title,body,files,additions,deletions,baseRefName,headRefName,number`; find/identify the local checkout; `git fetch origin pull/<N>/head:pr-<N> && git checkout pr-<N>`; capture `sha = git rev-parse HEAD`. Warn the user that the checkout switched branches.
- **`dir`**: `cd <path>`, then re-ask for the source within that directory.

Capture `mode`, `changed_files`, `diff_text`, `sha` (if available), `go_files = changed_files matching *.go / go.mod / go.sum`.

### 1. CLAUDE.md walk

Read the CLAUDE.md hierarchy as ground truth: `~/.claude/CLAUDE.md`, repo-root CLAUDE.md, and any CLAUDE.md in directories containing changed files. Pre-filter to review-relevant sections (style, tests, error handling, scope, language rules); skip unrelated guidance. The lanes cite these rules **verbatim** — paraphrased citations are dropped.

### 2. Quick context

Skim the 2-3 loudest changed files yourself. Map the changeset before dispatching.

### 3. Cost gate

Compute `loc` (sum of `+`/`-` lines, e.g. `git diff <range> --numstat | awk '{s+=$1+$2} END {print s}'`), `files = len(changed_files)`, and `sensitive = any changed path contains` one of: `auth`, `authn`, `authz`, `crypto`, `secret`, `token`, `session`, `credential`, `password`, `signing`, `security/`, `migrations/`, `*.pem`, `*.key`, `Dockerfile`.

- If `loc < 200 AND files <= 3 AND not sensitive`: **single-pass** — skip the lane fan-out; apply all five lane rubrics (`reference/agents/*`) yourself in-process. The Go chain (step 5) still fires.
- Else: **fan-out** (steps 4-5).

**Announce the decision** in one line, e.g. `Cost gate: fan-out (480 loc, 7 files); 5 lanes + Go chain.` There is no override flag; edit the constants here to change it.

### 4. Fan-out (parallel)

Dispatch the five lanes as `general-purpose` agents **in parallel** (single message, multiple Agent calls). Each lane's prompt is its inlined brief from `reference/agents/` PLUS the per-run brief from [`reference/agent-briefing.md`](reference/agent-briefing.md) (what changed, focus files, the parsed CLAUDE.md rules, and the YAML output contract).

| Lane | Brief | Focus |
|---|---|---|
| code-reviewer | `reference/agents/code-reviewer.md` | correctness, concurrency, security, CLAUDE.md compliance |
| silent-failure-hunter | `reference/agents/silent-failure-hunter.md` | swallowed errors, masking fallbacks |
| pr-test-analyzer | `reference/agents/pr-test-analyzer.md` | behavioral coverage gaps |
| comment-analyzer | `reference/agents/comment-analyzer.md` | comment-vs-code drift |
| structural-quality-reviewer | `reference/agents/structural-quality-reviewer.md` | missed simplifications, file growth, duplication, layer leaks |

The Boundary table in each brief is the primary anti-overlap mechanism; step 7's dedup is the safety net. Lanes report candidates down to confidence 60 ("coverage, not filtering"); the cutoff and caps live downstream in steps 7-8.

### 5. Go rubric chain (parallel with 4; also fired on single-pass)

This is what makes the review Go-aware. Dispatch one `general-purpose` agent (in parallel with the lanes) that loads the repo's own Go knowledge and applies it to the changed Go files. Fire it whenever `go_files` is non-empty.

The agent's brief instructs it to:

1. Invoke the `Skill` tool with `gopilot:gopilot` to load the Go methodology into its own context. Also load `gopilot:go-error-hygiene` (error-handling antipatterns) and, when the diff touches `*_test.go`, `gopilot:go-tdd-baby-steps`.
2. Apply that methodology to the `go_files` (scope to the diff: `git diff <range> -- '*.go'`).
3. Return findings in the same prose-plus-YAML contract as the lanes, with `lens: go`.

If the `Skill` tool is unavailable to the subagent, instruct it to read the sibling SKILL.md files directly from the plugin install path before falling back. If it can resolve neither, it must emit one `general_findings` entry (`summary: "Could not load gopilot Go rubric; chain skipped"`, `lens: go`, confidence 100) so the gap renders visibly rather than vanishing.

Treat the chain's findings as one more lane: they merge into the pool at step 6.

### 6. Aggregate

Parse each agent's YAML block (two arrays: `findings` line-anchored, `general_findings` cross-cutting). If YAML is missing/malformed, fall back to prose-regex extraction and log a warning. Drop any entry missing `lens`, `issue`, or `impact`.

Normalize native scores to 0-100:

| Lane | Native | Normalized |
|---|---|---|
| silent-failure-hunter | CRITICAL / HIGH / MEDIUM | 95 / 82 / 68 |
| pr-test-analyzer | 1-10 rating | rating × 10 |
| comment-analyzer | Critical Issue / Stale Comment | 90 / 70 |

`code-reviewer`, `structural-quality-reviewer`, and the Go chain already score 0-100.

### 7. Dedup + co-flag boost

Merge line-anchored `findings` on `(file, line ± 3)`. For each merged finding:

```
contributing = [s for s in scores if s >= 60]
aggregate = min(100, max(scores) + 5 * (len(contributing) - 1))
```

Only scores ≥ 60 contribute to the boost. The surviving finding carries the **lens of its highest-confidence contributor** (on a tie, prefer the lane whose Boundary table claims it).

Merge `general_findings` on `(lens, summary keyword overlap ≥ 2)` with the same formula. A general finding never merges with a line-anchored one — they describe different scopes.

### 8. Score → severity tier

| Score | Emoji | Tier | Meaning |
|---|---|---|---|
| 90-100 | 🔴 | critical | correctness bug that will surface in production, or a stated-design violation |
| 80-89 | 🟡 | important | silent regression, masked failure, real waste |
| 65-79 | 🔵 | test | missing coverage of a real regression path |
| 65-79 | ⚪ | nit | cleanup, comment drift, style |
| < 65 | — | drop | — |

The emoji is the sole rendered severity signal — use the actual characters (🔴 🟡 🔵 ⚪), not `:shortcodes:`. **Caps: ≤3 critical, ≤8 important.** If a tier exceeds its cap, raise that tier's threshold until it fits (re-score; don't truncate). Tests and nits are uncapped. Caps span both pools.

### 9. Render

Flat numbered list, severity order (🔴 → 🟡 → 🔵 → ⚪). Within a tier, line-anchored findings first (file order), then general findings (lens order). No section headers, no tier headings — the emoji is the priority signal. Numbering is continuous across tiers. Render to the conversation; never post.

Per finding (line-anchored):

````markdown
**N. 🔴 Five-word summary** (`pkg/applier/applier.go:712`) [_silent-failure_]

<One fused sentence, ≤45 words: issue (what's wrong, root cause), then impact (concrete consequence), joined by a causal connective. Cite identifiers in `backticks`. If the finding IS a CLAUDE.md violation, quote the rule verbatim with its source path.>

<details>
<summary>Fix</summary>

<One-sentence fix summary.>

```diff
- old line
+ new line
```

</details>

<br>
````

General (unanchored) finding: same shape, but replace the location with `_(general)_` and drop the diff block (the one-sentence fix may reference multiple files).

When a SHA is available (`pr`, `commits`, `branch` modes) and the repo has a GitHub remote, render the location as a markdown permalink `[applier/applier.go#L712](https://github.com/<org>/<repo>/blob/<sha>/pkg/applier/applier.go#L712)` instead of the plain `file:line`.

**Nit collapsing.** Wrap all nits in a single trailing `<details>` whose summary shows the count and a one-line theme list. Omit the block entirely if there are no nits. Emit a `<br>` after each finding's closing `</details>` (not after the last).

If no findings clear the cutoff, say so in one line: `No findings above cutoff.`

## Agent output contract

The authoritative contract lives in [`reference/agent-briefing.md`](reference/agent-briefing.md). In short, each agent ends with a fenced ```yaml block carrying two arrays — `findings` (require `file`, `line`, `lens`, `confidence`, `summary`, `issue`, `impact`, `fix`; optional `suggested_fix`) and `general_findings` (same minus `file`/`line`). Both arrays are always present (`[]` when empty).

## Lens identifiers

`code-review`, `silent-failure`, `test-coverage`, `comments`, `structure`, `go`. The lens renders as a trailing `[_<lens>_]` marker and is set by each lane on every entry it emits.

## Anti-patterns

- Don't dump the whole diff into a lane brief — point agents at files; they have read tools.
- Don't ask lanes for a summary or "what's good" recap — findings only.
- Don't post to GitHub. This skill is render-only.
- Don't skip the Go chain when Go files changed — it's where the Go-specific rules come from.
- Don't widen the rendered output by lowering the step-8 cutoff; widen finding-stage coverage instead and let dedup + caps do the ranking.
