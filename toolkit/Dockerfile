FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y curl wget ca-certificates tar restic unzip jq iputils-ping awscli bzip2 gnupg && \
    rm -rf /var/lib/apt/lists/*

ARG AGE_VERSION=1.2.1
RUN curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" | \ 
    tar xz -C /usr/local/bin --strip-components=1 && \
    chmod +x /usr/local/bin/age

ARG BW_CLI_VERSION=2025.3.0
RUN wget -qO /tmp/bw.zip "https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip" && \
    unzip /tmp/bw.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/bw && \
    rm /tmp/bw.zip

ARG KOPIA_VERSION=0.19.0
RUN wget -qO /tmp/kopia.deb "https://github.com/kopia/kopia/releases/download/v${KOPIA_VERSION}/kopia_${KOPIA_VERSION}_linux_amd64.deb" && \
    dpkg -i /tmp/kopia.deb && \
    rm /tmp/kopia.deb

RUN mkdir -p "/root/.config/Bitwarden CLI" && \
    touch "/root/.config/Bitwarden CLI/data.json"

WORKDIR /work
CMD ["/bin/bash"]
