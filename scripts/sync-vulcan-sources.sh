#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="dry-run"

ALLOWED_ENGINES=(databricks postgres snowflake spark trino)
DATAOS_VULCAN_PATH="documentation/references/resources/vulcan"
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

usage() {
  cat <<'EOF'
Usage: scripts/sync-vulcan-sources.sh [--dry-run|--apply]

Syncs the Vulcan submodules in place under dpbs-docs:
  - dpbs-docs/dataos          (GitHub moderndatacompany/dataos, sparse-checked
                               out to documentation/references/resources/vulcan
                               only)
  - dpbs-docs/vulcan-examples (Bitbucket rubik_/vulcan-examples, cleaned)

Operations:
  1. Initializes/updates both submodules to their pinned commits
  2. Restricts dpbs-docs/dataos's working tree to
     documentation/references/resources/vulcan via sparse-checkout
  3. Removes disallowed root entries from dpbs-docs/vulcan-examples,
     keeping only the allowed engine folders (databricks, postgres,
     snowflake, spark, trino)
  4. Removes disallowed files (README, *.md, *.csv, *.tsv, etc.) from
     dpbs-docs/vulcan-examples
  5. Removes now-empty directories from dpbs-docs/vulcan-examples

Options:
  --dry-run   Show what would change without writing files (default)
  --apply     Apply the sync to the working tree
  -h, --help  Show this help
EOF
}

log() {
  printf '%s\n' "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

DATAOS_DIR="${REPO_ROOT}/dpbs-docs/dataos"
EXAMPLES_DIR="${REPO_ROOT}/dpbs-docs/vulcan-examples"

log "Mode: ${MODE}"

log ""
log "Syncing submodule metadata"
git -C "${REPO_ROOT}" submodule sync --recursive

log ""
log "Updating submodules (dataos, vulcan-examples)"
git -C "${REPO_ROOT}" submodule update --init --recursive -- "${DATAOS_DIR}" "${EXAMPLES_DIR}"

configure_dataos_sparse_checkout() {
  log ""
  if [[ "${MODE}" != "apply" ]]; then
    log "[dry-run] would restrict dpbs-docs/dataos checkout to ${DATAOS_VULCAN_PATH}/*"
    return
  fi

  log "Restricting dpbs-docs/dataos checkout to ${DATAOS_VULCAN_PATH}"
  (
    cd "${DATAOS_DIR}"
    git sparse-checkout init --no-cone
    git_dir="$(git rev-parse --git-dir)"
    printf '/%s/*\n' "${DATAOS_VULCAN_PATH}" > "${git_dir}/info/sparse-checkout"
    git sparse-checkout reapply
  )
}

remove_disallowed_root_entries() {
  local entry_path
  for entry_path in "${EXAMPLES_DIR}"/*; do
    [[ -e "${entry_path}" ]] || continue
    local entry_name
    entry_name="$(basename "${entry_path}")"

    local allowed="false"
    local candidate
    for candidate in "${ALLOWED_ENGINES[@]}"; do
      if [[ "${entry_name}" == "${candidate}" ]]; then
        allowed="true"
        break
      fi
    done

    if [[ "${allowed}" == "false" ]]; then
      log ""
      if [[ "${MODE}" == "apply" ]]; then
        log "Removing disallowed entry ${entry_path}"
        rm -rf "${entry_path}"
      else
        log "[dry-run] remove disallowed entry ${entry_path}"
      fi
    fi
  done
}

remove_disallowed_files() {
  local find_name_args=()
  local name
  for name in "${PRUNE_NAMES[@]}"; do
    if [[ "${#find_name_args[@]}" -gt 0 ]]; then
      find_name_args+=(-o)
    fi
    find_name_args+=(-name "${name}")
  done

  local files_to_remove=()
  while IFS= read -r file_path; do
    files_to_remove+=("${file_path}")
  done < <(find "${EXAMPLES_DIR}" -type f \( "${find_name_args[@]}" \) | sort)

  if [[ "${#files_to_remove[@]}" -gt 0 ]]; then
    log ""
    log "Cleaning disallowed example files from ${EXAMPLES_DIR}"
    local file_path
    for file_path in "${files_to_remove[@]}"; do
      if [[ "${MODE}" == "apply" ]]; then
        rm -f "${file_path}"
      else
        log "[dry-run] remove ${file_path}"
      fi
    done
  fi
}

remove_empty_dirs() {
  if [[ "${MODE}" == "apply" ]]; then
    find "${EXAMPLES_DIR}" -depth -type d -empty -delete
  else
    local empty_dirs=()
    while IFS= read -r dir_path; do
      empty_dirs+=("${dir_path}")
    done < <(find "${EXAMPLES_DIR}" -depth -type d -empty | sort)
    if [[ "${#empty_dirs[@]}" -gt 0 ]]; then
      log ""
      log "Cleaning empty example directories from ${EXAMPLES_DIR}"
      local dir_path
      for dir_path in "${empty_dirs[@]}"; do
        log "[dry-run] remove empty dir ${dir_path}"
      done
    fi
  fi
}

configure_dataos_sparse_checkout
remove_disallowed_root_entries
remove_disallowed_files
remove_empty_dirs

log ""
log "Done."
