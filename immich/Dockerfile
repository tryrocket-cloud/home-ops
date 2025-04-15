FROM alpine:latest

RUN apk add --no-cache bash curl restic docker

WORKDIR /app

COPY backup.sh /app/backup.sh

# Make sure the backup script is executable.
RUN chmod +x /app/backup.sh

# Set the default entrypoint to your backup script.
ENTRYPOINT ["/app/backup.sh"]