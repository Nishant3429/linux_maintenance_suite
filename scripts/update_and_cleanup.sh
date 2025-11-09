#!/usr/bin/env bash
# update_and_cleanup.sh - Cross-distro updates + cleanup
# Runs with sudo/root privileges
set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

LOG_FILE="${LOG_DIR}/updates.log"
rotate_log "$LOG_FILE"
require_root

pm=$(detect_pkg_manager)
log INFO "Detected package manager: $pm"

case "$pm" in
  apt)
    log INFO "Updating package lists"
    apt update | tee -a "$LOG_FILE"
    log INFO "Upgrading packages"
    apt -y upgrade | tee -a "$LOG_FILE"
    log INFO "Autoremove + clean"
    apt -y autoremove | tee -a "$LOG_FILE"
    apt -y autoclean | tee -a "$LOG_FILE"
    ;;
  dnf)
    dnf -y upgrade | tee -a "$LOG_FILE"
    dnf -y autoremove | tee -a "$LOG_FILE"
    dnf -y clean all | tee -a "$LOG_FILE"
    ;;
  yum)
    yum -y update | tee -a "$LOG_FILE"
    yum -y autoremove | tee -a "$LOG_FILE" || true
    yum -y clean all | tee -a "$LOG_FILE"
    ;;
  pacman)
    pacman -Syu --noconfirm | tee -a "$LOG_FILE"
    paccache -r || true
    ;;
  zypper)
    zypper refresh | tee -a "$LOG_FILE"
    zypper update -y | tee -a "$LOG_FILE"
    zypper clean -a | tee -a "$LOG_FILE"
    ;;
  *)
    log ERROR "Unsupported package manager. Exiting."
    exit 1;;
esac

# Optional cleanup of orphans (best effort on Debian-like)
if command -v deborphan >/dev/null 2>&1; then
  deborphan | xargs -r apt -y remove | tee -a "$LOG_FILE" || true
fi

log INFO "System update & cleanup complete."
