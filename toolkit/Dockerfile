FROM debian:bookworm-slim@sha256:b1a741487078b369e78119849663d7f1a5341ef2768798f7b7406c4240f86aef

ENV DEBIAN_FRONTEND=noninteractive

ARG RESTIC_VERSION=0.18.0
ENV RESTIC_VERSION=${RESTIC_VERSION}
ARG AGE_VERSION=1.2.1
ENV AGE_VERSION=${AGE_VERSION}
ARG BW_CLI_VERSION=2025.3.0
ENV BW_CLI_VERSION=${BW_CLI_VERSION}
ARG KOPIA_VERSION=0.19.0
ENV KOPIA_VERSION=${KOPIA_VERSION}

RUN apt-get update && \
    apt-get install -y --no-install-recommends parallel curl wget ca-certificates tar unzip jq iputils-ping awscli bzip2 gnupg && \
    rm -rf /var/lib/apt/lists/* && \
    \
    curl -fsSL "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2" | \
      bzip2 -d > /usr/local/bin/restic && \
    chmod +x /usr/local/bin/restic && \
    \
    curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" | \
      tar xz -C /usr/local/bin --strip-components=1 && \
    \
    wget -qO /tmp/bw.zip "https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip" && \
    unzip /tmp/bw.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/bw && \
    rm /tmp/bw.zip && \
    \
    wget -qO /tmp/kopia.deb "https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/kopia_${KOPIA_VERSION}_linux_amd64.deb" && \
    dpkg -i /tmp/kopia.deb && \
    rm /tmp/kopia.deb

RUN mkdir -p "/root/.config/Bitwarden CLI" && \
    touch "/root/.config/Bitwarden CLI/data.json"

WORKDIR /work
CMD ["/bin/bash"]