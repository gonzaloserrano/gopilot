#!/bin/bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only process .go files
if [[ -z "$file_path" || ! "$file_path" =~ \.go$ ]]; then
  exit 0
fi

# Skip if file doesn't exist
if [[ ! -f "$file_path" ]]; then
  exit 0
fi

# Auto-format
if command -v gofmt &>/dev/null; then
  if ! gofmt -w "$file_path" 2>/tmp/gofmt-err; then
    echo "gofmt failed on $file_path:" >&2
    cat /tmp/gofmt-err >&2
    exit 2
  fi
fi
