#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="dry-run"

DATAOS_VULCAN_PATH="documentation/references/resources/vulcan"

usage() {
  cat <<'EOF'
Usage: scripts/sync-vulcan-sources.sh [--dry-run|--apply]

Syncs the Vulcan submodules in place under dpbs-docs:
  - dpbs-docs/dataos          (GitHub moderndatacompany/dataos, sparse-checked
                               out to documentation/references/resources/vulcan
                               only)
  - dpbs-docs/vulcan-examples (Bitbucket rubik_/vulcan-examples, unfiltered —
                               engine/file filtering happens at install time
                               in bin/create.js, not here)

Operations:
  1. Initializes/force-updates both submodules to their pinned commits,
     restoring full content even if a prior run left it pruned
  2. Restricts dpbs-docs/dataos's working tree to
     documentation/references/resources/vulcan via sparse-checkout

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

update_submodules() {
  log ""
  if [[ "${MODE}" != "apply" ]]; then
    log "[dry-run] would update submodules (dataos, vulcan-examples) to their pinned commits, restoring full content"
    return
  fi

  log "Updating submodules (dataos, vulcan-examples)"
  # --force always re-checks-out the pinned commit's full tree, even if it's
  # already checked out — so any local pruning (e.g. from an older version of
  # this script) gets restored instead of being left stale.
  git -C "${REPO_ROOT}" submodule update --init --recursive --force -- "${DATAOS_DIR}" "${EXAMPLES_DIR}"
}

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

update_submodules
configure_dataos_sparse_checkout

log ""
log "Done."
