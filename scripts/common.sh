#!/usr/bin/env bash
# common.sh - Shared helpers for the Linux Maintenance Suite
set -o errexit
set -o pipefail
set -o nounset

LOG_DIR="${LOG_DIR:-$(dirname "$0")/../logs}"
mkdir -p "$LOG_DIR"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

log() {
  local level="$1"; shift
  local msg="$*"
  printf "[%s] [%s] %s\n" "$(timestamp)" "$level" "$msg" | tee -a "$LOG_FILE"
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This action needs root privileges. Re-run with sudo."
    exit 1
  fi
}

detect_pkg_manager() {
  if command -v apt >/dev/null 2>&1; then echo "apt"
  elif command -v dnf >/dev/null 2>&1; then echo "dnf"
  elif command -v yum >/dev/null 2>&1; then echo "yum"
  elif command -v pacman >/dev/null 2>&1; then echo "pacman"
  elif command -v zypper >/dev/null 2>&1; then echo "zypper"
  else
    echo "unknown"
  fi
}

rotate_log() {
  local logfile="$1"
  local max_size_kb="${2:-2048}"
  if [[ -f "$logfile" ]]; then
    local size_kb
    size_kb=$(du -k "$logfile" | awk '{print $1}')
    if (( size_kb > max_size_kb )); then
      mv "$logfile" "${logfile}.$(date +%Y%m%d%H%M%S).bak"
      touch "$logfile"
    fi
  fi
}
