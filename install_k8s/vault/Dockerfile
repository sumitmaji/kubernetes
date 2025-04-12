FROM debian:bullseye-slim AS builder

# Install dependencies and tools
RUN apt-get update && apt-get install -y \
    curl \
    jq && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Use the official Vault image as the base for the final image
FROM hashicorp/vault:1.12.0

# Copy kubectl and jq from the builder stage
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/bin/jq /usr/bin/jq