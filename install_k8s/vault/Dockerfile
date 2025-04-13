FROM debian:bullseye-slim

# Install dependencies and tools
RUN apt-get update && apt-get install -y \
    curl \
    jq && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Add Vault binary
RUN curl -fsSL https://releases.hashicorp.com/vault/1.12.0/vault_1.12.0_linux_amd64.zip -o vault.zip && \
    apt-get update && apt-get install -y unzip && \
    unzip vault.zip && mv vault /usr/local/bin/vault && \
    chmod +x /usr/local/bin/vault && \
    rm vault.zip && apt-get clean && rm -rf /var/lib/apt/lists/*