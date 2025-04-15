FROM debian:trixie-slim

RUN apt-get update && \
    apt-get install -y \
      bash \
      curl \
      docker.io \
      cron \
      restic \
      vim \
      python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

COPY crontab.txt /etc/cron.d/backup
RUN chmod 0644 /etc/cron.d/backup && \
    touch /var/log/cron.log

CMD ["/usr/sbin/cron", "-f"]