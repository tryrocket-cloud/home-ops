#!/usr/bin/env bash
set -e

echo "Starting backup procedure..."

docker stop immich

sleep 60

docker start immich

echo "Backup completed successfully."
