FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4

RUN apt-get update && \
    apt-get install -y \
      bash \
      curl \
      docker.io \
      cron \
      restic \
      vim \
      python3 \
      python3-venv \
      python3-pip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt requirements.txt
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip3 install --requirement requirements.txt

COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

COPY backup.py /usr/local/bin/backup.py
RUN chmod +x /usr/local/bin/backup.py

COPY crontab.txt /etc/cron.d/backup
RUN chmod 0644 /etc/cron.d/backup && \
    touch /var/log/cron.log

CMD ["/usr/sbin/cron", "-f"]