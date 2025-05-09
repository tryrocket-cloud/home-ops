#!/usr/bin/env bash
set -euo pipefail

#–– healthcheck start ––
curl -fsS -m 10 https://hc-ping.com/${HC_UUID}/start

#–– always-run “finally” block ––
function finally {
echo "🔐 enforcing final S3 block policy…"
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

#–– 1) get VW version ––
VW_VERSION=$(curl -sSf -m 10 "https://${VAULTWARDEN_HOST}/api/config" \
                | jq -r '.version // empty')
echo "Vaultwarden version: $VW_VERSION"

bw config server https://${VAULTWARDEN_HOST}
export BW_SESSION=$(bw login --raw "${VAULTWARDEN_USERNAME}" "${VAULTWARDEN_PASSWORD}")
bw sync
bw export \
--format encrypted_json \
--password "${VAULTWARDEN_PASSWORD}" \
--output /export/vaultwarden-export-"${VAULTWARDEN_USER_ID}"-encrypted_json.json
bw export \
--format json \
--output /export/vaultwarden-export-"${VAULTWARDEN_USER_ID}"-plain.json
bw logout

[ -s "/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-encrypted_json.json" ] || { echo "ERROR: export failed or produced empty file" >&2; exit 1; }
[ -s "/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-plain.json" ] || { echo "ERROR: export failed or produced empty file" >&2; exit 1; }


PLAIN="/export/vaultwarden-export-${VAULTWARDEN_USER_ID}-plain.json"
CIPHER="/export/vaultwarden-export-${VAULTWARDEN_USER_ID}.age"

[ -s "${PLAIN}" ] || { echo "ERROR: missing plaintext export" >&2; exit 1; }

age --recipient "${AGE_RECIPIENT}" --output "${CIPHER}" "${PLAIN}"

[ -s "${CIPHER}" ] || { echo "ERROR: age encryption failed" >&2; exit 1; }
head -c21 "${CIPHER}" | grep -q '^age-encryption\.org/v1'

rm "${PLAIN}"

#–– 4) configure S3 for restic ––
aws s3api put-bucket-policy \
--bucket "${BUCKET}" \
--endpoint-url "${AWS_ENDPOINT_URL}" \
--policy file:///policies/restic-policy.json
aws s3api put-public-access-block \
--bucket "${BUCKET}" \
--endpoint-url "${AWS_ENDPOINT_URL}" \
--public-access-block-configuration file:///policies/public-access-block-restic.json

#–– 5) restic backup & prune ––

restic backup \
--host "${HOSTNAME}" \
--tag restic_version:$(restic version | awk 'NR==1{print $2}') \
--tag bw_cli_version:$BW_CLI_VERSION \
--tag vaultwarden_version:$VW_VERSION \
--tag age_version:$AGE_VERSION \
--tag environment:production \
/export
restic check --read-data
restic forget --keep-within '180d' --prune

#–– 6) final healthcheck ping ––
curl -fsS -m 10 https://hc-ping.com/${HC_UUID}

echo "✅ backup completed successfully."