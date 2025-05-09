hc() {
  local action="${1:-}"
  curl -fsS -m 10 "${HC_URL}/${HC_UUID}/${action}" > /dev/null 2>&1
}
