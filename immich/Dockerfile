FROM alpine:latest

RUN apk add --no-cache bash curl restic docker dcron

WORKDIR /app

COPY backup.sh /usr/local/bin/backup.sh

RUN chmod +x /usr/local/bin/backup.sh

COPY crontab.txt /etc/crontabs/root
RUN touch /var/log/cron.log

# Set the default entrypoint to your backup script.
CMD ["crond", "-f"]
