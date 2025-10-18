#!/bin/bash
# Summary logic for gok-controller (extracted/copied from original install summary section).

# Function to summarize gok-controller install
summarize_gok_controller() {
    echo "Summary for gok-controller installation:"
    echo "- Namespace: gok-controller"
    echo "- Helm release: gok-controller"
    echo "- Chart: ${MOUNT_PATH}/kubernetes/install_k8s/gok-cloud/controller/chart"
    echo "- Pods: $(kubectl get pods -n gok-controller -l app.kubernetes.io/name=gok-controller --no-headers 2>/dev/null | wc -l)"
    echo "- ConfigMaps: ca-cert"
    echo "- Ingress: gok-controller (Let's Encrypt patched)"
    echo "- Access URL: https://controller.$(rootDomain)"
    echo "- Status: $(helm status gok-controller -n gok-controller --short 2>/dev/null || echo 'Unknown')"
    echo "- Installation completed at: $(date)"
}
export -f summarize_gok_controller