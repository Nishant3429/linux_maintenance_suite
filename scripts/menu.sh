#!/usr/bin/env bash
# menu.sh - Interactive maintenance suite menu
set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${ROOT_DIR}/logs"
export LOG_DIR
mkdir -p "$LOG_DIR"

export PATH="$SCRIPT_DIR:$PATH"

show_header() {
  clear || true
  cat <<'EOF'
╔══════════════════════════════════════════════════════╗
║          Linux System Maintenance Suite              ║
╚══════════════════════════════════════════════════════╝
EOF
}

pause() { read -rp "Press Enter to continue..."; }

backup_flow() {
  read -rp "Enter destination backup directory (e.g., /mnt/backup): " dest
  echo "Enter one or more source paths (blank line to finish):"
  sources=()
  while true; do
    read -rp "  Source path: " s
    [[ -z "$s" ]] && break
    sources+=("$s")
  done
  read -rp "Exclude patterns (comma-separated, optional): " ex
  args=()
  for src in "${sources[@]}"; do args+=(--source "$src"); done
  args+=(--dest "$dest")
  if [[ -n "$ex" ]]; then
    IFS=',' read -ra arr <<< "$ex"
    for e in "${arr[@]}"; do args+=(--exclude "$(echo "$e" | xargs)") ; done
  fi
  sudo -n true 2>/dev/null || echo "Note: you may be prompted for sudo (rsync may need permissions)."
  "${SCRIPT_DIR}/backup.sh" "${args[@]}"
  pause
}

updates_flow() {
  echo "This requires root privileges."
  sudo "${SCRIPT_DIR}/update_and_cleanup.sh"
  pause
}

logscan_flow() {
  read -rp "Mode (scan/follow) [scan]: " mode
  mode="${mode:-scan}"
  read -rp "Regex patterns [ERROR|CRITICAL|Failed password]: " pats
  pats="${pats:-ERROR|CRITICAL|Failed password}"
  read -rp "Since (journalctl, e.g., '2 hours ago', optional): " since
  if [[ "$mode" == "follow" ]]; then
    "${SCRIPT_DIR}/log_monitor.sh" --follow --patterns "$pats"
  else
    if [[ -n "$since" ]]; then
      "${SCRIPT_DIR}/log_monitor.sh" --scan --since "$since" --patterns "$pats"
    else
      "${SCRIPT_DIR}/log_monitor.sh" --scan --patterns "$pats"
    fi
    pause
  fi
}

while true; do
  show_header
  echo "1) Backup files/directories"
  echo "2) System update & cleanup"
  echo "3) Log monitoring (scan/follow)"
  echo "4) Show logs directory"
  echo "5) Exit"
  read -rp "Choose an option [1-5]: " choice
  case "$choice" in
    1) backup_flow ;;
    2) updates_flow ;;
    3) logscan_flow ;;
    4) echo "Logs: $LOG_DIR"; ls -lh "$LOG_DIR"; pause ;;
    5) echo "Goodbye!"; exit 0 ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac
done
