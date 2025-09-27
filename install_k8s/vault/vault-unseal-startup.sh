#!/bin/bash
# Vault Unseal Startup Script
# This script runs on system startup to unseal vault

set -e

# Configuration
NAMESPACE="vault"
JOB_NAME="vault-unseal-startup"
VAULT_MANIFEST="/root/kubernetes/install_k8s/vault/vault-unseal-job.yaml"
KUBECTL_BIN="/usr/local/bin/kubectl"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/vault-unseal.log
}

log "Starting vault unseal process..."

# Wait for kubectl to be available
while ! command -v $KUBECTL_BIN &> /dev/null; do
    log "Waiting for kubectl to be available..."
    sleep 5
done

# Wait for kubernetes to be ready
while ! $KUBECTL_BIN cluster-info &> /dev/null; do
    log "Waiting for kubernetes cluster to be ready..."
    sleep 10
done

log "Kubernetes cluster is ready"

# Delete existing job if it exists
log "Cleaning up any existing vault unseal job..."
$KUBECTL_BIN delete job $JOB_NAME -n $NAMESPACE --ignore-not-found=true

# Wait a moment for cleanup
sleep 2

# Apply the vault unseal job
log "Starting vault unseal job..."
if $KUBECTL_BIN apply -f $VAULT_MANIFEST; then
    log "Vault unseal job created successfully"
    
    # Optional: Wait for job completion
    log "Waiting for job completion..."
    $KUBECTL_BIN wait --for=condition=complete job/$JOB_NAME -n $NAMESPACE --timeout=300s
    
    if [ $? -eq 0 ]; then
        log "Vault unseal job completed successfully"
    else
        log "Vault unseal job timed out or failed"
        exit 1
    fi
else
    log "Failed to create vault unseal job"
    exit 1
fi

log "Vault unseal startup script completed"