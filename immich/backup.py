#!/usr/bin/env python3

import os
import sys
import logging
import docker
import gzip
import subprocess
import requests
from pathlib import Path

from contextlib import contextmanager
from filelock import FileLock
from healthchecks_io import Client, CheckTrap

hc_uuid = os.environ.get("HC_UUID")

docker_client = docker.from_env()
hc_client = Client(api_key=os.environ.get("HC_API_KEY"))

# ---------------------------
# Logging Configuration
# ---------------------------

log_file = os.path.join(os.getcwd(), os.path.splitext(os.path.basename(__file__))[0] + ".log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)


def get_immich_version() -> str:
    container = docker_client.containers.get("immich-server")

    image_full = container.attrs['Config']['Image']
    image_tag = image_full.split(":")[-1]

    return image_tag


def export_database_to(db_dump: Path):
    pg_container = docker_client.containers.get("immich-pgvecto-1")
    exec_result = pg_container.exec_run(f"pg_dumpall --clean --if-exists --username={os.environ.get("POSTGRES_USER")}")

    if exec_result.exit_code != 0:
        raise Exception(f"pg_dumpall failed with exit code {exec_result.exit_code}")

    with open(db_dump, "wb") as dump_file:
        with gzip.GzipFile(fileobj=dump_file, mode="wb") as gz_file:
            gz_file.write(exec_result.output)


def _export_immich_database(db_dump: Path):
    postgres_user = os.environ.get("POSTGRES_USER")
    dump_cmd = f"docker exec -t immich-pgvecto-1 pg_dumpall --clean --if-exists --username={postgres_user} | gzip > {db_dump}"

    try:
        ret = subprocess.run(dump_cmd, shell=True)
        if ret.returncode != 0:
            raise RuntimeError(f"Database dump command failed with return code {ret.returncode}")
    except Exception as e:
        raise RuntimeError(f"Failed to create database dump: {e}")

    if not os.path.isfile(db_dump) or os.path.getsize(db_dump) == 0:
        raise RuntimeError(f"Database dump file {db_dump} is empty or does not exist.")


@contextmanager
def docker_context(docker_containers: list[str]):
    try:
        for name in docker_containers:
            container = docker_client.containers.get(name)
            container.stop()
            log.debug(f"Container '{name}' stopped.")
        yield        
    finally:
        for name in docker_containers:
            container = docker_client.containers.get(name)
            container.start()
            log.debug(f"Container '{name}' started.")


def backup():
    db_dump = Path("/app/data/db_dump.sql.gz")
    
    # export_database_to(db_dump) needs over minutes to run
    # _export_immich_database(db_dump)

    immich_version = get_immich_version()

    with docker_context(["immich-server", "immich-redis-1", "immich-machine-learning-1", "immich-pgvecto-1"]):
        try:
            tags = {
                "immich_version": immich_version,
                "environment": "production"
            }
            paths = [
                Path("/app/data/immich-data"), 
                db_dump
            ]
            log.info("Now Backup tags: %s", tags)
            log.info("Now Backup paths: %s", paths)
            # restic.backup(tags, paths)
            # . /app/venv/bin/activate
            # 0 0 * * * root /app/venv/bin/python /usr/local/bin/backup.py >> /var/log/cron.log 2>&1
            # gunzip -c /app/data/db_dump.sql.gz | head
        except Exception as e:
            log.error(f"An error occurred during the backup process. {e}")
            sys.exit(1)


def main():
    lock_path = os.path.join("/tmp", os.path.splitext(os.path.basename(__file__))[0] + ".lock")
    with FileLock(lock_path), CheckTrap(hc_client, hc_uuid):
        backup()


if __name__ == "__main__":
    main()