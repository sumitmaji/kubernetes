#!/bin/bash

# OAuth2 Proxy Debugging and Validation Script
# This script captures the current working OAuth2 configuration and validates future deployments
# Author: Generated for OAuth2 troubleshooting
# Date: $(date)

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
NAMESPACE="oauth2"
DEPLOYMENT_NAME="oauth2-proxy"
SERVICE_NAME="oauth2-proxy"
INGRESS_NAME="oauth2-proxy"
DEBUG_DIR="/tmp/oauth2-debug-$(date +%Y%m%d-%H%M%S)"

# Create debug directory
mkdir -p "$DEBUG_DIR"

echo -e "${BOLD}${CYAN}OAuth2 Proxy Debug and Validation Script${NC}"
echo -e "${CYAN}Debug output directory: $DEBUG_DIR${NC}\n"

# Function to log with timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to capture and explain deployment configuration
capture_deployment() {
    log "${BOLD}${BLUE}=== CAPTURING DEPLOYMENT CONFIGURATION ===${NC}"
    
    # Capture deployment YAML
    kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o yaml > "$DEBUG_DIR/deployment.yaml"
    
    # Extract and explain arguments
    echo -e "${YELLOW}OAuth2 Proxy Arguments and Their Meanings:${NC}" | tee "$DEBUG_DIR/arguments_explained.txt"
    echo "======================================================" | tee -a "$DEBUG_DIR/arguments_explained.txt"
    
    # Get the arguments from deployment
    kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].args}' > "$DEBUG_DIR/raw_args.json"
    
    # Parse and explain each argument
    cat << 'EOF' > "$DEBUG_DIR/explain_args.py"
import json
import sys

# OAuth2 Proxy argument explanations
arg_explanations = {
    "--http-address": "HTTP listening address and port (default: 0.0.0.0:4180)",
    "--https-address": "HTTPS listening address and port (default: 0.0.0.0:4443)", 
    "--metrics-address": "Metrics endpoint listening address and port",
    "--provider": "OAuth provider type (oidc, google, github, etc.)",
    "--keycloak-group": "Allowed Keycloak groups for authentication",
    "--allowed-group": "Groups allowed to authenticate (can be specified multiple times)",
    "--scope": "OAuth scopes to request from the provider",
    "--ssl-insecure-skip-verify": "Skip SSL certificate verification (true/false)",
    "--set-authorization-header": "Set Authorization header with access token",
    "--whitelist-domain": "Allowed domains for redirects",
    "--oidc-groups-claim": "OIDC claim name that contains user groups",
    "--user-id-claim": "OIDC claim to use as user ID (usually 'sub')",
    "--cookie-domain": "Domain to set cookies for",
    "--cookie-secure": "Use secure cookies (requires HTTPS)",
    "--pass-access-token": "Pass access token to upstream in X-Access-Token header",
    "--pass-authorization-header": "Pass Authorization header to upstream",
    "--standard-logging": "Enable standard request logging",
    "--auth-logging": "Enable authentication event logging",
    "--request-logging": "Enable detailed request logging",
    "--cookie-refresh": "Cookie refresh interval",
    "--cookie-expire": "Cookie expiration time", 
    "--set-xauthrequest": "Set X-Auth-Request-* headers",
    "--skip-jwt-bearer-tokens": "Skip JWT bearer token validation",
    "--email-domain": "Allowed email domains (* for any)",
    "--oidc-issuer-url": "OIDC issuer URL",
    "--oidc-jwks-url": "OIDC JWKS (JSON Web Key Set) URL",
    "--reverse-proxy": "Enable reverse proxy mode",
    "--login-url": "OIDC authorization endpoint URL",
    "--redeem-url": "OIDC token endpoint URL", 
    "--profile-url": "OIDC userinfo endpoint URL",
    "--validate-url": "OIDC token validation endpoint URL",
    "--show-debug-on-error": "Show debug information when errors occur",
    "--silence-ping-logging": "Disable logging for /ping endpoint requests",
    "--upstream": "Upstream URL to proxy authenticated requests to",
    "--skip-provider-button": "Skip showing provider selection button"
}

