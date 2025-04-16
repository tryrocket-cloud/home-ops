set dotenv-load

MY_SEC=abc

help:
	@just --list

restic-stats:
    @restic stats

restic-snapshots:
    @restic snapshots --group-by host

restic-key-list:
    @restic key list

