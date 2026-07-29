#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="dry-run"
WORK_ROOT=""
CLEANUP_WORK_ROOT="true"
BITBUCKET_URL="${BITBUCKET_URL:-git@bitbucket.org:rubik_/vulcan-examples.git}"
GITHUB_URL="${GITHUB_URL:-git@github.com:moderndatacompany/dataos.git}"
BITBUCKET_BRANCH="${BITBUCKET_BRANCH:-main}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

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

Syncs upstream Vulcan sources into this repository from temporary clones.

Operations:
  1. Clones or refreshes upstream repositories in a temp workspace
  2. Removes the temp workspace automatically when the run finishes
  3. Mirrors allowed engines into dpbs-docs/vulcan-examples
  4. Removes unwanted example content automatically
  5. Applies mapped vulcan-book updates via scripts/sync-vulcan-book.mjs

Options:
  --dry-run            Show what would change without writing files (default)
  --apply              Apply the sync to the working tree
  --work-root PATH     Override temp workspace root and keep it after the run
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

cleanup_workspace() {
  if [[ "${CLEANUP_WORK_ROOT}" == "true" && -n "${WORK_ROOT}" && -d "${WORK_ROOT}" ]]; then
    rm -rf "${WORK_ROOT}"
  fi
}

prepare_repo() {
  local repo_url="$1"
  local repo_branch="$2"
  local repo_dir="$3"
  local repo_label="$4"

  if [[ ! -d "${repo_dir}/.git" ]]; then
    log ""
    log "Cloning ${repo_label} into ${repo_dir}"
    git clone --depth 1 --branch "${repo_branch}" "${repo_url}" "${repo_dir}"
    return
  fi

  log ""
  log "Refreshing ${repo_label} in ${repo_dir}"
  git -C "${repo_dir}" remote set-url origin "${repo_url}"
  git -C "${repo_dir}" fetch --depth 1 origin "${repo_branch}"
  git -C "${repo_dir}" checkout -B "${repo_branch}" "origin/${repo_branch}"
  git -C "${repo_dir}" reset --hard "origin/${repo_branch}"
  git -C "${repo_dir}" clean -fd
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
      CLEANUP_WORK_ROOT="false"
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

if [[ -z "${WORK_ROOT}" ]]; then
  WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vulcan-sync.XXXXXX")"
fi

trap cleanup_workspace EXIT

SOURCE_ROOT_DIR="${WORK_ROOT}/sources"
BITBUCKET_DIR="${SOURCE_ROOT_DIR}/vulcan-examples"
GITHUB_DIR="${SOURCE_ROOT_DIR}/dataos"
STAGE_DIR="${WORK_ROOT}/stage"
STAGE_EXAMPLES_DIR="${STAGE_DIR}/vulcan-examples"

mkdir -p "${SOURCE_ROOT_DIR}" "${STAGE_EXAMPLES_DIR}"

log "Mode: ${MODE}"
log "Workspace: ${WORK_ROOT}"
log "Source cache: ${SOURCE_ROOT_DIR}"

prepare_repo "${BITBUCKET_URL}" "${BITBUCKET_BRANCH}" "${BITBUCKET_DIR}" "vulcan-examples"
prepare_repo "${GITHUB_URL}" "${GITHUB_BRANCH}" "${GITHUB_DIR}" "dataos"

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