try:
    with open(sys.argv[1], 'r') as f:
        args = json.load(f)
    
    print("OAuth2 Proxy Configuration Analysis:")
    print("=" * 50)
    
    for i, arg in enumerate(args):
        if '=' in arg:
            key, value = arg.split('=', 1)
        else:
            key, value = arg, "enabled"
            
        explanation = arg_explanations.get(key, "Unknown argument - please check documentation")
        print(f"\n{i+1:2d}. {key}")
        print(f"    Value: {value}")
        print(f"    Explanation: {explanation}")
        
except Exception as e:
    print(f"Error parsing arguments: {e}")
EOF

    python3 "$DEBUG_DIR/explain_args.py" "$DEBUG_DIR/raw_args.json" | tee -a "$DEBUG_DIR/arguments_explained.txt"
    
    # Capture environment variables
    log "${YELLOW}Environment Variables:${NC}"
    kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].env}' | tee "$DEBUG_DIR/env_vars.json"
    
    log "${GREEN}✓ Deployment configuration captured${NC}"
}

# Function to capture and explain service configuration
capture_service() {
    log "${BOLD}${BLUE}=== CAPTURING SERVICE CONFIGURATION ===${NC}"
    
    # Capture service YAML
    kubectl get service $SERVICE_NAME -n $NAMESPACE -o yaml > "$DEBUG_DIR/service.yaml"
    
    echo -e "${YELLOW}Service Configuration Analysis:${NC}" | tee "$DEBUG_DIR/service_explained.txt"
    echo "======================================" | tee -a "$DEBUG_DIR/service_explained.txt"
    
    # Get service details
    kubectl describe service $SERVICE_NAME -n $NAMESPACE | tee -a "$DEBUG_DIR/service_explained.txt"
    
    # Explain service components
    cat << 'EOF' | tee -a "$DEBUG_DIR/service_explained.txt"

Service Component Explanations:
==============================
- Type: ClusterIP means the service is only accessible within the cluster
- Ports: Maps external port to container port
- Endpoints: Shows which pods are backing this service
- Selector: Labels used to identify target pods
EOF
    
    # Get endpoints
    log "${YELLOW}Service Endpoints:${NC}"
    kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o yaml > "$DEBUG_DIR/endpoints.yaml"
    kubectl describe endpoints $SERVICE_NAME -n $NAMESPACE | tee -a "$DEBUG_DIR/service_explained.txt"
    
    log "${GREEN}✓ Service configuration captured${NC}"
}

# Function to capture and explain ingress configuration  
capture_ingress() {
    log "${BOLD}${BLUE}=== CAPTURING INGRESS CONFIGURATION ===${NC}"
    
    # Capture ingress YAML
    kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o yaml > "$DEBUG_DIR/ingress.yaml"
    
    echo -e "${YELLOW}Ingress Configuration Analysis:${NC}" | tee "$DEBUG_DIR/ingress_explained.txt"
    echo "======================================" | tee -a "$DEBUG_DIR/ingress_explained.txt"
    
    # Get annotations and explain them
    kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.metadata.annotations}' > "$DEBUG_DIR/ingress_annotations.json"
    
    cat << 'EOF' > "$DEBUG_DIR/explain_ingress.py"
import json
import sys

