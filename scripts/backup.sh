#!/usr/bin/env bash
# backup.sh - Safe backup using rsync (incremental) or tar (archive mode)
# Usage:
#   ./backup.sh --source /path --dest /backup/path --exclude "*.tmp"
set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

LOG_FILE="${LOG_DIR}/backup.log"
rotate_log "$LOG_FILE"

SOURCE_DIRS=()
DEST_DIR=""
EXCLUDES=()
MODE="rsync" # rsync|tar

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE_DIRS+=("$2"); shift 2 ;;
    --dest) DEST_DIR="$2"; shift 2 ;;
    --exclude) EXCLUDES+=("$2"); shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Backup script
Usage:
  --source <dir> (repeatable)
  --dest <dir>
  --exclude <pattern> (repeatable)
  --mode rsync|tar
EOF
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

if [[ -z "$DEST_DIR" || ${#SOURCE_DIRS[@]} -eq 0 ]]; then
  echo "Error: --dest and at least one --source required"
  exit 2
fi

mkdir -p "$DEST_DIR"

if [[ "$MODE" == "rsync" ]] && command -v rsync >/dev/null 2>&1; then
  log INFO "Starting rsync backup to $DEST_DIR"
  RSYNC_ARGS=(-aAXHv --numeric-ids --delete --partial --info=progress2)
  for ex in "${EXCLUDES[@]}"; do RSYNC_ARGS+=("--exclude=$ex"); done

  for src in "${SOURCE_DIRS[@]}"; do
    if [[ -d "$src" || -f "$src" ]]; then
      log INFO "Backing up: $src"
      rsync "${RSYNC_ARGS[@]}" "$src" "$DEST_DIR" | tee -a "$LOG_FILE"
    else
      log WARN "Skipping missing path: $src"
    fi
  done

  log INFO "Backup completed."
else
  TS="$(date +%Y%m%d_%H%M%S)"
  ARCHIVE="${DEST_DIR%/}/backup_${TS}.tar.gz"
  log INFO "Creating tar archive ${ARCHIVE}"

  TAR_ARGS=(-czpf "$ARCHIVE")
  for ex in "${EXCLUDES[@]}"; do TAR_ARGS+=("--exclude=$ex"); done

  for src in "${SOURCE_DIRS[@]}"; do
    if [[ -e "$src" ]]; then
      TAR_ARGS+=("$src")
    else
      log WARN "Missing $src"
    fi
  done

  tar "${TAR_ARGS[@]}"
  log INFO "Archive created: ${ARCHIVE}"
fi
