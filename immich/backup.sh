#!/usr/bin/env bash
set -euxo pipefail

# Prevent concurrent runs using a file lock.
LOCK_FILE="/tmp/immich_backup.lock"
exec 200>"${LOCK_FILE}"
if ! flock -n 200; then
    echo "Another instance of the backup script is already running. Exiting." >&2
    exit 1
fi

HC_BASE="https://hc-ping.com/${HC_UUID}"
HC_START="${HC_BASE}/start"
HC_FAIL="${HC_BASE}/fail"
HC_REPORT_SUCCESS="${HC_BASE}/0"

DUMP_FILE="db_dump.sql.gz"

send_ping() {
    local url="$1"
    echo "Sending ping to ${url}"
    curl -fsS -m 10 --retry 5 -o /dev/null "${url}"
}

# On any error, report failure and exit.
report_failure() {
    local exit_code=$1
    echo "An error occurred. Reporting failure (exit status ${exit_code})."
    send_ping "${HC_FAIL}"
    exit "${exit_code}"
}
trap 'report_failure $?' ERR

echo "Starting backup procedure..."

send_ping "${HC_START}"
docker stop immich-server immich-redis-1 immich-machine-learning-1

docker exec -t immich-pgvecto-1 pg_dumpall --clean --if-exists --username="${POSTGRES_USER}" | gzip > "${DUMP_FILE}"

gunzip -t "${DUMP_FILE}"

docker stop immich-pgvecto-1

pwd

#restic backup immich-data "${DUMP_FILE}" \
    --cache-dir .cache/restic \
    --host "${HOSTNAME}" \
    --tag environment=production
#restic check --read-data-subset 1/10
#restic forget --keep-daily 30 --keep-monthly 3 --keep-yearly 1 --prune

send_ping "${HC_REPORT_SUCCESS}"

docker start immich-server immich-redis-1 immich-machine-learning-1 immich-pgvecto-1

echo "Backup completed successfully."

rm -f "${DUMP_FILE}"
