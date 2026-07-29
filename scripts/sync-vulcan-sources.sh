#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="dry-run"
WORK_ROOT="${TMPDIR:-/tmp}/vulcan-sync"
UPSTREAM_ROOT_DIR="${UPSTREAM_ROOT_DIR:-${REPO_ROOT}/dpbs-docs/upstream}"

ALLOWED_ENGINES=(databricks postgres snowflake spark trino)
PRESERVE_LOCAL_EXCLUDES=(--exclude="limitations.yaml" --exclude="usecases.yaml")
UPSTREAM_PRUNE_EXCLUDES=(
  --exclude=".gitignore"
  --exclude="README.md"
  --exclude="*.md"
  --exclude="*.csv"
  --exclude="*.tsv"
  --exclude="config.yaml"
  --exclude="domain-resource.yaml"
  --exclude="domain_resource.yaml"
  --exclude="usage.yaml"
  --exclude="package-lock.json"
  --exclude="requirements.txt"
)

usage() {
  cat <<'EOF'
Usage: scripts/sync-vulcan-sources.sh [--dry-run|--apply] [--work-root PATH]

Syncs upstream Vulcan sources into this repository from git submodules.

Operations:
  1. Initializes upstream git submodules under dpbs-docs/upstream
  2. Syncs submodule metadata to the configured paths
  3. Mirrors allowed engines into dpbs-docs/vulcan-examples
  4. Removes unwanted example content automatically
  5. Applies mapped vulcan-book updates via scripts/sync-vulcan-book.mjs

Options:
  --dry-run            Show what would change without writing files (default)
  --apply              Apply the sync to the working tree
  --work-root PATH     Override temp workspace root
  --upstream-root-dir PATH
                      Override the submodule root directory
  -h, --help           Show this help
EOF
}

log() {
  printf '%s\n' "$*"
}

sync_examples() {
  local upstream_dir="$1"
  local target_dir="$2"

  mkdir -p "${target_dir}"

  local rsync_args=(
    -a
    --delete
    --itemize-changes
    "${PRESERVE_LOCAL_EXCLUDES[@]}"
  )

  if [[ "${MODE}" == "dry-run" ]]; then
    rsync_args+=(-n)
  fi

  log ""
  log "Syncing dpbs-docs/vulcan-examples from ${upstream_dir}"
  rsync "${rsync_args[@]}" "${upstream_dir}/" "${target_dir}/"
}

cleanup_examples_target() {
  local target_dir="$1"
  local files_to_remove=()
  local empty_dirs=()

  local find_args=(
    "${target_dir}"
    -type f
    \( -name ".gitignore"
       -o -name "README.md"
       -o -name "*.md"
       -o -name "*.csv"
       -o -name "*.tsv"
       -o -name "config.yaml"
       -o -name "domain-resource.yaml"
       -o -name "domain_resource.yaml"
       -o -name "usage.yaml"
       -o -name "package-lock.json"
       -o -name "requirements.txt"
    \)
  )

  while IFS= read -r file_path; do
    files_to_remove+=("${file_path}")
  done < <(find "${find_args[@]}" | sort)

  if [[ "${#files_to_remove[@]}" -gt 0 ]]; then
    log ""
    log "Cleaning disallowed example files from ${target_dir}"
    for file_path in "${files_to_remove[@]}"; do
      if [[ "${MODE}" == "apply" ]]; then
        rm -f "${file_path}"
      else
        log "[dry-run] remove ${file_path}"
      fi
    done
  fi

  if [[ "${MODE}" == "apply" ]]; then
    find "${target_dir}" -depth -type d -empty -delete
  else
    while IFS= read -r dir_path; do
      empty_dirs+=("${dir_path}")
    done < <(find "${target_dir}" -depth -type d -empty | sort)
    if [[ "${#empty_dirs[@]}" -gt 0 ]]; then
      log ""
      log "Cleaning empty example directories from ${target_dir}"
      for dir_path in "${empty_dirs[@]}"; do
        log "[dry-run] remove empty dir ${dir_path}"
      done
    fi
  fi
}

ensure_submodule_repo() {
  local repo_dir="$1"
  local repo_name="$2"

  git -C "${REPO_ROOT}" submodule sync -- "${repo_dir}" >/dev/null

  if [[ ! -d "${repo_dir}/.git" && ! -f "${repo_dir}/.git" ]]; then
    log ""
    log "Initializing submodule ${repo_name}"
    git -C "${REPO_ROOT}" submodule update --init --recursive -- "${repo_dir}"
  fi

  if [[ ! -d "${repo_dir}/.git" && ! -f "${repo_dir}/.git" ]]; then
    printf '%s\n' "Missing submodule checkout after init: ${repo_name} (${repo_dir})" >&2
    exit 1
  fi
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
    --work-root)
      WORK_ROOT="$2"
      shift 2
      ;;
    --upstream-root-dir)
      UPSTREAM_ROOT_DIR="$2"
      shift 2
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

BITBUCKET_DIR="${UPSTREAM_ROOT_DIR}/vulcan-examples"
GITHUB_DIR="${UPSTREAM_ROOT_DIR}/dataos"
STAGE_DIR="${WORK_ROOT}/stage"
STAGE_EXAMPLES_DIR="${STAGE_DIR}/vulcan-examples"

mkdir -p "${WORK_ROOT}" "${STAGE_EXAMPLES_DIR}"

log "Mode: ${MODE}"
log "Workspace: ${WORK_ROOT}"
log "Upstream root: ${UPSTREAM_ROOT_DIR}"

ensure_submodule_repo "${BITBUCKET_DIR}" "dpbs-docs/upstream/vulcan-examples"
ensure_submodule_repo "${GITHUB_DIR}" "dpbs-docs/upstream/dataos"

BOOK_SOURCE_DIR="${GITHUB_DIR}/documentation/references/resources/vulcan"

rm -rf "${STAGE_EXAMPLES_DIR}"
mkdir -p "${STAGE_EXAMPLES_DIR}"

for engine in "${ALLOWED_ENGINES[@]}"; do
  if [[ -d "${BITBUCKET_DIR}/${engine}" ]]; then
    if [[ "${MODE}" == "dry-run" ]]; then
      log "[dry-run] stage ${engine} from ${BITBUCKET_DIR}/${engine}"
    fi
    mkdir -p "${STAGE_EXAMPLES_DIR}"
    rsync -a --delete "${UPSTREAM_PRUNE_EXCLUDES[@]}" \
      "${BITBUCKET_DIR}/${engine}/" "${STAGE_EXAMPLES_DIR}/${engine}/"
  fi
done

sync_examples "${STAGE_EXAMPLES_DIR}" "${REPO_ROOT}/dpbs-docs/vulcan-examples"
cleanup_examples_target "${REPO_ROOT}/dpbs-docs/vulcan-examples"

log ""
log "Syncing mapped vulcan-book files from ${BOOK_SOURCE_DIR}"
node "${SCRIPT_DIR}/sync-vulcan-book.mjs" \
  --mode "${MODE}" \
  --repo-root "${REPO_ROOT}" \
  --source-root "${BOOK_SOURCE_DIR}" \
  --mapping-file "${SCRIPT_DIR}/vulcan-book-map.json"

log ""
log "Done."