# Ingress annotation explanations
annotation_explanations = {
    "cert-manager.io/cluster-issuer": "Cert-manager cluster issuer for automatic TLS certificate generation",
    "ingress.kubernetes.io/ssl-passthrough": "Pass SSL traffic directly to backend (true) or terminate at ingress (false)",
    "nginx.ingress.kubernetes.io/ssl-redirect": "Automatically redirect HTTP to HTTPS",
    "nginx.ingress.kubernetes.io/backend-protocol": "Protocol to use when connecting to backend service",
    "kubernetes.io/ingress.allow-http": "Allow HTTP traffic (false means HTTPS only)",
    "nginx.ingress.kubernetes.io/proxy-buffer-size": "Size of buffer for reading response from backend",
    "nginx.ingress.kubernetes.io/proxy-buffers": "Number and size of buffers for reading backend response",
    "nginx.ingress.kubernetes.io/proxy-busy-buffers-size": "Size of busy buffers when reading from backend",
    "kubectl.kubernetes.io/last-applied-configuration": "Last applied configuration (managed by kubectl)"
}

try:
    with open(sys.argv[1], 'r') as f:
        annotations = json.load(f)
    
    print("Ingress Annotations Analysis:")
    print("=" * 40)
    
    for key, value in annotations.items():
        explanation = annotation_explanations.get(key, "Custom annotation - check documentation")
        print(f"\nAnnotation: {key}")
        print(f"Value: {value}")
        print(f"Purpose: {explanation}")
        
except Exception as e:
    print(f"Error parsing annotations: {e}")
EOF

    python3 "$DEBUG_DIR/explain_ingress.py" "$DEBUG_DIR/ingress_annotations.json" | tee -a "$DEBUG_DIR/ingress_explained.txt"
    
    # Describe ingress for additional details
    kubectl describe ingress $INGRESS_NAME -n $NAMESPACE | tee -a "$DEBUG_DIR/ingress_explained.txt"
    
    log "${GREEN}✓ Ingress configuration captured${NC}"
}

# Function to capture ConfigMaps and Secrets
capture_configs() {
    log "${BOLD}${BLUE}=== CAPTURING CONFIGMAPS AND SECRETS ===${NC}"
    
    # Capture OAuth2 ConfigMaps
    for cm in $(kubectl get configmap -n $NAMESPACE -o name | grep oauth2); do
        cm_name=$(echo $cm | cut -d'/' -f2)
        log "Capturing ConfigMap: $cm_name"
        kubectl get configmap $cm_name -n $NAMESPACE -o yaml > "$DEBUG_DIR/configmap_${cm_name}.yaml"
        kubectl describe configmap $cm_name -n $NAMESPACE > "$DEBUG_DIR/configmap_${cm_name}_desc.txt"
    done
    
    # Capture OAuth2 Secrets (without exposing sensitive data)
    for secret in $(kubectl get secret -n $NAMESPACE -o name | grep oauth2); do
        secret_name=$(echo $secret | cut -d'/' -f2)
        log "Capturing Secret metadata: $secret_name"
        kubectl get secret $secret_name -n $NAMESPACE -o yaml | sed 's/data:/data: [REDACTED]/g' > "$DEBUG_DIR/secret_${secret_name}_metadata.yaml"
        kubectl describe secret $secret_name -n $NAMESPACE > "$DEBUG_DIR/secret_${secret_name}_desc.txt"
    done
    
    log "${GREEN}✓ ConfigMaps and Secrets captured${NC}"
}

# Function to capture logs
capture_logs() {
    log "${BOLD}${BLUE}=== CAPTURING LOGS ===${NC}"
    
    # OAuth2 Pod logs
    log "Capturing OAuth2 proxy pod logs..."
    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=oauth2-proxy --tail=100 > "$DEBUG_DIR/oauth2_pod_logs.txt" 2>&1 || true
    
    # Nginx Ingress logs
    log "Capturing Nginx ingress logs..."
    kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 > "$DEBUG_DIR/nginx_ingress_logs.txt" 2>&1 || true
    
    log "${GREEN}✓ Logs captured${NC}"
}

