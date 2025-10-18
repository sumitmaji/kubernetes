#!/bin/bash
# Summary logic for gok-agent (extracted/copied from original install summary section).

# Function to summarize gok-agent install
summarize_gok_agent() {
    echo "Summary for gok-agent installation:"
    echo "- Namespace: gok-agent"
    echo "- Helm release: gok-agent"
    echo "- Chart: ${MOUNT_PATH}/kubernetes/install_k8s/gok-cloud/agent/chart"
    echo "- Pods: $(kubectl get pods -n gok-agent -l app.kubernetes.io/name=gok-agent --no-headers 2>/dev/null | wc -l)"
    echo "- ConfigMaps: ca-cert"
    echo "- Status: $(helm status gok-agent -n gok-agent --short 2>/dev/null || echo 'Unknown')"
    echo "- Installation completed at: $(date)"
}
export -f summarize_gok_agent