#!/bin/bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only intercept git commit commands
if [[ ! "$command" =~ ^git\ commit ]]; then
  exit 0
fi

# Respect --no-verify (same semantics as git's own hook skip)
if [[ "$command" =~ --no-verify ]]; then
  exit 0
fi

# Skip if not a Go project (search up to git root)
find_go_mod() {
  local dir="$PWD"
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  while [[ "$dir" == "$root"* ]]; do
    [[ -f "$dir/go.mod" ]] && return 0
    [[ "$dir" == "$root" ]] && return 1
    dir=$(dirname "$dir")
  done
  return 1
}
if ! find_go_mod; then
  exit 0
fi

errors=""

# Build check
if ! build_output=$(go build ./... 2>&1); then
  errors+="go build failed:\n$build_output\n\n"
fi

# Test compilation check (compiles _test.go files without running tests)
if ! test_build_output=$(go test -exec true ./... 2>&1); then
  errors+="go test compilation failed:\n$test_build_output\n\n"
fi

# Lint check
if command -v golangci-lint &>/dev/null; then
  if ! lint_output=$(golangci-lint run --new 2>&1); then
    errors+="golangci-lint failed:\n$lint_output\n\n"
  fi
fi

if [[ -n "$errors" ]]; then
  echo -e "Pre-commit checks failed. Fix before committing:\n\n$errors" >&2
  exit 2
fi