# Function to create ingress-service-endpoint mapping
create_mapping() {
    log "${BOLD}${BLUE}=== CREATING INGRESS-SERVICE-ENDPOINT MAPPING ===${NC}"
    
    cat << 'EOF' > "$DEBUG_DIR/mapping_analysis.txt"
OAuth2 Proxy Traffic Flow Analysis
=================================

1. INGRESS LAYER
   - Receives external traffic on kube.gokcloud.com/oauth2
   - Terminates SSL (if ssl-passthrough=false) 
   - Routes traffic based on path rules
   - Applies annotations for proxy behavior

2. SERVICE LAYER  
   - Acts as load balancer for pods
   - Maps ingress traffic to pod endpoints
   - Provides stable networking interface

3. ENDPOINT LAYER
   - Individual pod IPs and ports
   - Health check status
   - Ready/NotReady status

4. POD LAYER
   - Actual OAuth2 proxy containers
   - Runs on port 4180 (HTTP) and 4443 (HTTPS)
   - Handles authentication logic

Traffic Flow:
External -> Ingress -> Service -> Endpoints -> Pods -> Upstream
EOF

    # Create detailed mapping
    echo -e "\nDetailed Current Mapping:" >> "$DEBUG_DIR/mapping_analysis.txt"
    echo "=========================" >> "$DEBUG_DIR/mapping_analysis.txt"
    
    # Ingress details
    echo -e "\nINGRESS: $INGRESS_NAME" >> "$DEBUG_DIR/mapping_analysis.txt"
    kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o custom-columns="NAME:.metadata.name,HOSTS:.spec.rules[*].host,PATHS:.spec.rules[*].http.paths[*].path,BACKEND:.spec.rules[*].http.paths[*].backend.service.name" --no-headers >> "$DEBUG_DIR/mapping_analysis.txt"
    
    # Service details
    echo -e "\nSERVICE: $SERVICE_NAME" >> "$DEBUG_DIR/mapping_analysis.txt"  
    kubectl get service $SERVICE_NAME -n $NAMESPACE -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip,PORTS:.spec.ports[*].port" --no-headers >> "$DEBUG_DIR/mapping_analysis.txt"
    
    # Endpoint details
    echo -e "\nENDPOINTS: $SERVICE_NAME" >> "$DEBUG_DIR/mapping_analysis.txt"
    kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o custom-columns="NAME:.metadata.name,ENDPOINTS:.subsets[*].addresses[*].ip,PORTS:.subsets[*].ports[*].port" --no-headers >> "$DEBUG_DIR/mapping_analysis.txt"
    
    # Pod details
    echo -e "\nPODS:" >> "$DEBUG_DIR/mapping_analysis.txt"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=oauth2-proxy -o custom-columns="NAME:.metadata.name,READY:.status.conditions[?(@.type=='Ready')].status,STATUS:.status.phase,IP:.status.podIP" --no-headers >> "$DEBUG_DIR/mapping_analysis.txt"
    
    log "${GREEN}✓ Mapping analysis created${NC}"
}

