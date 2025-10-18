#!/bin/bash
# Guidance logic for gok-agent (merged from original install "next steps" and "next modules install" sections).

# Function to provide guidance for gok-agent
guide_gok_agent() {
    echo "Next steps and module installs for gok-agent:"
    echo ""
    echo "1. Verify agent connectivity:"
    echo "   kubectl logs -f deployment/gok-agent -n gok-agent"
    echo ""
    echo "2. Check agent health:"
    echo "   kubectl exec -it deployment/gok-agent -n gok-agent -- curl http://localhost:8080/health"
    echo ""
    echo "3. Next recommended modules to install:"
    echo "   • gok-controller (for centralized management)"
    echo "   • monitoring stack (Prometheus/Grafana)"
    echo "   • cert-manager (for TLS certificates)"
    echo ""
    echo "4. Access agent metrics:"
    echo "   kubectl port-forward deployment/gok-agent -n gok-agent 8080:8080"
    echo "   Visit: http://localhost:8080/metrics"
    echo ""
    echo "5. Troubleshooting:"
    echo "   • Check agent logs for connectivity issues"
    echo "   • Verify network policies allow agent communication"
    echo "   • Ensure proper RBAC permissions are configured"
    echo ""
    echo "For detailed documentation, see: https://docs.gok.io/agent"
}
export -f guide_gok_agent