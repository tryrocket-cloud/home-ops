#!/usr/bin/env bash
set -euo pipefail

#─── CONFIGURATION ─────────────────────────────────────────────────────────────
readonly REQUIRED_VARS=(
  HC_UUID VAULTWARDEN_HOST VAULTWARDEN_USERNAME VAULTWARDEN_PASSWORD
  VAULTWARDEN_USER_ID BW_CLI_VERSION AGE_RECIPIENT
  BUCKET AWS_ENDPOINT_URL HOSTNAME AGE_VERSION
)
readonly EXPORT_DIR="/export"
readonly POLICIES_DIR="/policies"
readonly HC_URL="https://hc-ping.com/${HC_UUID}"
readonly RESTIC_KEEP_WITHIN="180d"

#─── LOGGING ───────────────────────────────────────────────────────────────────
log()   { echo "[INFO]  $(date -Iseconds) $*"; }
warn()  { echo "[WARN]  $(date -Iseconds) $*" >&2; }
error() { echo "[ERROR] $(date -Iseconds) $*" >&2; exit 1; }

#─── PRE-FLIGHT CHECKS ───────────────────────────────────────────────────────────
require_env() {
  for var in "${REQUIRED_VARS[@]}"; do
    [[ -n "${!var:-}" ]] || error "Missing required env: $var"
  done
}

require_cmds() {
  local cmds=(curl aws jq bw age restic)
  for cmd in "${cmds[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || error "Command not found: $cmd"
  done
}

check_file() {
  [[ -s "$1" ]] || error "File missing or empty: $1"
}

#─── TRAP HANDLER ────────────────────────────────────────────────────────────────
on_exit() {
  local code=$?
  log "Applying final S3 block policy…"
  aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --endpoint-url "${AWS_ENDPOINT_URL}" \
    --public-access-block-configuration file://"${POLICIES_DIR}/public-access-block-deny-all.json"
  aws s3api put-bucket-policy \
    --bucket "${BUCKET}" \
    --endpoint-url "${AWS_ENDPOINT_URL}" \
    --policy file://"${POLICIES_DIR}/deny-all-policy.json"

  if [[ $code -eq 0 ]]; then
    curl -fsS -m 10 "${HC_URL}" > /dev/null 2>&1 || warn "Health check ping failed"
    log "Backup completed successfully."
  else
    curl -fsS -m 10 "${HC_URL}/fail" > /dev/null 2>&1 || warn "Failure ping failed"
    error "Backup exited with code $code."
  fi
}
trap on_exit EXIT

#─── MAIN LOGIC ─────────────────────────────────────────────────────────────────
main() {
  require_env
  require_cmds

  log "Starting health-check ping…"
  curl -fsS -m 10 "${HC_URL}/start" > /dev/null 2>&1 || warn "Start ping failed"

  # 1) Fetch Vaultwarden version
  VW_VERSION=$(curl -fsS -m 10 "https://${VAULTWARDEN_HOST}/api/config" \
    | jq -r '.version // empty')
  [[ -n "$VW_VERSION" ]] || error "Unable to retrieve Vaultwarden version"

  # 2) Bitwarden login & export
  log "Logging into Bitwarden and exporting data…"
  bw config server "https://${VAULTWARDEN_HOST}"
  export BW_SESSION
  BW_SESSION=$(bw login --raw --cleanexit "${VAULTWARDEN_USERNAME}" "${VAULTWARDEN_PASSWORD}")
  bw sync --cleanexit --quiet

  local enc_json="${EXPORT_DIR}/vaultwarden-${VAULTWARDEN_USER_ID}.encrypted.json"
  local plain_json="${EXPORT_DIR}/vaultwarden-${VAULTWARDEN_USER_ID}.plain.json"

  bw export --format encrypted_json --password "${VAULTWARDEN_PASSWORD}" \
    --output "${enc_json}" --cleanexit --quiet
  bw export --format json \
    --output "${plain_json}" --cleanexit --quiet
  bw logout --cleanexit --quiet

  check_file "${enc_json}"
  check_file "${plain_json}"

  # 3) AGE encryption
  log "Encrypting export with age…"
  local cipher_file="${EXPORT_DIR}/vaultwarden-${VAULTWARDEN_USER_ID}.age"
  age --recipient "${AGE_RECIPIENT}" \
      --output "${cipher_file}" "${plain_json}"
  check_file "${cipher_file}"
  head -c21 "${cipher_file}" | grep -q '^age-encryption\.org/v1' \
    || error "Invalid age header"
  rm -f "${plain_json}"

  # 4) Prepare S3 policies for restic run
  log "Applying S3 policies for Restic…"
  aws s3api put-bucket-policy \
    --bucket "${BUCKET}" \
    --endpoint-url "${AWS_ENDPOINT_URL}" \
    --policy file://"${POLICIES_DIR}/restic-policy.json"
  aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --endpoint-url "${AWS_ENDPOINT_URL}" \
    --public-access-block-configuration file://"${POLICIES_DIR}/public-access-block-restic.json"

  # 5) Run Restic
  log "Running Restic backup…"
  restic backup \
    --host "${HOSTNAME}" \
    --tag "restic_version:$(restic version | awk 'NR==1{print $2}')" \
    --tag "bw_cli_version:${BW_CLI_VERSION}" \
    --tag "vaultwarden_version:${VW_VERSION}" \
    --tag "age_version:${AGE_VERSION}" \
    --tag "environment:production" \
    "${EXPORT_DIR}"

  restic check --read-data
  restic forget --keep-within "${RESTIC_KEEP_WITHIN}" --prune
}

main "$@"