# Function to validate configuration
validate_config() {
    log "${BOLD}${BLUE}=== RUNNING CONFIGURATION VALIDATION ===${NC}"
    
    local validation_log="$DEBUG_DIR/validation_results.txt"
    
    echo "OAuth2 Proxy Configuration Validation Results" > "$validation_log"
    echo "=============================================" >> "$validation_log"
    echo "Validation Date: $(date)" >> "$validation_log"
    echo "" >> "$validation_log"
    
    # Check if deployment is ready
    if kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE >/dev/null 2>&1; then
        echo "✓ Deployment exists" >> "$validation_log"
        
        # Check if deployment is ready
        ready_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        desired_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [[ "$ready_replicas" == "$desired_replicas" ]]; then
            echo "✓ Deployment is ready ($ready_replicas/$desired_replicas)" >> "$validation_log"
        else
            echo "✗ Deployment not ready ($ready_replicas/$desired_replicas)" >> "$validation_log"
        fi
    else
        echo "✗ Deployment not found" >> "$validation_log"
    fi
    
    # Check service
    if kubectl get service $SERVICE_NAME -n $NAMESPACE >/dev/null 2>&1; then
        echo "✓ Service exists" >> "$validation_log"
        
        # Check if service has endpoints
        endpoints=$(kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
        if [[ $endpoints -gt 0 ]]; then
            echo "✓ Service has $endpoints endpoint(s)" >> "$validation_log"
        else
            echo "✗ Service has no endpoints" >> "$validation_log"
        fi
    else
        echo "✗ Service not found" >> "$validation_log"
    fi
    
    # Check ingress
    if kubectl get ingress $INGRESS_NAME -n $NAMESPACE >/dev/null 2>&1; then
        echo "✓ Ingress exists" >> "$validation_log"
        
        # Check critical annotations
        proxy_buffer_size=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/proxy-buffer-size}' 2>/dev/null)
        if [[ -n "$proxy_buffer_size" ]]; then
            echo "✓ Proxy buffer size configured: $proxy_buffer_size" >> "$validation_log"
        else
            echo "⚠ Proxy buffer size not configured (may cause 502 errors)" >> "$validation_log"
        fi
    else
        echo "✗ Ingress not found" >> "$validation_log"
    fi
    
    # Check required ConfigMaps
    if kubectl get configmap oauth2-proxy-config -n $NAMESPACE >/dev/null 2>&1; then
        echo "✓ OAuth2 ConfigMap exists" >> "$validation_log"
    else
        echo "✗ OAuth2 ConfigMap not found" >> "$validation_log"
    fi
    
    # Test connectivity
    echo "" >> "$validation_log"
    echo "Connectivity Tests:" >> "$validation_log"
    echo "==================" >> "$validation_log"
    
    # Test OAuth2 start endpoint
    if curl -k -s -o /dev/null -w "%{http_code}" "https://kube.gokcloud.com/oauth2/start?rd=/" | grep -q "200\|302"; then
        echo "✓ OAuth2 start endpoint responding" >> "$validation_log"
    else
        echo "✗ OAuth2 start endpoint not responding" >> "$validation_log"
    fi
    
    cat "$validation_log"
    log "${GREEN}✓ Validation completed${NC}"
}

