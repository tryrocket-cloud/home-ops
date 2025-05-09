hc_ping() {
  local action="${1:-}"
  local url="https://hc-ping.com/${HC_UUID}"
  if [[ -n "$action" ]]; then
    url="${url}/${action}"
  fi
  curl -fsS -m 10 "$url" > /dev/null 2>&1
}
