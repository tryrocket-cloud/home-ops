#!/usr/bin/env bash
set -euo pipefail

echo "Starting backup procedure..."

RESTIC_VERSION=$( restic version | grep -oP 'restic \K[0-9.]+')
IMMICH_VERSION=$( docker exec immich-server /usr/bin/immich --version | grep -oP 'Immich \K[0-9.]+' )

HEALTHCHECKS_UUID=8e8fd81c-4b46-4ddf-913d-add07e66832f
HEALTHCHECKS_API_KEY=jTV1xRU4u3sgK2375Cs56CMMoBEQkKHL
AWS_ACCESS_KEY_ID=EAAAAAFST23-w7xHkJ5R_SoHFJStLceMn5UrXHGPUvjeZS8rAgAAAAECCpNuAAAAAAIKk25VDzn3RCgpB2Q5VHtclQxG
AWS_SECRET_ACCESS_KEY=lN7iYpcvE6UQv8OKNQIptmFqU6OlaHb+eXGuu85cGxf4NfKWQTToHOHmU/1rIqZW
RESTIC_REPOSITORY=s3:s3.eu-central-3.ionoscloud.com/tryrocket.cloud/immich/backup/restic/
RESTIC_PASSWORD=NZ3tXTUIvQgnYqbfMAs7eCqYOI9NgIHexuLwhUmq9bpNQkqNqAEKZ7HnHoCpxhSKIO6kCqqs1AzehXopgjECIUwV50Z0DjZ7neV8BFEJDBJ66CjOiSHw70PN8992qtef

docker stop immich-server immich-redis-1 immich-machine-learning-1

curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/$HEALTHCHECKS_UUID/start \
  -H "User-Agent: Immich Backup" \
  -H "X-Immich-Version: $IMMICH_VERSION" \
  -H "X-Restic-Version: $RESTIC_VERSION" \
  -H "X-Environment: production" \
  --data-urlencode "status=200" \
  --data-urlencode "message=Backup started" \
  --data-urlencode "tags=backup,restic,immich"

docker exec -t immich-pgvecto-1 pg_dumpall --clean --if-exists --username=postgres | gzip > db_dump.sql.gz 
docker stop immich-pgvecto-1

restic backup --cache-dir /tmp/restic-cache \
  --repo s3:s3.amazonaws.com/$S3_BUCKET_NAME \
  --password-file /run/secrets/restic_password \
  --verbose \
  --tag immich_version:$IMMICH_VERSION \
  --tag environment=production \
  --tag restic_version:$RESTIC_VERSION \
  --exclude-file /backup/exclude.txt \
  immich-data db_dump.sql.gz

restic backup immich-data db_dump.sql.gz \
  --cache-dir .cache/restic \
  --host $HOSTNAME \
  --tag immich_version:$IMMICH_VERSION \
  --tag environment=production \
  --tag restic_version:$RESTIC_VERSION

restic check --read-data-subset 1/10
restic forget --keep-daily 30 --keep-monthly 3 --keep-yearly 1 --prune

curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/$HEALTHCHECKS_UUID \
  -H "User-Agent: Immich Backup" \
  -H "X-Immich-Version: $IMMICH_VERSION" \
  -H "X-Restic-Version: $RESTIC_VERSION" \
  -H "X-Environment: production" \
  --data-urlencode "status=200" \
  --data-urlencode "message=Backup completed successfully" \
  --data-urlencode "tags=backup,restic,immich"

echo "Backup process completed successfully."

docker start immich-server immich-redis-1 immich-machine-learning-1 immich-pgvecto-1

echo "Backup completed successfully."
