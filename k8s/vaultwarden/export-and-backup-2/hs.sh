hc_ping() {
  local action="${1:-}"
  local url="https://hc-ping.com/${HC_UUID}"
  if [[ -n "$action" ]]; then
    url="${url}/${action}"
  fi
  curl -fsS -m 10 "$url" > /dev/null 2>&1
}

log()   { echo "[INFO]  $(date -Iseconds) $*"; }
warn()  { echo "[WARN]  $(date -Iseconds) $*" >&2; }
error() { echo "[ERROR] $(date -Iseconds) $*" >&2; exit 1; }

check_file() { [[ -s "$1" ]] || error "File missing or empty: $1"; }