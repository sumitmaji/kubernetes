FROM hashicorp/vault:1.12.0

# Install kubectl
RUN apt-get update && apt-get install -y curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install jq
RUN apt-get install -y jq

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*