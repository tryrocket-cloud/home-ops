FROM debian:trixie-slim@sha256:c85a2732e97694ea77237c61304b3bb410e0e961dd6ee945997a06c788c545bb

RUN apt-get update && \
    apt-get install -y wget ca-certificates tar just restic ansible unzip && \
    rm -rf /var/lib/apt/lists/*

RUN ansible-galaxy collection install arensb.truenas community.healthchecksio community.docker community.general

ARG BW_CLI_VERSION=2025.2.0
RUN wget -qO /tmp/bw.zip "https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip" && \
    unzip /tmp/bw.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/bw && \
    rm /tmp/bw.zip

ARG MEDUSA_VERSION=0.7.3
RUN wget -qO /tmp/medusa.tar.gz "https://github.com/jonasvinther/medusa/releases/download/v${MEDUSA_VERSION}/medusa_${MEDUSA_VERSION}_linux_amd64.tar.gz" && \
    tar -xzf /tmp/medusa.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/medusa && \
    rm /tmp/medusa.tar.gz

RUN mkdir -p "/root/.config/Bitwarden CLI" && \
    touch "/root/.config/Bitwarden CLI/data.json"

COPY tools /tools
COPY ansible /ansible

ENTRYPOINT [ "just", "--justfile", "/tools/Justfile" ]
