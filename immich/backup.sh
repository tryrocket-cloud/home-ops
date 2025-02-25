#!/usr/bin/env bash
set -euxo pipefail

# Define base data directory and derived paths.
BASE_DIR="/app/data"
DUMP_FILE="${BASE_DIR}/db_dump.sql.gz"
IMMICH_DATA="${BASE_DIR}/immich-data"

# Change to base directory.
cd "${BASE_DIR}" || { echo "Cannot change directory to ${BASE_DIR}"; exit 1; }

# Prevent concurrent runs using a file lock.
LOCK_FILE="/tmp/immich_backup.lock"
exec 200>"${LOCK_FILE}"
if ! flock -n 200; then
    echo "Another instance of the backup script is already running. Exiting." >&2
    exit 1
fi

# Healthchecks.io endpoints – assumes HC_UUID is set.
HC_BASE="https://hc-ping.com/${HC_UUID}"
HC_START="${HC_BASE}/start"
HC_FAIL="${HC_BASE}/fail"
HC_REPORT_SUCCESS="${HC_BASE}/0"

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

# Retrieve the image tag in use by immich-server.
IMMICH_IMAGE=$(docker inspect --format '{{ index .Config.Image }}' immich-server)
IMMICH_IMAGE_TAG=${IMMICH_IMAGE##*:}
echo "Immich server image tag: ${IMMICH_IMAGE_TAG}"

# Signal the start of the backup.
send_ping "${HC_START}"

# Stop the service containers (non-database ones).
docker stop immich-server immich-redis-1 immich-machine-learning-1

# Dump the PostgreSQL database and compress it.
docker exec -t immich-pgvecto-1 pg_dumpall --clean --if-exists --username="${POSTGRES_USER}" \
    | gzip > "${DUMP_FILE}"

# Verify the database dump file.
gunzip -t "${DUMP_FILE}"

# Stop the PostgreSQL container to avoid data changes during backup.
docker stop immich-pgvecto-1

# Run the restic backup with appropriate tags.
restic backup "${IMMICH_DATA}" "${DUMP_FILE}" \
    --tag "immich_version:${IMMICH_IMAGE_TAG}" \
    --tag environment=production

# Run integrity check and prune old snapshots.
restic check --read-data-subset 1/10
restic forget --keep-daily 30 --keep-monthly 3 --keep-yearly 1 --prune

# Report success to healthchecks.io.
send_ping "${HC_REPORT_SUCCESS}"

# Restart all previously stopped containers.
docker start immich-server immich-redis-1 immich-machine-learning-1 immich-pgvecto-1

echo "Backup completed successfully."

# Remove the database dump file.
rm -f "${DUMP_FILE}"