# Function to create comparison script for future deployments
create_comparison_script() {
    log "${BOLD}${BLUE}=== CREATING COMPARISON SCRIPT ===${NC}"
    
    cat << 'EOF' > "$DEBUG_DIR/compare_future_deployment.sh"
#!/bin/bash

# OAuth2 Proxy Configuration Comparison Script
# This script compares current deployment with the baseline captured configuration

BASELINE_DIR="$1"
CURRENT_NAMESPACE="${2:-oauth2}"

if [[ -z "$BASELINE_DIR" ]]; then
    echo "Usage: $0 <baseline_debug_dir> [namespace]"
    echo "Example: $0 /tmp/oauth2-debug-20241007-123456 oauth2"
    exit 1
fi

if [[ ! -d "$BASELINE_DIR" ]]; then
    echo "Error: Baseline directory not found: $BASELINE_DIR"
    exit 1
fi

echo "Comparing current OAuth2 configuration with baseline..."
echo "Baseline: $BASELINE_DIR"
echo "Current namespace: $CURRENT_NAMESPACE"
echo ""

# Compare deployment args
echo "=== DEPLOYMENT ARGUMENTS COMPARISON ==="
kubectl get deployment oauth2-proxy -n "$CURRENT_NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].args}' > /tmp/current_args.json

if [[ -f "$BASELINE_DIR/raw_args.json" ]]; then
    if diff -u "$BASELINE_DIR/raw_args.json" /tmp/current_args.json; then
        echo "✓ Deployment arguments match baseline"
    else
        echo "✗ Deployment arguments differ from baseline"
        echo "Run: diff -u $BASELINE_DIR/raw_args.json /tmp/current_args.json"
    fi
else
    echo "⚠ Baseline args not found"
fi

# Compare service
echo -e "\n=== SERVICE COMPARISON ==="
kubectl get service oauth2-proxy -n "$CURRENT_NAMESPACE" -o yaml > /tmp/current_service.yaml

if [[ -f "$BASELINE_DIR/service.yaml" ]]; then
    if diff -u <(grep -v "resourceVersion\|uid\|creationTimestamp" "$BASELINE_DIR/service.yaml") <(grep -v "resourceVersion\|uid\|creationTimestamp" /tmp/current_service.yaml) >/dev/null; then
        echo "✓ Service configuration matches baseline"
    else
        echo "✗ Service configuration differs from baseline"
        echo "Run: diff -u $BASELINE_DIR/service.yaml /tmp/current_service.yaml"
    fi
else
    echo "⚠ Baseline service not found"
fi

# Compare ingress annotations
echo -e "\n=== INGRESS ANNOTATIONS COMPARISON ==="
kubectl get ingress oauth2-proxy -n "$CURRENT_NAMESPACE" -o jsonpath='{.metadata.annotations}' > /tmp/current_annotations.json

if [[ -f "$BASELINE_DIR/ingress_annotations.json" ]]; then
    if diff -u "$BASELINE_DIR/ingress_annotations.json" /tmp/current_annotations.json; then
        echo "✓ Ingress annotations match baseline"
    else
        echo "✗ Ingress annotations differ from baseline"
    fi
else
    echo "⚠ Baseline ingress annotations not found"
fi

# Check endpoints
echo -e "\n=== ENDPOINTS CHECK ==="
current_endpoints=$(kubectl get endpoints oauth2-proxy -n "$CURRENT_NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
if [[ $current_endpoints -gt 0 ]]; then
    echo "✓ Service has $current_endpoints endpoint(s)"
else
    echo "✗ Service has no endpoints - pods may not be ready"
fi

# Cleanup
rm -f /tmp/current_args.json /tmp/current_service.yaml /tmp/current_annotations.json

echo -e "\nComparison completed. Check diff outputs above for details."
EOF

    chmod +x "$DEBUG_DIR/compare_future_deployment.sh"
    
    log "${GREEN}✓ Comparison script created: $DEBUG_DIR/compare_future_deployment.sh${NC}"
}

# Main execution
main() {
    log "${BOLD}Starting OAuth2 Proxy debugging and validation...${NC}\n"
    
    # Check if kubectl is available and namespace exists
    if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        log "${RED}Error: Namespace '$NAMESPACE' not found or kubectl not available${NC}"
        exit 1
    fi
    
    # Capture all configurations
    capture_deployment
    echo ""
    capture_service  
    echo ""
    capture_ingress
    echo ""
    capture_configs
    echo ""
    capture_logs
    echo ""
    create_mapping
    echo ""
    validate_config
    echo ""
    create_comparison_script
    
    # Create summary
    log "${BOLD}${GREEN}=== DEBUG CAPTURE COMPLETED ===${NC}"
    log "Debug files saved to: ${CYAN}$DEBUG_DIR${NC}"
    log ""
    log "${YELLOW}Key files created:${NC}"
    log "  • arguments_explained.txt - OAuth2 arguments with explanations"
    log "  • service_explained.txt - Service configuration details"
    log "  • ingress_explained.txt - Ingress annotations explained"
    log "  • mapping_analysis.txt - Traffic flow and endpoint mapping"
    log "  • validation_results.txt - Current configuration validation"
    log "  • compare_future_deployment.sh - Script to compare future deployments"
    log ""
    log "${YELLOW}Usage for future debugging:${NC}"
    log "  1. Run this script to capture baseline: ./oauth2-debug.sh"
    log "  2. For comparison: $DEBUG_DIR/compare_future_deployment.sh <baseline_dir>"
    log "  3. Check validation: cat $DEBUG_DIR/validation_results.txt"
    log ""
    log "${GREEN}✓ OAuth2 debugging toolkit ready!${NC}"
}

# Run main function
main "$@"