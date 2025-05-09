#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  HC_UUID VAULTWARDEN_HOST VAULTWARDEN_USERNAME VAULTWARDEN_PASSWORD
  VAULTWARDEN_USER_ID BW_CLI_VERSION AGE_RECIPIENT
  BUCKET AWS_ENDPOINT_URL HOSTNAME AGE_VERSION
)
for var in "${required_vars[@]}"; do
  [[ -z "${!var:-}" ]] && { echo "Missing required env: $var" >&2; exit 1; }
done

function check_file() {
  local file="$1"
  [[ -s "$file" ]] || { echo "ERROR: $file missing or empty" >&2; exit 1; }
}

curl -fsS -m 10 "https://hc-ping.com/${HC_UUID}/start"  > /dev/null 2>&1

function finally {
  echo "🔐 Enforcing final S3 block policy…"
  aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --endpoint-url "${AWS_ENDPOINT_URL}" \
    --public-access-block-configuration file:///policies/public-access-block-deny-all.json
  aws s3api put-bucket-policy \
    --bucket "${BUCKET}" \
    --endpoint-url "${AWS_ENDPOINT_URL}" \
    --policy file:///policies/deny-all-policy.json
}
trap finally EXIT

VW_VERSION=$(curl -sSf -m 10 "https://${VAULTWARDEN_HOST}/api/config" | jq -r '.version // empty')

bw config server "https://${VAULTWARDEN_HOST}"
export BW_SESSION
BW_SESSION=$(bw login --raw --cleanexit "${VAULTWARDEN_USERNAME}" "${VAULTWARDEN_PASSWORD}")
bw sync --cleanexit --quiet
bw export --cleanexit --quiet --format encrypted_json --password "${VAULTWARDEN_PASSWORD}" --output "/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-encrypted_json.json"
bw export --cleanexit --quiet --format json --output "/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-plain.json"
bw logout --cleanexit --quiet

  

check_file "/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-encrypted_json.json"
check_file "/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-plain.json"

PLAIN="/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-plain.json"
CIPHER="/export/vaultwarden-export-${VAULTWARDEN_USER_ID}.age"

check_file "$PLAIN"
age --recipient "${AGE_RECIPIENT}" --output "${CIPHER}" "${PLAIN}"
check_file "$CIPHER"
head -c21 "${CIPHER}" | grep -q '^age-encryption\.org/v1'
rm "$PLAIN"

aws s3api put-bucket-policy --bucket "${BUCKET}" --endpoint-url "${AWS_ENDPOINT_URL}" --policy file:///policies/restic-policy.json
aws s3api put-public-access-block --bucket "${BUCKET}" --endpoint-url "${AWS_ENDPOINT_URL}" --public-access-block-configuration file:///policies/public-access-block-restic.json

restic backup \
  --host "${HOSTNAME}" \
  --tag restic_version:"$(restic version | awk 'NR==1{print $2}')" \
  --tag bw_cli_version:"$BW_CLI_VERSION" \
  --tag vaultwarden_version:"$VW_VERSION" \
  --tag age_version:"$AGE_VERSION" \
  --tag environment:production \
  /export
restic check --read-data
restic forget --keep-within '180d' --prune

curl -fsS -m 10 "https://hc-ping.com/${HC_UUID}" > /dev/null 2>&1

echo "✅ backup completed successfully."