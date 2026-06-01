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

# Read a top-level scalar from a YAML file, stripping quotes, inline comments,
# and surrounding whitespace. Good enough for .custom-gcl.yml's flat keys.
yaml_scalar() {
  local val
  val=$(sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" "$2" || true)
  val=${val%%$'\n'*}                  # first match only
  val=${val%%#*}                      # strip inline comment
  val=${val//\"/}; val=${val//\'/}    # strip quotes
  val=${val#"${val%%[![:space:]]*}"}  # ltrim
  val=${val%"${val##*[![:space:]]}"}  # rtrim
  printf '%s' "$val"
}

# Resolve the golangci-lint binary, preferring a project's custom build.
#
# Projects with custom/private linters use golangci-lint's module plugin system:
# they declare plugins in .custom-gcl.yml and build a dedicated binary
# (golangci-lint custom). The golangci-lint on PATH does not know those linters
# and fails with "unknown linters", which would block every commit. Resolve the
# right binary instead. Override with GOPILOT_GOLANGCI_LINT=/path/to/binary.
resolve_golangci() {
  if [[ -n "${GOPILOT_GOLANGCI_LINT:-}" ]]; then
    printf '%s' "$GOPILOT_GOLANGCI_LINT"
    return 0
  fi

  local root cfg name dest bin
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
  for cfg in "$root/.custom-gcl.yml" "$root/.custom-gcl.yaml"; do
    [[ -f "$cfg" ]] || continue
    name=$(yaml_scalar name "$cfg"); name=${name:-custom-gcl}
    dest=$(yaml_scalar destination "$cfg"); dest=${dest:-.}
    [[ "$dest" == /* ]] && bin="$dest/$name" || bin="$root/$dest/$name"
    if [[ -x "$bin" ]]; then
      printf '%s' "$bin"
      return 0
    fi
    # Config present but binary not built: skip lint rather than run the PATH
    # binary (which would fail on the custom linters). Building it here could
    # blow the hook timeout.
    echo "gopilot: $cfg found but $bin not built; skipping lint (run 'golangci-lint custom')." >&2
    return 1
  done

  command -v golangci-lint &>/dev/null && { printf '%s' golangci-lint; return 0; }
  return 1
}

# Lint check
if golangci=$(resolve_golangci); then
  if ! lint_output=$("$golangci" run --new 2>&1); then
    errors+="golangci-lint failed:\n$lint_output\n\n"
  fi
fi

if [[ -n "$errors" ]]; then
  echo -e "Pre-commit checks failed. Fix before committing:\n\n$errors" >&2
  exit 2
fi
