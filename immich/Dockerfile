FROM debian:bullseye-slim

# Install necessary packages and clean up apt cache.
RUN apt-get update && \
    apt-get install -y \
      bash \
      curl \
      restic \
      docker.io \
      cron && \
    rm -rf /var/lib/apt/lists/*

# Set working directory.
WORKDIR /app

# Copy backup script and make it executable.
COPY backup1.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

# Copy the crontab file into /etc/cron.d.
COPY crontab.txt /etc/cron.d/backup
RUN chmod 0644 /etc/cron.d/backup && \
    touch /var/log/cron.log

# Run cron in the foreground.
CMD ["/usr/sbin/cron", "-f"]
