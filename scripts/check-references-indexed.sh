#!/usr/bin/env bash
# Fail when a skill ships a reference/ file that its SKILL.md doesn't mention.
# A new reference that lands without a SKILL.md entry is invisible to agents.

set -euo pipefail

SKILLS_DIR="${SKILLS_DIR:-skills}"

failed=0
missing=()

for dir in "${SKILLS_DIR}"/*/; do
  ref_dir="${dir}reference"
  [[ -d "${ref_dir}" ]] || continue

  skill_md="${dir}SKILL.md"
  [[ -f "${skill_md}" ]] || continue

  while IFS= read -r -d '' ref_file; do
    base=$(basename "${ref_file}")
    if ! grep -qF "reference/${base}" "${skill_md}"; then
      missing+=("${dir%/}: reference/${base}")
      failed=1
    fi
  done < <(find "${ref_dir}" -maxdepth 1 -type f -print0)
done

if ((failed)); then
  printf 'Reference files not indexed in SKILL.md:\n'
  printf '  - %s\n' "${missing[@]}"
  exit 1
fi

echo "All reference files are indexed in their SKILL.md"
