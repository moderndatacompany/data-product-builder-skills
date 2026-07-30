#!/usr/bin/env bash

# Runs automatically via npm's "prepack" lifecycle hook, right before
# `npm pack` / `npm publish` build the tarball. Prunes dpbs-docs/vulcan-examples
# down to just the allowed engines and strips junk files (READMEs, csv/tsv
# seed data, lockfiles, etc.) so the published package doesn't ship hundreds
# of MB of raw upstream content. This only cleans the working tree used for
# packaging — it does not touch git history, and re-running
# scripts/sync-vulcan-sources.sh afterward will restore the full submodule
# content for local dev/testing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

EXAMPLES_DIR="${REPO_ROOT}/dpbs-docs/vulcan-examples"
ALLOWED_ENGINES=(databricks postgres snowflake spark trino)
PRUNE_NAMES=(
  ".gitignore"
  "README.md"
  "*.md"
  "*.csv"
  "*.tsv"
  "config.yaml"
  "domain-resource.yaml"
  "domain_resource.yaml"
  "usage.yaml"
  "package-lock.json"
  "requirements.txt"
  "limitations.yaml"
  "usecases.yaml"
)

log() {
  printf '%s\n' "$*"
}

if [[ ! -d "${EXAMPLES_DIR}" ]]; then
  log "prepack-clean-examples: ${EXAMPLES_DIR} not found — skipping"
  exit 0
fi

log "prepack-clean-examples: pruning ${EXAMPLES_DIR} before packaging"

for entry_path in "${EXAMPLES_DIR}"/*; do
  [[ -e "${entry_path}" ]] || continue
  entry_name="$(basename "${entry_path}")"

  allowed="false"
  for candidate in "${ALLOWED_ENGINES[@]}"; do
    if [[ "${entry_name}" == "${candidate}" ]]; then
      allowed="true"
      break
    fi
  done

  if [[ "${allowed}" == "false" ]]; then
    log "  removing disallowed entry ${entry_path}"
    rm -rf "${entry_path}"
  fi
done

find_name_args=()
for name in "${PRUNE_NAMES[@]}"; do
  if [[ "${#find_name_args[@]}" -gt 0 ]]; then
    find_name_args+=(-o)
  fi
  find_name_args+=(-name "${name}")
done

while IFS= read -r file_path; do
  log "  removing disallowed file ${file_path}"
  rm -f "${file_path}"
done < <(find "${EXAMPLES_DIR}" -type f \( "${find_name_args[@]}" \))

find "${EXAMPLES_DIR}" -depth -type d -empty -delete

log "prepack-clean-examples: done"
