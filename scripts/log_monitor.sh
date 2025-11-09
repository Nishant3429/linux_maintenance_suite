#!/usr/bin/env bash
# log_monitor.sh - Scan or follow logs and alert on patterns
# Usage:
#   ./log_monitor.sh --scan
#   ./log_monitor.sh --follow
# Options:
#   --patterns "ERROR|CRITICAL|Failed password"   (regex)
#   --file /var/log/syslog  (repeatable)
#   --since "1 hour ago"    (journalctl mode)
set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

LOG_FILE="${LOG_DIR}/log_monitor.log"
rotate_log "$LOG_FILE"

MODE="scan"
PATTERNS="ERROR|CRITICAL|Failed password|segfault|panic|oom-killer"
FILES=()
SINCE=""
ALERT_CMD=""  # e.g., 'wall' or 'notify-send'; empty => echo only

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan) MODE="scan"; shift ;;
    --follow) MODE="follow"; shift ;;
    --patterns) PATTERNS="$2"; shift 2 ;;
    --file) FILES+=("$2"); shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --alert-cmd) ALERT_CMD="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Monitor logs and alert on patterns.
  --scan | --follow
  --patterns "REGEX"
  --file /path/to/log (repeatable)
  --since "1 hour ago"    (journalctl)
  --alert-cmd "wall"      (or notify-send, echo, etc.)
Examples:
  ./log_monitor.sh --scan --patterns "Failed password|sudo: .* authentication failure" --file /var/log/auth.log
  ./log_monitor.sh --follow --patterns "panic|oom-killer"
EOF
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

alert() {
  local line="$1"
  local msg="[ALERT] $(timestamp) :: $line"
  echo "$msg" | tee -a "$LOG_FILE"
  if [[ -n "$ALERT_CMD" ]]; then
    # shellcheck disable=SC2086
    echo "$msg" | $ALERT_CMD || true
  fi
}

journal_mode=false
if command -v journalctl >/dev/null 2>&1; then journal_mode=true; fi

if [[ "$MODE" == "scan" ]]; then
  log INFO "Scanning logs for patterns: $PATTERNS"
  if $journal_mode; then
    if [[ -n "$SINCE" ]]; then
      journalctl --since "$SINCE" -p info -n all -o short-iso | grep -E "$PATTERNS" -i || true | while read -r line; do alert "$line"; done
    else
      journalctl -p info -n 1000 -o short-iso | grep -E "$PATTERNS" -i || true | while read -r line; do alert "$line"; done
    fi
  else
    if [[ ${#FILES[@]} -eq 0 ]]; then
      FILES=("/var/log/syslog" "/var/log/messages")
    fi
    for f in "${FILES[@]}"; do
      [[ -f "$f" ]] || { log WARN "Skipping missing $f"; continue; }
      grep -E -i "$PATTERNS" "$f" | while read -r line; do alert "$line"; done
    done
  fi
  log INFO "Scan completed."
else
  log INFO "Following logs for patterns: $PATTERNS"
  if $journal_mode; then
    journalctl -f -o short-iso | grep -E --line-buffered -i "$PATTERNS" | while read -r line; do alert "$line"; done
  else
    if [[ ${#FILES[@]} -eq 0 ]]; then
      FILES=("/var/log/syslog" "/var/log/messages")
    fi
    tail -Fn0 "${FILES[@]}" 2>/dev/null | grep -E --line-buffered -i "$PATTERNS" | while read -r line; do alert "$line"; done
  fi
fi
